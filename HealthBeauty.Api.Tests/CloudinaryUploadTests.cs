using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Encodings.Web;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class CloudinaryUploadTests
{
    private static readonly byte[] Png = [137, 80, 78, 71, 13, 10, 26, 10, 0];
    private sealed class Storage : ICloudinaryImageStorage
    {
        public bool IsConfigured { get; set; } = true;
        public Exception? Error { get; set; }
        public int Calls { get; private set; }
        public Task<UploadImageResponse> UploadAsync(byte[] bytes, string type, CancellationToken ct)
        {
            Calls++;
            if (Error is not null) throw Error;
            return Task.FromResult(new UploadImageResponse("https://res.cloudinary.com/demo/image/upload/test.png", "healthbeauty/catalog/test"));
        }
    }
    private static UploadImageRequest File(byte[] bytes, string type = "image/png", long? reportedLength = null) => new()
    {
        File = reportedLength is null
            ? new FormFile(new MemoryStream(bytes), 0, bytes.Length, "file", "untrusted-original-name.png") { Headers = new HeaderDictionary(), ContentType = type }
            : new MisreportedFile(bytes, type, reportedLength.Value)
    };
    private sealed class MisreportedFile(byte[] bytes, string type, long length) : IFormFile
    {
        public string ContentType => type; public string ContentDisposition => ""; public IHeaderDictionary Headers => new HeaderDictionary();
        public long Length => length; public string Name => "file"; public string FileName => "test.png";
        public Stream OpenReadStream() => new MemoryStream(bytes);
        public void CopyTo(Stream target) => target.Write(bytes);
        public Task CopyToAsync(Stream target, CancellationToken cancellationToken = default) => target.WriteAsync(bytes, cancellationToken).AsTask();
    }

    [Theory]
    [InlineData("image/png")]
    [InlineData("image/jpeg")]
    [InlineData("image/webp")]
    public async Task RecognizedImages_Return201(string type)
    {
        byte[] bytes = type == "image/png" ? Png : type == "image/jpeg" ? [255, 216, 255, 0] : Encoding.ASCII.GetBytes("RIFF0000WEBPdata");
        var storage = new Storage();
        var result = await new MediaController(storage).Upload(File(bytes, type), default);
        Assert.Equal(201, Assert.IsType<ObjectResult>(result.Result).StatusCode);
        Assert.IsType<UploadImageResponse>(Assert.IsType<ObjectResult>(result.Result).Value);
        Assert.Equal(1, storage.Calls);
    }

    [Theory]
    [InlineData("image/svg+xml", "<svg></svg>")]
    [InlineData("application/octet-stream", "MZexe")]
    [InlineData("image/png", "MZexe")]
    [InlineData("image/jpeg", "<svg></svg>")]
    [InlineData("image/webp", "https://example.com/file.webp")]
    public async Task UnsupportedOrSpoofedContent_Is400WithoutProviderCall(string type, string body)
    {
        var storage = new Storage();
        Assert.IsType<BadRequestObjectResult>((await new MediaController(storage).Upload(File(Encoding.UTF8.GetBytes(body), type), default)).Result);
        Assert.Equal(0, storage.Calls);
    }

    [Fact]
    public async Task MissingAndEmptyFiles_Are400()
    {
        var storage = new Storage(); var controller = new MediaController(storage);
        Assert.IsType<BadRequestObjectResult>((await controller.Upload(new(), default)).Result);
        Assert.IsType<BadRequestObjectResult>((await controller.Upload(File([]), default)).Result);
        Assert.Equal(0, storage.Calls);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task OversizeActualOrReportedLength_Is413(bool lie)
    {
        var storage = new Storage();
        var result = await new MediaController(storage).Upload(File(new byte[MediaController.MaximumImageBytes + 1], reportedLength: lie ? 1 : null), default);
        Assert.Equal(413, Assert.IsType<ObjectResult>(result.Result).StatusCode);
        Assert.Equal(0, storage.Calls);
    }

    [Theory]
    [InlineData("disabled", 503)]
    [InlineData("provider", 502)]
    [InlineData("timeout", 504)]
    public async Task ConfigurationAndProviderErrors_ReturnSanitizedResponses(string error, int status)
    {
        var storage = new Storage { IsConfigured = error != "disabled", Error = error == "provider" ? new ImageStorageException() : error == "timeout" ? new TimeoutException("do-not-leak-secret") : null };
        var result = Assert.IsType<ObjectResult>((await new MediaController(storage).Upload(File(Png), default)).Result);
        Assert.Equal(status, result.StatusCode);
        Assert.DoesNotContain("do-not-leak-secret", JsonSerializer.Serialize(result.Value));
    }

    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct);
    }
    private static CloudinaryOptions Config() => new() { Enabled = true, CloudName = "demo", ApiKey = "fake-api-key", ApiSecret = "fake-api-secret" };
    private static CloudinaryImageStorage Provider(Handler handler) => new(new HttpClient(handler), Options.Create(Config()), TimeProvider.System);

    [Fact]
    public async Task RestUpload_IsSignedUsesBytesAndNeverSendsApiSecretOrOriginalFilename()
    {
        var ids = new List<string>();
        var handler = new Handler(async (request, ct) =>
        {
            Assert.Equal("https://api.cloudinary.com/v1_1/demo/image/upload", request.RequestUri!.ToString());
            var form = Assert.IsType<MultipartFormDataContent>(request.Content);
            var fields = new Dictionary<string, string>();
            foreach (var part in form)
            {
                var name = part.Headers.ContentDisposition!.Name!.Trim('"');
                if (name == "file") { Assert.Equal(Png, await part.ReadAsByteArrayAsync(ct)); Assert.Contains("image.png", part.Headers.ContentDisposition.FileName!); }
                else fields[name] = await part.ReadAsStringAsync(ct);
            }
            Assert.Equal("false", fields["overwrite"]);
            Assert.Equal("healthbeauty/catalog", fields["folder"]);
            Assert.Equal("fake-api-key", fields["api_key"]);
            Assert.False(fields.ContainsKey("api_secret"));
            Assert.Matches("^[a-f0-9]{32}$", fields["public_id"]);
            ids.Add(fields["public_id"]);
            var signed = $"folder={fields["folder"]}&overwrite=false&public_id={fields["public_id"]}&timestamp={fields["timestamp"]}fake-api-secret";
            Assert.Equal(Convert.ToHexString(SHA1.HashData(Encoding.UTF8.GetBytes(signed))).ToLowerInvariant(), fields["signature"]);
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("{\"secure_url\":\"https://res.cloudinary.com/demo/image/upload/test.png\",\"public_id\":\"healthbeauty/catalog/test\"}") };
        });
        var provider = Provider(handler);
        Assert.True(provider.IsConfigured);
        Assert.StartsWith("https://res.cloudinary.com/", (await provider.UploadAsync(Png, "image/png", default)).ImageUrl);
        await provider.UploadAsync(Png, "image/png", default);
        Assert.Equal(2, ids.Distinct().Count());
    }

    [Theory]
    [InlineData("{\"error\":\"secret\"}", 401)]
    [InlineData("invalid json secret", 200)]
    [InlineData("[]", 200)]
    [InlineData("{}", 200)]
    [InlineData("{\"secure_url\":\"http://evil.example/file\",\"public_id\":\"id\"}", 200)]
    public async Task ProviderErrorsAndMalformedResponses_AreSanitized(string body, int status)
    {
        var provider = Provider(new Handler((_, _) => Task.FromResult(new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(body) })));
        var error = await Assert.ThrowsAsync<ImageStorageException>(() => provider.UploadAsync(Png, "image/png", default));
        Assert.DoesNotContain("secret", error.Message);
    }

    [Fact]
    public async Task OversizedProviderResponse_AndNetworkFailuresAreSanitized()
    {
        var oversized = Provider(new Handler((_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(new string('x', 65537)) })));
        await Assert.ThrowsAsync<ImageStorageException>(() => oversized.UploadAsync(Png, "image/png", default));
        var network = Provider(new Handler((_, _) => throw new HttpRequestException("do-not-leak-secret")));
        var error = await Assert.ThrowsAsync<ImageStorageException>(() => network.UploadAsync(Png, "image/png", default));
        Assert.DoesNotContain("secret", error.Message);
    }

    [Fact]
    public async Task ProviderTimeout_IsDistinctFromClientCancellation()
    {
        var provider = Provider(new Handler((_, _) => throw new TaskCanceledException("provider-secret")));
        await Assert.ThrowsAsync<TimeoutException>(() => provider.UploadAsync(Png, "image/png", default));
        using var cancel = new CancellationTokenSource(); cancel.Cancel();
        await Assert.ThrowsAsync<TaskCanceledException>(() => provider.UploadAsync(Png, "image/png", cancel.Token));
    }

    private sealed class HeaderAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!int.TryParse(Request.Headers["X-Test-User"], out var id)) return Task.FromResult(AuthenticateResult.NoResult());
            var role = id == 1 ? "Admin" : id == 4 ? "Customer" : "Reception";
            var principal = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, role) }, Scheme.Name));
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name)));
        }
    }

    [Fact]
    public async Task HttpMultipartAndSwagger_RequireRolesAndDatabaseGrant()
    {
        var builder = WebApplication.CreateBuilder();
        var dbName = Guid.NewGuid().ToString(); var storage = new Storage();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(dbName));
        builder.Services.AddSingleton<ICloudinaryImageStorage>(storage);
        builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddControllers(o => o.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(MediaController).Assembly);
        builder.Services.AddAuthentication("Test").AddScheme<AuthenticationSchemeOptions, HeaderAuthentication>("Test", _ => { });
        builder.Services.AddAuthorization(); builder.Services.AddEndpointsApiExplorer(); builder.Services.AddSwaggerGen();
        await using var app = builder.Build();
        app.UseAuthentication(); app.UseAuthorization(); app.UseSwagger(); app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var permission = new Quyen { QuyenId = 1, MaQuyen = "SERVICE.WRITE", TenQuyen = "Manage services", NhomQuyen = "Services", TrangThai = true };
            db.Quyens.Add(permission);
            foreach (var id in Enumerable.Range(1, 4))
            {
                var role = new Vaitro { VaiTroId = id, TenVaiTro = id == 1 ? "Admin" : id == 4 ? "Customer" : "Reception" };
                db.Vaitros.Add(role);
                db.Taikhoans.Add(new Taikhoan { TaiKhoanId = id, VaiTroId = id, VaiTro = role, Email = $"upload{id}@example.invalid", MatKhauHash = "unused", TrangThai = true });
                if (id <= 2) db.VaitroQuyens.Add(new VaitroQuyen { VaiTroId = id, QuyenId = 1, Quyen = permission, DuocCap = true });
            }
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        try
        {
            using var client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) };
            using var swagger = await client.GetAsync("/swagger/v1/swagger.json");
            Assert.Equal(HttpStatusCode.OK, swagger.StatusCode);
            using var document = JsonDocument.Parse(await swagger.Content.ReadAsStringAsync());
            Assert.True(document.RootElement.GetProperty("paths").TryGetProperty("/api/v1/media/images", out _));
            foreach (var (id, status) in new[] { (0, 401), (1, 201), (2, 201), (3, 403), (4, 403) })
            {
                client.DefaultRequestHeaders.Remove("X-Test-User");
                if (id != 0) client.DefaultRequestHeaders.Add("X-Test-User", id.ToString());
                using var form = new MultipartFormDataContent();
                var file = new ByteArrayContent(Png); file.Headers.ContentType = new MediaTypeHeaderValue("image/png");
                form.Add(file, "file", "service.png");
                using var response = await client.PostAsync("/api/v1/media/images", form);
                Assert.Equal(status, (int)response.StatusCode);
                if (status == 201)
                {
                    using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
                    Assert.StartsWith("https://", json.RootElement.GetProperty("imageUrl").GetString());
                    Assert.NotEmpty(json.RootElement.GetProperty("publicId").GetString()!);
                }
            }
            Assert.Equal(2, storage.Calls);
            client.DefaultRequestHeaders.Remove("X-Test-User"); client.DefaultRequestHeaders.Add("X-Test-User", "1");
            using var missingFile = new MultipartFormDataContent();
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsync("/api/v1/media/images", missingFile)).StatusCode);
        }
        finally { await app.StopAsync(); }
    }

    [Fact]
    public void UploadPermission_IsServiceWriteAndConfigurationRejectsEndpointInjection()
    {
        Assert.Equal("SERVICE.WRITE", DatabasePermissionFilter.RequiredPermission("Media", "Upload", new ClaimsPrincipal()));
        Assert.False(new CloudinaryOptions().IsConfigured);
        var config = Config(); config.CloudName = "evil.example/path"; Assert.False(config.IsConfigured);
        config = Config(); config.Folder = "catalog&overwrite=true"; Assert.False(config.IsConfigured);
    }
}
