using System.Security.Claims;
using System.Text;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AuthSecurityRegressionTests
{
    private sealed class Passwords : IPasswordService
    {
        public string Hash(string password) => password;
        public bool Verify(string password, string encodedHash) => password == encodedHash;
    }

    private sealed class Tokens : ITokenService
    {
        public (string Token, DateTime ExpiresAt) CreateAccessToken(Taikhoan account) => ("access", DateTime.UtcNow.AddMinutes(30));
        public string CreateRefreshToken() => Guid.NewGuid().ToString();
        public string HashRefreshToken(string token) => token;
    }

    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Vaitros.Add(new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" });
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, VaiTroId = 1, Email = "user@example.com", MatKhauHash = "correct-password", TrangThai = true });
        await db.SaveChangesAsync();
        return db;
    }

    private static AuthController Controller(Klcn021HealthBeautyContext db, int accountId = 1, Dictionary<string, string?>? settings = null) => new(db, new Passwords(), new Tokens(),
        new ConfigurationBuilder().AddInMemoryCollection(settings ?? []).Build())
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString())], "Test")) } }
    };

    [Fact]
    public async Task FiveWrongPasswordsAreLoggedAndTemporarilyLockAccount()
    {
        await using var db = await Database();
        for (var i = 0; i < 5; i++)
            Assert.IsType<UnauthorizedObjectResult>((await Controller(db).Login(new LoginRequest("user@example.com", "wrong"), default)).Result);
        var account = await db.Taikhoans.SingleAsync();
        Assert.Equal(5, account.SoLanDangNhapSai);
        Assert.InRange(account.KhoaDen!.Value, DateTime.UtcNow.AddMinutes(14), DateTime.UtcNow.AddMinutes(16));
        Assert.Equal(5, await db.Dangnhaplogs.CountAsync(x => !x.ThanhCong && x.LyDoThatBai != null));
        Assert.IsType<UnauthorizedObjectResult>((await Controller(db).Login(new LoginRequest("user@example.com", "correct-password"), default)).Result);
        Assert.Empty(await db.Refreshtokens.ToListAsync());
    }

    [Fact]
    public async Task UnknownAccountFailureIsLoggedWithoutAccountReference()
    {
        await using var db = await Database();
        await Controller(db).Login(new LoginRequest("missing@example.com", "wrong"), default);
        var log = await db.Dangnhaplogs.SingleAsync();
        Assert.Null(log.TaiKhoanId);
        Assert.False(log.ThanhCong);
        Assert.Equal("missing@example.com", log.Email);
    }

    [Fact]
    public async Task LockedAccountCannotRefreshAndTokenIsNotRotated()
    {
        await using var db = await Database();
        (await db.Taikhoans.SingleAsync()).KhoaDen = DateTime.UtcNow.AddMinutes(15);
        db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = 1, TokenHash = "locked-refresh", ExpiresAt = DateTime.UtcNow.AddDays(1), CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();
        Assert.IsType<UnauthorizedObjectResult>((await Controller(db).Refresh(new RefreshRequest("locked-refresh"), default)).Result);
        Assert.Null((await db.Refreshtokens.SingleAsync()).RevokedAt);
    }

    [Fact]
    public async Task LogoutCannotRevokeAnotherAccountsRefreshToken()
    {
        await using var db = await Database();
        db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = 1, TokenHash = "owned-refresh", ExpiresAt = DateTime.UtcNow.AddDays(1), CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();
        Assert.IsType<NoContentResult>(await Controller(db, 2).Logout(new RefreshRequest("owned-refresh"), default));
        Assert.Null((await db.Refreshtokens.SingleAsync()).RevokedAt);
        Assert.IsType<NoContentResult>(await Controller(db).Logout(new RefreshRequest("owned-refresh"), default));
        Assert.NotNull((await db.Refreshtokens.SingleAsync()).RevokedAt);
    }

    [Fact]
    public async Task ConfiguredLockoutThresholdAndDurationAreApplied()
    {
        await using var db = await Database();
        var settings = new Dictionary<string, string?> { ["Authentication:MaxFailedAttempts"] = "2", ["Authentication:LockoutMinutes"] = "3" };
        await Controller(db, settings: settings).Login(new LoginRequest("user@example.com", "wrong"), default);
        Assert.Null((await db.Taikhoans.SingleAsync()).KhoaDen);
        await Controller(db, settings: settings).Login(new LoginRequest("user@example.com", "wrong"), default);
        Assert.InRange((await db.Taikhoans.SingleAsync()).KhoaDen!.Value, DateTime.UtcNow.AddMinutes(2), DateTime.UtcNow.AddMinutes(4));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task ExpiredLockStartsFreshFailureCountAndSuccessfulLoginResetsState(bool correctPassword)
    {
        await using var db = await Database();
        var account = await db.Taikhoans.SingleAsync();
        account.SoLanDangNhapSai = 5;
        account.KhoaDen = DateTime.UtcNow.AddMinutes(-1);
        await db.SaveChangesAsync();
        var result = await Controller(db).Login(new LoginRequest("user@example.com", correctPassword ? "correct-password" : "wrong"), default);
        Assert.Null(account.KhoaDen);
        Assert.Equal(correctPassword ? 0 : 1, account.SoLanDangNhapSai);
        if (correctPassword)
        {
            Assert.IsType<OkObjectResult>(result.Result);
            Assert.NotNull(account.LanDangNhapCuoi);
            Assert.True((await db.Dangnhaplogs.SingleAsync()).ThanhCong);
        }
        else Assert.IsType<UnauthorizedObjectResult>(result.Result);
    }

    private static TokenValidatedContext TokenContext(params Claim[] claims) => new(new DefaultHttpContext(),
        new AuthenticationScheme("Bearer", null, typeof(JwtBearerHandler)), new JwtBearerOptions())
        { Principal = new ClaimsPrincipal(new ClaimsIdentity(claims, "Bearer")) };

    [Theory]
    [InlineData("valid", false)]
    [InlineData("inactive", true)]
    [InlineData("locked", true)]
    [InlineData("expired-lock", false)]
    [InlineData("missing", true)]
    [InlineData("wrong-role", true)]
    [InlineData("missing-role", true)]
    [InlineData("extra-role", true)]
    [InlineData("missing-id", true)]
    [InlineData("invalid-id", true)]
    [InlineData("conflicting-id", true)]
    public async Task AccessTokenValidationChecksCurrentAccountAndExactRole(string scenario, bool rejected)
    {
        await using var db = await Database();
        var account = await db.Taikhoans.SingleAsync();
        if (scenario == "inactive") account.TrangThai = false;
        if (scenario == "locked") account.KhoaDen = DateTime.UtcNow.AddMinutes(15);
        if (scenario == "expired-lock") account.KhoaDen = DateTime.UtcNow.AddMinutes(-1);
        await db.SaveChangesAsync();
        var claims = new List<Claim>();
        if (scenario != "missing-id") claims.Add(new Claim(ClaimTypes.NameIdentifier, scenario == "missing" ? "999" : scenario == "invalid-id" ? "bad" : "1"));
        if (scenario == "conflicting-id") claims.Add(new Claim(ClaimTypes.NameIdentifier, "2"));
        if (scenario != "missing-role") claims.Add(new Claim(ClaimTypes.Role, scenario == "wrong-role" ? "Admin" : "Customer"));
        if (scenario == "extra-role") claims.Add(new Claim(ClaimTypes.Role, "Admin"));
        var context = TokenContext(claims.ToArray());
        await new AccountTokenValidation(db).TokenValidated(context);
        Assert.Equal(rejected, context.Result?.Failure is not null);
    }

    [Fact]
    public async Task ExistingTokenIsRejectedAfterRoleChange()
    {
        await using var db = await Database();
        var context = TokenContext(new Claim(ClaimTypes.NameIdentifier, "1"), new Claim(ClaimTypes.Role, "Customer"));
        await new AccountTokenValidation(db).TokenValidated(context);
        Assert.Null(context.Result);
        (await db.Vaitros.SingleAsync()).TenVaiTro = "Manager";
        await db.SaveChangesAsync();
        await new AccountTokenValidation(db).TokenValidated(context);
        Assert.NotNull(context.Result?.Failure);
    }

    [Fact]
    public async Task ActualIssuedJwtMapsToAccountIdentifierAndCurrentRole()
    {
        await using var db = await Database();
        var settings = new Dictionary<string, string?> { ["Jwt:Key"] = "regression-test-key-at-least-thirty-two-characters", ["Jwt:Issuer"] = "test-issuer", ["Jwt:Audience"] = "test-audience" };
        var config = new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
        var account = await db.Taikhoans.Include(x => x.VaiTro).SingleAsync();
        var token = new TokenService(config).CreateAccessToken(account).Token;
        var handler = new JsonWebTokenHandler { MapInboundClaims = new JwtBearerOptions().MapInboundClaims };
        var validated = await handler.ValidateTokenAsync(token, new TokenValidationParameters {
            ValidateIssuer = true, ValidIssuer = settings["Jwt:Issuer"], ValidateAudience = true, ValidAudience = settings["Jwt:Audience"],
            ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings["Jwt:Key"]!)), ValidateLifetime = true });
        Assert.True(validated.IsValid, validated.Exception?.ToString());
        var context = TokenContext();
        context.Principal = new ClaimsPrincipal(validated.ClaimsIdentity);
        Assert.Equal("1", context.Principal.FindFirstValue(ClaimTypes.NameIdentifier));
        Assert.True(context.Principal.IsInRole("Customer"));
        await new AccountTokenValidation(db).TokenValidated(context);
        Assert.Null(context.Result);
    }
}
