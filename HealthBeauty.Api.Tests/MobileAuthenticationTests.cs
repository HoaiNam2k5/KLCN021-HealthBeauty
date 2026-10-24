using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class MobileAuthenticationTests
{
    private sealed class Passwords : IPasswordService
    {
        public string Hash(string value) => "hashed:" + value;
        public bool Verify(string value, string hash) => hash == Hash(value);
    }
    private sealed class Tokens : ITokenService
    {
        public (string Token, DateTime ExpiresAt) CreateAccessToken(Taikhoan account) => ($"access-{account.TaiKhoanId}", DateTime.UtcNow.AddMinutes(30));
        public string CreateRefreshToken() => Guid.NewGuid().ToString("N");
        public string HashRefreshToken(string token) => token;
    }
    private sealed class GoogleVerifier : IGoogleIdentityVerifier
    {
        public bool IsConfigured { get; init; } = true;
        public VerifiedGoogleIdentity? Identity { get; init; } = new("google-sub", "customer@gmail.com", true, "Google customer", null, null);
        public bool NetworkFailure { get; init; }
        public Task<VerifiedGoogleIdentity?> VerifyAsync(string token, CancellationToken ct) => NetworkFailure
            ? throw new HttpRequestException("Synthetic provider outage") : Task.FromResult(Identity);
    }
    private sealed class Mail : ILoginTwoFactorEmailQueue
    {
        public bool IsConfigured { get; set; } = true;
        public List<LoginTwoFactorEmail> Items { get; } = [];
        public bool TryEnqueue(LoginTwoFactorEmail email) { Items.Add(email); return true; }
    }
    private sealed class Fixture : IAsyncDisposable
    {
        public Klcn021HealthBeautyContext Db { get; } = new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        public Mail Mail { get; } = new();
        public IConfiguration Config { get; }
        public LoginTwoFactorService Otp { get; }
        private readonly ServiceProvider services;
        public Fixture(bool otp = false)
        {
            Config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Authentication:TwoFactor:Enabled"] = otp.ToString(),
                ["Jwt:Key"] = "synthetic-test-otp-key-at-least-32-characters"
            }).Build();
            Otp = new LoginTwoFactorService(Db, Mail, Config, TimeProvider.System);
            services = new ServiceCollection().AddSingleton(Otp).BuildServiceProvider();
            Db.Vaitros.Add(new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" });
            Db.SaveChanges();
        }
        public AuthController Controller(int id = 1) => new(Db, new Passwords(), new Tokens(), Config)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext
            {
                RequestServices = services,
                User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString())], "Test"))
            } }
        };
        public async Task<Taikhoan> Account(string email = "customer@gmail.com", string role = "Customer")
        {
            var r = await Db.Vaitros.SingleOrDefaultAsync(x => x.TenVaiTro == role);
            if (r is null) { r = new Vaitro { TenVaiTro = role }; Db.Vaitros.Add(r); }
            var account = new Taikhoan { Email = email, TenTaiKhoan = "Original name", VaiTro = r,
                MatKhauHash = new Passwords().Hash("correct-password"), TrangThai = true, SecurityStamp = "stamp" };
            account.Khachhang = new Khachhang { HoTen = "Original name", CreatedAt = DateTime.Now };
            Db.Taikhoans.Add(account); await Db.SaveChangesAsync(); return account;
        }
        public async ValueTask DisposeAsync() { await services.DisposeAsync(); await Db.DisposeAsync(); }
    }

    [Fact]
    public async Task GoogleCreatesOnlyVerifiedIdentityAndReusesStableSubject()
    {
        await using var f = new Fixture();
        var request = new GoogleLoginRequest("signed-fixture", "victim@example.test", "spoofed-sub", "Spoofed name");
        var first = Assert.IsType<AuthResponse>(Assert.IsType<OkObjectResult>((await f.Controller().Google(request, new GoogleVerifier(), default)).Result).Value);
        var second = Assert.IsType<AuthResponse>(Assert.IsType<OkObjectResult>((await f.Controller().Google(request, new GoogleVerifier(), default)).Result).Value);
        Assert.Equal(first.Account.Id, second.Account.Id);
        Assert.Equal("customer@gmail.com", first.Account.Email);
        Assert.Equal("Google customer", first.Account.Name);
        Assert.Equal("Customer", first.Account.Role);
        Assert.Single(await f.Db.Taikhoans.ToListAsync()); Assert.Single(await f.Db.Khachhangs.ToListAsync());
        Assert.Equal("google-sub", (await f.Db.Externallogins.SingleAsync()).ProviderUserId);
        Assert.Equal(2, await f.Db.Refreshtokens.CountAsync());
    }

    [Fact]
    public async Task VerifiedGmailLinksExistingCustomerWithoutOverwritingPasswordOrProfile()
    {
        await using var f = new Fixture(); var account = await f.Account(); var hash = account.MatKhauHash;
        Assert.IsType<OkObjectResult>((await f.Controller().Google(new("signed"), new GoogleVerifier(), default)).Result);
        Assert.Single(await f.Db.Taikhoans.ToListAsync()); Assert.Equal(hash, account.MatKhauHash);
        Assert.Equal("Original name", account.TenTaiKhoan); Assert.Single(await f.Db.Externallogins.ToListAsync());
    }

    [Fact]
    public async Task ThirdPartyEmailCannotTakeOverExistingPasswordAccount()
    {
        await using var f = new Fixture(); await f.Account("customer@example.test");
        var verifier = new GoogleVerifier { Identity = new("sub", "customer@example.test", true, "name", null, null) };
        Assert.IsType<ConflictObjectResult>((await f.Controller().Google(new("signed"), verifier, default)).Result);
        Assert.Empty(await f.Db.Externallogins.ToListAsync()); Assert.Empty(await f.Db.Refreshtokens.ToListAsync());
    }

    [Fact]
    public async Task AlreadyLinkedThirdPartyEmailLogsInBySubject()
    {
        await using var f = new Fixture(); var account = await f.Account("customer@example.test");
        f.Db.Externallogins.Add(new Externallogin { TaiKhoan = account, Provider = "Google", ProviderUserId = "sub" });
        await f.Db.SaveChangesAsync();
        var verifier = new GoogleVerifier { Identity = new("sub", "changed@example.test", true, "name", null, null) };
        Assert.IsType<OkObjectResult>((await f.Controller().Google(new("signed"), verifier, default)).Result);
        Assert.Equal("customer@example.test", account.Email);
    }

    [Theory]
    [InlineData("Admin", true, false, 403)]
    [InlineData("Customer", false, false, 401)]
    [InlineData("Customer", true, true, 401)]
    public async Task GoogleCannotBypassRoleOrAccountLocks(string role, bool active, bool locked, int status)
    {
        await using var f = new Fixture(); var account = await f.Account(role: role);
        account.TrangThai = active; account.KhoaDen = locked ? DateTime.UtcNow.AddMinutes(5) : null;
        await f.Db.SaveChangesAsync();
        var result = Assert.IsAssignableFrom<ObjectResult>((await f.Controller().Google(new("signed"), new GoogleVerifier(), default)).Result);
        Assert.Equal(status, result.StatusCode); Assert.Empty(await f.Db.Refreshtokens.ToListAsync());
    }

    [Theory]
    [InlineData(false, false, 503)]
    [InlineData(true, false, 401)]
    [InlineData(true, true, 503)]
    public async Task InvalidGoogleOrProviderFailureIssuesNoTokens(bool configured, bool network, int status)
    {
        await using var f = new Fixture();
        var verifier = new GoogleVerifier { IsConfigured = configured, Identity = null, NetworkFailure = network };
        var result = Assert.IsAssignableFrom<ObjectResult>((await f.Controller().Google(new("invalid"), verifier, default)).Result);
        Assert.Equal(status, result.StatusCode); Assert.Empty(await f.Db.Taikhoans.ToListAsync());
    }

    [Fact]
    public async Task PasswordOtpIssuesNoTokensUntilVerifiedAndCannotReplay()
    {
        await using var f = new Fixture(true); var account = await f.Account();
        var pending = Assert.IsType<TwoFactorRequiredResponse>(Assert.IsType<OkObjectResult>((await f.Controller().Login(new(account.Email, "correct-password"), default)).Result).Value);
        Assert.True(pending.RequiresTwoFactor); Assert.Equal(account.Email, pending.Email);
        Assert.Empty(await f.Db.Refreshtokens.ToListAsync()); Assert.Null(account.LanDangNhapCuoi);
        Assert.False((await f.Db.Dangnhaplogs.SingleAsync()).ThanhCong);
        var email = Assert.Single(f.Mail.Items);
        Assert.IsType<OkObjectResult>((await f.Controller().VerifyTwoFactor(new(account.Email, email.Otp), f.Otp, default)).Result);
        Assert.Single(await f.Db.Refreshtokens.ToListAsync());
        Assert.IsType<BadRequestObjectResult>((await f.Controller().VerifyTwoFactor(new(account.Email, email.Otp), f.Otp, default)).Result);
        Assert.Single(await f.Db.Refreshtokens.ToListAsync());
    }

    [Fact]
    public async Task PasswordOtpCannotStartWithWrongPasswordOrResendEmailAlone()
    {
        await using var f = new Fixture(true); var account = await f.Account();
        Assert.IsType<UnauthorizedObjectResult>((await f.Controller().Login(new(account.Email, "wrong"), default)).Result);
        Assert.IsType<OkObjectResult>(await f.Controller().ResendTwoFactor(new(account.Email), f.Otp, default));
        Assert.Empty(f.Mail.Items); Assert.Empty(await f.Db.LoginTwoFactorChallenges.ToListAsync());
    }

    [Fact]
    public async Task MissingSmtpFailsClosedInsteadOfBypassingOtp()
    {
        await using var f = new Fixture(true); var account = await f.Account(); f.Mail.IsConfigured = false;
        Assert.Equal(503, Assert.IsType<ObjectResult>((await f.Controller().Login(new(account.Email, "correct-password"), default)).Result).StatusCode);
        Assert.Empty(await f.Db.Refreshtokens.ToListAsync());
    }

    [Fact]
    public async Task DefaultLoginAndWebRolesKeepExistingAuthResponse()
    {
        await using var f = new Fixture(); var account = await f.Account();
        Assert.IsType<AuthResponse>(Assert.IsType<OkObjectResult>((await f.Controller().Login(new(account.Email, "correct-password"), default)).Result).Value);
        await using var admin = new Fixture(true); var a = await admin.Account(role: "Admin");
        Assert.IsType<AuthResponse>(Assert.IsType<OkObjectResult>((await admin.Controller().Login(new(a.Email, "correct-password"), default)).Result).Value);
        Assert.Empty(admin.Mail.Items);
    }

    [Theory]
    [InlineData(null, false, false)]
    [InlineData("device-a", false, true)]
    [InlineData("device-a", true, true)]
    public async Task LogoutDisablesOnlyOwnedDevicesAfterValidSessionProof(string? deviceToken, bool wrongOwner, bool secondStillActive)
    {
        await using var f = new Fixture(); var account = await f.Account();
        f.Db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = account.TaiKhoanId, TokenHash = "refresh", ExpiresAt = DateTime.UtcNow.AddDays(1) });
        f.Db.ThietBiKhachHangs.AddRange(
            new ThietBiKhachHang { TaiKhoanId = account.TaiKhoanId, FcmToken = "device-a" },
            new ThietBiKhachHang { TaiKhoanId = account.TaiKhoanId, FcmToken = "device-b" },
            new ThietBiKhachHang { TaiKhoanId = 999, FcmToken = "other-customer" });
        await f.Db.SaveChangesAsync();
        await f.Controller(wrongOwner ? 999 : account.TaiKhoanId).Logout(new("refresh", deviceToken), default);
        Assert.Equal(wrongOwner, (await f.Db.ThietBiKhachHangs.SingleAsync(x => x.FcmToken == "device-a")).TrangThai);
        Assert.Equal(secondStillActive, (await f.Db.ThietBiKhachHangs.SingleAsync(x => x.FcmToken == "device-b")).TrangThai);
        Assert.True((await f.Db.ThietBiKhachHangs.SingleAsync(x => x.FcmToken == "other-customer")).TrangThai);
    }
}
