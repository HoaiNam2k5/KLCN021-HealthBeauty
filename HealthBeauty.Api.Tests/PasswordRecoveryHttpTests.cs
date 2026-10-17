using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class PasswordRecoveryHttpTests
{
    private sealed class Server : IAsyncDisposable
    {
        public required WebApplication App { get; init; }
        public required HttpClient Client { get; init; }
        public required PasswordRecoveryRegressionTests.Queue Queue { get; init; }
        public async ValueTask DisposeAsync() { Client.Dispose(); await App.StopAsync(); await App.DisposeAsync(); }
    }

    private static async Task<Server> Start()
    {
        var config = PasswordRecoveryRegressionTests.Configuration();
        var queue = new PasswordRecoveryRegressionTests.Queue();
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddSingleton<IConfiguration>(config);
        var name = Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(options => options.UseInMemoryDatabase(name));
        builder.Services.AddSingleton<IPasswordRecoveryEmailQueue>(queue);
        builder.Services.AddSingleton<TimeProvider>(new PasswordRecoveryRegressionTests.Clock());
        builder.Services.AddScoped<PasswordRecoveryService>();
        builder.Services.AddScoped<IPasswordService, PasswordService>();
        builder.Services.AddScoped<ITokenService, TokenService>();
        builder.Services.AddScoped<AccountTokenValidation>();
        builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddControllers(options => options.Filters.AddService<DatabasePermissionFilter>())
            .AddApplicationPart(typeof(AuthController).Assembly);
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
        {
            options.EventsType = typeof(AccountTokenValidation);
            options.TokenValidationParameters = new TokenValidationParameters {
                ValidateIssuer = true, ValidIssuer = "RecoveryTests", ValidateAudience = true, ValidAudience = "RecoveryTests",
                ValidateLifetime = true, ClockSkew = TimeSpan.Zero, ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!)) };
        });
        builder.Services.AddAuthorization();
        builder.Services.AddPasswordRecoveryRateLimiting();
        var app = builder.Build();
        app.UseRateLimiter(); app.UseAuthentication(); app.UseAuthorization(); app.MapControllers();
        app.Urls.Add("http://127.0.0.1:0");
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var passwords = scope.ServiceProvider.GetRequiredService<IPasswordService>();
            var role = new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" };
            db.Vaitros.Add(role);
            db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, Email = "user@example.com", TenTaiKhoan = "Customer",
                MatKhauHash = passwords.Hash("old-password-123"), TrangThai = true, VaiTro = role, VaiTroId = 1 });
            db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 2, Email = "inactive@example.com", TenTaiKhoan = "Inactive",
                MatKhauHash = passwords.Hash("old-password-123"), TrangThai = false, VaiTro = role, VaiTroId = 1 });
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        return new Server { App = app, Queue = queue, Client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) } };
    }

    [Fact]
    public async Task RecoveryIsAnonymousNeverRevealsOtpAndInvalidatesOldJwtAndRefreshSessions()
    {
        await using var server = await Start(); var client = server.Client;
        using var login = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "user@example.com", password = "old-password-123" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var oldAuth = (await login.Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new("Bearer", oldAuth.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/auth/permissions")).StatusCode);
        client.DefaultRequestHeaders.Authorization = null;
        var bodies = new List<string>();
        foreach (var email in new[] { "user@example.com", "missing@example.com", "inactive@example.com" })
        {
            using var forgot = await client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email });
            Assert.Equal(HttpStatusCode.OK, forgot.StatusCode);
            var body = await forgot.Content.ReadAsStringAsync(); bodies.Add(body);
            var response = JsonDocument.Parse(body).RootElement;
            Assert.Equal(new[] { "message" }, response.EnumerateObject().Select(property => property.Name).ToArray());
            Assert.False(string.IsNullOrWhiteSpace(response.GetProperty("message").GetString()));
        }
        Assert.All(bodies, body => Assert.Equal(bodies[0], body));
        var otp = Assert.Single(server.Queue.Messages).Otp;
        Assert.All(bodies, body => Assert.DoesNotContain(otp, body));
        using var reset = await client.PostAsJsonAsync("/api/v1/auth/reset-password", new { email = "user@example.com", otp, newPassword = "new-password-456" });
        Assert.Equal(HttpStatusCode.OK, reset.StatusCode);
        var resetText = await reset.Content.ReadAsStringAsync(); Assert.DoesNotContain(otp, resetText); Assert.DoesNotContain("password-456", resetText);
        client.DefaultRequestHeaders.Authorization = new("Bearer", oldAuth.AccessToken);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/auth/permissions")).StatusCode);
        client.DefaultRequestHeaders.Authorization = null;
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = oldAuth.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "user@example.com", password = "old-password-123" })).StatusCode);
        using var newLogin = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "user@example.com", password = "new-password-456" });
        Assert.Equal(HttpStatusCode.OK, newLogin.StatusCode);
        var newAuth = (await newLogin.Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new("Bearer", newAuth.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/auth/permissions")).StatusCode);
        client.DefaultRequestHeaders.Authorization = null;
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/reset-password", new { email = "user@example.com", otp, newPassword = "third-password-789" })).StatusCode);
    }

    [Theory]
    [InlineData("forgot-password", 10)]
    [InlineData("reset-password", 20)]
    public async Task AnonymousRecoveryEndpointsLimitRequestsByRemoteIp(string endpoint, int permits)
    {
        await using var server = await Start();
        for (var i = 0; i < permits; i++)
        {
            using var response = await server.Client.PostAsJsonAsync("/api/v1/auth/" + endpoint,
                new { email = "missing@example.com", otp = "123456", newPassword = "new-password-456" });
            Assert.NotEqual(HttpStatusCode.TooManyRequests, response.StatusCode);
        }
        using var limited = await server.Client.PostAsJsonAsync("/api/v1/auth/" + endpoint,
            new { email = "another@example.com", otp = "123456", newPassword = "new-password-456" });
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
    }

    [Theory]
    [InlineData("12345", "new-password-456")]
    [InlineData("abcdef", "new-password-456")]
    [InlineData("123456", "short")]
    public async Task InvalidResetPayloadReturns400WithoutRevealingSecrets(string otp, string newPassword)
    {
        await using var server = await Start();
        using var result = await server.Client.PostAsJsonAsync("/api/v1/auth/reset-password", new { email = "user@example.com", otp, newPassword });
        Assert.Equal(HttpStatusCode.BadRequest, result.StatusCode);
        Assert.Empty(server.Queue.Messages);
    }
}
