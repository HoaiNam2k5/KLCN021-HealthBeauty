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

public sealed class MobileAuthenticationHttpTests
{
    private sealed class Images : ICloudinaryImageStorage
    {
        public bool IsConfigured => true;
        public Task<UploadImageResponse> UploadAsync(byte[] image, string type, CancellationToken ct) =>
            Task.FromResult(new UploadImageResponse("https://res.cloudinary.com/demo/image/upload/customer-avatar.png", "http-avatar"));
    }
    private sealed class Mail : ILoginTwoFactorEmailQueue
    {
        public bool IsConfigured => true;
        public List<LoginTwoFactorEmail> Items { get; } = [];
        public bool TryEnqueue(LoginTwoFactorEmail email) { Items.Add(email); return true; }
    }
    private sealed class Verifier : IGoogleIdentityVerifier
    {
        public bool IsConfigured => true;
        public Task<VerifiedGoogleIdentity?> VerifyAsync(string token, CancellationToken ct) => Task.FromResult(token == "verified-test-token"
            ? new VerifiedGoogleIdentity("signed-sub", "google-customer@gmail.com", true, "Google fixture", null, null) : null);
    }
    private sealed class Server : IAsyncDisposable
    {
        public required WebApplication App { get; init; }
        public required HttpClient Client { get; init; }
        public required Mail Mail { get; init; }
        public async ValueTask DisposeAsync() { Client.Dispose(); await App.StopAsync(); await App.DisposeAsync(); }
    }
    private static async Task<Server> Start(bool twoFactor = false)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = "isolated-mobile-http-tests-only-at-least-32-characters", ["Jwt:Issuer"] = "MobileTests",
            ["Jwt:Audience"] = "MobileTests", ["Authentication:TwoFactor:Enabled"] = twoFactor.ToString()
        }).Build();
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddSingleton<IConfiguration>(config);
        var database = Guid.NewGuid().ToString(); var mail = new Mail();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(database));
        builder.Services.AddSingleton<TimeProvider>(TimeProvider.System);
        builder.Services.AddSingleton<ILoginTwoFactorEmailQueue>(mail);
        builder.Services.AddSingleton<IGoogleIdentityVerifier, Verifier>();
        builder.Services.AddSingleton<ICloudinaryImageStorage, Images>();
        builder.Services.AddScoped<LoginTwoFactorService>();
        builder.Services.AddScoped<IPasswordService, PasswordService>();
        builder.Services.AddScoped<ITokenService, TokenService>();
        builder.Services.AddScoped<AccountTokenValidation>();
        builder.Services.AddControllers(options => options.Filters.Add<DatabasePermissionFilter>()).AddApplicationPart(typeof(AuthController).Assembly);
        builder.Services.AddEndpointsApiExplorer(); builder.Services.AddSwaggerGen();
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
        {
            o.EventsType = typeof(AccountTokenValidation);
            o.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true, ValidIssuer = "MobileTests", ValidateAudience = true, ValidAudience = "MobileTests",
                ValidateLifetime = true, ClockSkew = TimeSpan.Zero, ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!))
            };
        });
        builder.Services.AddAuthorization(); builder.Services.AddPasswordRecoveryRateLimiting();
        builder.Services.AddMobileAuthenticationRateLimiting();
        var app = builder.Build(); app.UseSwagger(); app.UseRateLimiter(); app.UseAuthentication(); app.UseAuthorization();
        app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var passwords = scope.ServiceProvider.GetRequiredService<IPasswordService>();
            var role = new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" }; db.Vaitros.Add(role);
            db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, Email = "password@example.test", VaiTro = role,
                TrangThai = true, TenTaiKhoan = "Password fixture", MatKhauHash = passwords.Hash("password-fixture-123") });
            db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Customer fixture", DiemThuong = 100 });
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        return new Server { App = app, Client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) }, Mail = mail };
    }

    [Fact]
    public async Task GoogleRouteMatchesMobileBodyAndIssuesUsableSession()
    {
        await using var server = await Start();
        var response = await server.Client.PostAsJsonAsync("/api/v1/auth/google", new
        {
            idToken = "verified-test-token", googleId = "untrusted-sub", email = "untrusted@example.test", fullName = "Untrusted"
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var auth = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.Equal("google-customer@gmail.com", auth.Account.Email); Assert.False(string.IsNullOrEmpty(auth.RefreshToken));
        server.Client.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await server.Client.GetAsync("/api/v1/auth/permissions")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await server.Client.PostAsJsonAsync("/api/v1/auth/logout", new { refreshToken = auth.RefreshToken })).StatusCode);
    }

    [Fact]
    public async Task GoogleMissingOrInvalidTokenFailsWithoutTrustingEmail()
    {
        await using var server = await Start();
        Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.PostAsJsonAsync("/api/v1/auth/google", new { email = "google-customer@gmail.com", googleId = "signed-sub" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await server.Client.PostAsJsonAsync("/api/v1/auth/google", new { idToken = "forged-token" })).StatusCode);
    }

    [Fact]
    public async Task PasswordOtpChallengeVerifyAndResendMatchFlutterContract()
    {
        await using var server = await Start(true);
        var login = await server.Client.PostAsJsonAsync("/api/v1/auth/login", new { email = "password@example.test", password = "password-fixture-123" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var pending = await login.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(pending.GetProperty("requiresTwoFactor").GetBoolean());
        Assert.False(pending.TryGetProperty("accessToken", out _));
        Assert.Equal("password@example.test", pending.GetProperty("email").GetString());
        var email = Assert.Single(server.Mail.Items);
        Assert.Equal(HttpStatusCode.OK, (await server.Client.PostAsJsonAsync("/api/v1/auth/resend-2fa", new { email = email.Email })).StatusCode);
        Assert.Single(server.Mail.Items);
        var verify = await server.Client.PostAsJsonAsync("/api/v1/auth/verify-2fa", new { email = email.Email, otp = email.Otp });
        Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
        var auth = (await verify.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.Equal("Customer", auth.Account.Role); Assert.False(string.IsNullOrWhiteSpace(auth.AccessToken));
        Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.PostAsJsonAsync("/api/v1/auth/verify-2fa", new { email = email.Email, otp = email.Otp })).StatusCode);
    }

    [Fact]
    public async Task PublicAvailabilityRangeMatchesFlutterJsonAndValidatesBounds()
    {
        await using var server = await Start();
        var day = DateOnly.FromDateTime(DateTime.Today.AddDays(10));
        using (var scope = server.App.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            db.Nhanviens.Add(new Nhanvien { NhanVienId = 7, HoTen = "Availability fixture" });
            db.Lichlamviecs.Add(new Lichlamviec { NhanVienId = 7, NgayLam = day, GioBatDau = new(9, 0), GioKetThuc = new(10, 0) });
            await db.SaveChangesAsync();
        }
        var query = $"from={day:yyyy-MM-dd}&to={day.AddDays(2):yyyy-MM-dd}&staffId=7&durationMinutes=60";
        var response = await server.Client.GetAsync($"/api/v1/appointments/availability/days?{query}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var days = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, days.GetArrayLength());
        Assert.Equal(day.ToString("yyyy-MM-dd"), days[0].GetProperty("date").GetString());
        Assert.Equal("09:00:00", days[0].GetProperty("startTimes")[0].GetString());
        Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.GetAsync($"/api/v1/appointments/availability/days?from={day:yyyy-MM-dd}&to={day.AddDays(61):yyyy-MM-dd}")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.GetAsync($"/api/v1/appointments/availability/days?from={day:yyyy-MM-dd}&to={day:yyyy-MM-dd}&staffId=999")).StatusCode);
    }

    [Fact]
    public async Task CustomerAvatarMultipartIsOwnedAndAdminImageRouteStaysForbidden()
    {
        await using var server = await Start();
        static MultipartFormDataContent Image()
        {
            var body = new MultipartFormDataContent();
            var image = new ByteArrayContent([137, 80, 78, 71, 13, 10, 26, 10, 0]);
            image.Headers.ContentType = new("image/png"); body.Add(image, "File", "avatar.png");
            body.Add(new StringContent("2"), "customerId"); return body;
        }
        using (var image = Image())
            Assert.Equal(HttpStatusCode.Unauthorized, (await server.Client.PostAsync("/api/v1/customers/me/avatar", image)).StatusCode);
        var login = await server.Client.PostAsJsonAsync("/api/v1/auth/login", new { email = "password@example.test", password = "password-fixture-123" });
        var auth = (await login.Content.ReadFromJsonAsync<AuthResponse>())!;
        server.Client.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        using (var scope = server.App.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            db.Khachhangs.Add(new Khachhang { KhachHangId = 2, HoTen = "Other", AvatarUrl = "https://example.test/other.png" });
            await db.SaveChangesAsync();
        }
        using (var image = Image())
        {
            var uploaded = await server.Client.PostAsync("/api/v1/customers/me/avatar", image);
            Assert.Equal(HttpStatusCode.OK, uploaded.StatusCode);
            var profile = (await uploaded.Content.ReadFromJsonAsync<CustomerResponse>())!;
            Assert.Equal(1, profile.Id); Assert.EndsWith("customer-avatar.png", profile.AvatarUrl); Assert.Equal(100, profile.RewardPoints);
        }
        using (var image = Image())
            Assert.Equal(HttpStatusCode.Forbidden, (await server.Client.PostAsync("/api/v1/media/images", image)).StatusCode);
        var read = (await server.Client.GetFromJsonAsync<CustomerResponse>("/api/v1/customers/me"))!;
        Assert.EndsWith("customer-avatar.png", read.AvatarUrl);
        using (var scope = server.App.Services.CreateScope())
            Assert.Equal("https://example.test/other.png", (await scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>().Khachhangs.FindAsync(2))!.AvatarUrl);
        Assert.Equal(HttpStatusCode.OK, (await server.Client.DeleteAsync("/api/v1/customers/me/avatar")).StatusCode);
        Assert.Null((await server.Client.GetFromJsonAsync<CustomerResponse>("/api/v1/customers/me"))!.AvatarUrl);
    }

    [Fact]
    public async Task PasswordChangeInvalidatesAccessAndRefreshAndRequiresCurrentProof()
    {
        await using var server = await Start();
        Assert.Equal(HttpStatusCode.Unauthorized, (await server.Client.PutAsJsonAsync("/api/v1/auth/change-password", new { currentPassword = "password-fixture-123", newPassword = "new-password-456" })).StatusCode);
        var login = await server.Client.PostAsJsonAsync("/api/v1/auth/login", new { email = "password@example.test", password = "password-fixture-123" });
        var auth = (await login.Content.ReadFromJsonAsync<AuthResponse>())!;
        server.Client.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.PutAsJsonAsync("/api/v1/auth/change-password", new { currentPassword = "wrong-password", newPassword = "new-password-456" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.PutAsJsonAsync("/api/v1/auth/change-password", new { currentPassword = "password-fixture-123", newPassword = "short" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await server.Client.PutAsJsonAsync("/api/v1/auth/change-password", new { currentPassword = "password-fixture-123", newPassword = "new-password-456" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await server.Client.GetAsync("/api/v1/auth/permissions")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await server.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = auth.RefreshToken })).StatusCode);
        server.Client.DefaultRequestHeaders.Authorization = null;
        Assert.Equal(HttpStatusCode.Unauthorized, (await server.Client.PostAsJsonAsync("/api/v1/auth/login", new { email = "password@example.test", password = "password-fixture-123" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await server.Client.PostAsJsonAsync("/api/v1/auth/login", new { email = "password@example.test", password = "new-password-456" })).StatusCode);
    }

    [Fact]
    public async Task PasswordChangeHasRegisteredBoundedRatePolicy()
    {
        await using var server = await Start();
        var login = await server.Client.PostAsJsonAsync("/api/v1/auth/login", new { email = "password@example.test", password = "password-fixture-123" });
        var auth = (await login.Content.ReadFromJsonAsync<AuthResponse>())!;
        server.Client.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        for (var i = 0; i < 10; i++)
            Assert.Equal(HttpStatusCode.BadRequest, (await server.Client.PutAsJsonAsync("/api/v1/auth/change-password", new { currentPassword = "wrong-password", newPassword = "new-password-456" })).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await server.Client.PutAsJsonAsync("/api/v1/auth/change-password", new { currentPassword = "wrong-password", newPassword = "new-password-456" })).StatusCode);
    }

    [Fact]
    public async Task SwaggerListsMobileEndpointsAndAdditionalAppointmentFields()
    {
        await using var server = await Start();
        var swagger = await server.Client.GetStringAsync("/swagger/v1/swagger.json");
        foreach (var path in new[] { "/api/v1/auth/google", "/api/v1/auth/verify-2fa", "/api/v1/auth/resend-2fa", "/api/v1/appointments/availability/days" }) Assert.Contains(path, swagger);
        foreach (var field in new[] { "reviewComment", "reviewedAt", "reviewReply", "reviewRepliedAt" }) Assert.Contains(field, swagger);
    }
}
