using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.Encodings.Web;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public class SpaAssistantTests
{
    private sealed class FixtureAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var id = Request.Headers["X-Fixture-User"].ToString();
            if (string.IsNullOrEmpty(id)) return Task.FromResult(AuthenticateResult.NoResult());
            var user = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id)], Scheme.Name));
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(user, Scheme.Name)));
        }
    }
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => send(request, cancellationToken);
    }
    private sealed class Factory(HttpClient client) : IHttpClientFactory { public HttpClient CreateClient(string name) => client; }
    private static Klcn021HealthBeautyContext Db() => new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static IConfiguration Config(string? key = "test-key") => new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["Gemini:ApiKey"] = key }).Build();
    private static HttpResponseMessage Gemini(object json) => new(HttpStatusCode.OK) { Content = new StringContent(JsonSerializer.Serialize(new { candidates = new[] { new { content = new { parts = new[] { new { text = JsonSerializer.Serialize(json) } } } } } }), Encoding.UTF8, "application/json") };
    private static async Task Seed(Klcn021HealthBeautyContext db)
    {
        db.Dichvus.AddRange(new Dichvu { DichVuId = 1, TenDichVu = "Facial", TrangThai = true, Gia = 350000, ThoiLuongPhut = 60 }, new Dichvu { DichVuId = 2, TenDichVu = "Inactive", TrangThai = false, Gia = 1 });
        db.ServicePackages.AddRange(new ServicePackage { Id = 3, Name = "Package", Active = true, Price = 500000, ValidityDays = 30 }, new ServicePackage { Id = 4, Name = "Inactive", Active = false });
        db.Combodichvus.Add(new Combodichvu { ComboId = 5, TenCombo = "Combo", GiaCombo = 200000, TrangThai = true });
        db.Chitietcombos.Add(new Chitietcombo { ComboChiTietId = 5, ComboId = 5, DichVuId = 1, SoLuong = 2 });
        await db.SaveChangesAsync();
    }
    [Fact]
    public async Task GeneratedIdsAreValidatedAndPricesComeOnlyFromCatalog()
    {
        await using var db = Db(); await Seed(db);
        var handler = new Handler(async (req, ct) => {
            Assert.Equal("generativelanguage.googleapis.com", req.RequestUri!.Host);
            Assert.Equal("/v1beta/models/gemini-3.5-flash-lite:generateContent", req.RequestUri.AbsolutePath);
            Assert.Equal("test-key", req.Headers.GetValues("x-goog-api-key").Single());
            var requestBody = await req.Content!.ReadAsStringAsync(ct);
            Assert.Contains("history", requestBody);
            Assert.Equal(2048, JsonDocument.Parse(requestBody).RootElement.GetProperty("generationConfig").GetProperty("maxOutputTokens").GetInt32());
            return Gemini(new { reply = "Dịch vụ này giá 9999999 đồng.", serviceIds = new[] { 1, 2, 999, 1 }, comboIds = new[] { 5, 99 }, packageIds = new[] { 3, 4 } });
        });
        var assistant = new SpaAssistant(db, new Factory(new HttpClient(handler)), Config());
        var result = await assistant.AskAsync("Giá?", [new AssistantTurn("user", "Da khô")], default);
        Assert.Equal(new[] { 1 }, result.ServiceIds); Assert.Equal(new[] { 5 }, result.ComboIds); Assert.Equal(new[] { 3 }, result.PackageIds);
        Assert.DoesNotContain("9999999", result.Reply); Assert.Contains("350.000", result.Reply); Assert.Contains("60 phút", result.Reply);
        Assert.Contains("200.000", result.Reply); Assert.Contains("120 phút", result.Reply); Assert.Contains("500.000", result.Reply); Assert.Contains("30 ngày", result.Reply);
    }
    [Fact]
    public async Task MissingConfigurationDoesNotContactProvider()
    {
        await using var db = Db(); var handler = new Handler((_, _) => throw new Exception("unexpected request"));
        var controller = new AssistantController(new SpaAssistant(db, new Factory(new HttpClient(handler)), Config(null)));
        var result = Assert.IsType<ObjectResult>(await controller.Chat(new("Hello"), default));
        Assert.Equal(503, result.StatusCode);
    }
    [Theory]
    [InlineData("", 0)] [InlineData("  ", 0)] [InlineData("valid", 7)]
    public async Task ControllerRejectsInvalidQuestionsOrHistory(string message, int turns)
    {
        await using var db = Db(); var handler = new Handler((_, _) => throw new Exception("unexpected request"));
        var controller = new AssistantController(new SpaAssistant(db, new Factory(new HttpClient(handler)), Config()));
        var history = Enumerable.Range(0, turns).Select(_ => new AssistantTurn("user", "text")).ToList();
        Assert.IsType<BadRequestResult>(await controller.Chat(new(message, history), default));
        Assert.IsType<BadRequestResult>(await controller.Chat(new("valid", [new AssistantTurn("system", "text")]), default));
        Assert.IsType<BadRequestResult>(await controller.Chat(new("valid", [new AssistantTurn("user", new string('x', 501))]), default));
    }
    [Fact]
    public async Task MalformedOrFailedProviderResponsesReturnSafeErrors()
    {
        await using var db = Db();
        var handler = new Handler((_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("bad") }));
        var controller = new AssistantController(new SpaAssistant(db, new Factory(new HttpClient(handler)), Config()));
        Assert.Equal(502, Assert.IsType<ObjectResult>(await controller.Chat(new("Hello"), default)).StatusCode);
    }
    [Fact]
    public async Task ProviderTimeoutReturns504()
    {
        await using var db = Db();
        var handler = new Handler((_, _) => throw new OperationCanceledException());
        var controller = new AssistantController(new SpaAssistant(db, new Factory(new HttpClient(handler)), Config()));
        Assert.Equal(504, Assert.IsType<ObjectResult>(await controller.Chat(new("Hello"), default)).StatusCode);
    }
    [Fact]
    public async Task UserCancellationIsNotReportedAsProviderTimeout()
    {
        await using var db = Db();
        var handler = new Handler((_, ct) => { ct.ThrowIfCancellationRequested(); throw new OperationCanceledException(ct); });
        var assistant = new SpaAssistant(db, new Factory(new HttpClient(handler)), Config());
        using var token = new CancellationTokenSource(); token.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => assistant.AskAsync("Hello", [], token.Token));
    }

    [Fact]
    public async Task HttpPipelineRequiresAuthenticationEnforcesPerAccountRateLimitAndAcceptsUtf8Boundary()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddSingleton<IConfiguration>(Config());
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(Guid.NewGuid().ToString()));
        builder.Services.AddControllers().AddApplicationPart(typeof(AssistantController).Assembly);
        builder.Services.AddAuthentication("fixture").AddScheme<AuthenticationSchemeOptions, FixtureAuthentication>("fixture", _ => { });
        builder.Services.AddAuthorization();
        builder.Services.AddSpaAssistant();
        builder.Services.AddPasswordRecoveryRateLimiting();
        builder.Services.AddMobileAuthenticationRateLimiting();
        builder.Services.AddHttpClient("spa-assistant").ConfigurePrimaryHttpMessageHandler(() => new Handler((_, _) => Task.FromResult(Gemini(new { reply = "Xin chào", serviceIds = Array.Empty<int>(), comboIds = Array.Empty<int>(), packageIds = Array.Empty<int>() }))));
        await using var app = builder.Build();
        app.UseAuthentication(); app.UseRateLimiter(); app.UseAuthorization(); app.MapControllers();
        app.MapGet("/fixture-existing-limit", () => "ok").RequireRateLimiting(MobileAuthenticationRateLimiting.AvatarPolicy);
        app.Urls.Add("http://127.0.0.1:0");
        await app.StartAsync();
        var addresses = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!;
        using var client = new HttpClient { BaseAddress = new Uri(addresses.Addresses.Single()) };
        var request = new AssistantChatRequest(new string('ắ', 1000), Enumerable.Range(0, 6).Select(_ => new AssistantTurn("user", new string('ắ', 500))).ToList());
        Assert.True(Encoding.UTF8.GetByteCount(JsonSerializer.Serialize(request, new JsonSerializerOptions { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping })) > 8192);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/v1/assistant/chat", request)).StatusCode);
        using var a = new HttpClient { BaseAddress = client.BaseAddress }; a.DefaultRequestHeaders.Add("X-Fixture-User", "11");
        using var b = new HttpClient { BaseAddress = client.BaseAddress }; b.DefaultRequestHeaders.Add("X-Fixture-User", "12");
        for (var i = 0; i < 20; i++) Assert.Equal(HttpStatusCode.OK, (await a.PostAsJsonAsync("/api/v1/assistant/chat", request)).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await a.PostAsJsonAsync("/api/v1/assistant/chat", request)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await b.PostAsJsonAsync("/api/v1/assistant/chat", request)).StatusCode);
        for (var i = 0; i < 20; i++) Assert.Equal(HttpStatusCode.OK, (await a.GetAsync("/fixture-existing-limit")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await b.GetAsync("/fixture-existing-limit")).StatusCode);
        await app.StopAsync();
    }
}
