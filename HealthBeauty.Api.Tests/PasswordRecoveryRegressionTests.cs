using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class PasswordRecoveryRegressionTests
{
    internal sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = DateTimeOffset.UtcNow;
        public override DateTimeOffset GetUtcNow() => Now;
        public void Advance(TimeSpan by) => Now += by;
    }

    internal sealed class Queue : IPasswordRecoveryEmailQueue
    {
        public bool IsConfigured { get; set; } = true;
        public bool Accept { get; set; } = true;
        public List<PasswordRecoveryEmail> Messages { get; } = [];
        public bool TryEnqueue(PasswordRecoveryEmail email)
        {
            if (!Accept) return false;
            Messages.Add(email);
            return true;
        }
    }

    internal static IConfiguration Configuration() => new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
    {
        ["Jwt:Key"] = "password-recovery-isolated-tests-secret-at-least-32-characters",
        ["Jwt:Issuer"] = "RecoveryTests", ["Jwt:Audience"] = "RecoveryTests",
        ["PasswordRecovery:OtpHashKey"] = "password-recovery-isolated-tests-otp-key-at-least-32-characters"
    }).Build();

    private sealed class Fixture : IAsyncDisposable
    {
        public readonly DbContextOptions<Klcn021HealthBeautyContext> Options = new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        public readonly Klcn021HealthBeautyContext Db;
        public Fixture() => Db = new(Options);
        public readonly Clock Time = new();
        public readonly Queue Mail = new();
        public readonly PasswordService Passwords = new();
        public PasswordRecoveryService Service => new(Db, Passwords, Mail, Configuration(), Time);
        public async Task<Taikhoan> Seed(int id = 1, bool active = true)
        {
            var role = await Db.Vaitros.FindAsync(1);
            if (role is null) { role = new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" }; Db.Vaitros.Add(role); }
            var account = new Taikhoan { TaiKhoanId = id, Email = id == 1 ? "user@example.com" : "other@example.com",
                TenTaiKhoan = "Test", MatKhauHash = Passwords.Hash("old-password-123"), TrangThai = active, VaiTro = role, VaiTroId = 1 };
            Db.Taikhoans.Add(account);
            await Db.SaveChangesAsync();
            return account;
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    [Fact]
    public async Task ValidOtpChangesPasswordRevokesEverySessionClearsLockoutAndCannotBeReplayed()
    {
        await using var f = new Fixture(); var account = await f.Seed();
        account.SoLanDangNhapSai = 5; account.KhoaDen = f.Time.Now.UtcDateTime.AddMinutes(15);
        f.Db.Refreshtokens.AddRange(Enumerable.Range(1, 2).Select(i => new Refreshtoken { TaiKhoanId = 1,
            TokenHash = "refresh-" + i, CreatedAt = f.Time.Now.UtcDateTime, ExpiresAt = f.Time.Now.UtcDateTime.AddDays(1) }));
        await f.Db.SaveChangesAsync();
        await f.Service.RequestAsync(" USER@EXAMPLE.COM ", default);
        var email = Assert.Single(f.Mail.Messages);
        Assert.Matches("^[0-9]{6}$", email.Otp);
        Assert.Equal("user@example.com", email.Email);
        var stored = await f.Db.PasswordResetChallenges.SingleAsync();
        Assert.NotEqual(email.Otp, stored.OtpHash);
        Assert.DoesNotContain(email.Otp, stored.OtpHash!);
        Assert.True(await f.Service.ResetAsync("USER@example.com", email.Otp, "new-password-456", "127.0.0.1", default));
        Assert.True(f.Passwords.Verify("new-password-456", account.MatKhauHash));
        Assert.False(f.Passwords.Verify("old-password-123", account.MatKhauHash));
        Assert.False(string.IsNullOrWhiteSpace(account.SecurityStamp));
        Assert.Equal(0, account.SoLanDangNhapSai); Assert.Null(account.KhoaDen); Assert.True(account.TrangThai);
        Assert.All(await f.Db.Refreshtokens.ToListAsync(), token => Assert.NotNull(token.RevokedAt));
        Assert.Null(stored.OtpHash); Assert.NotNull(stored.UsedAt);
        Assert.False(await f.Service.ResetAsync(account.Email, email.Otp, "third-password-789", null, default));
        var audit = Assert.Single(await f.Db.Auditlogs.ToListAsync());
        var recorded = System.Text.Json.JsonSerializer.Serialize(audit, new System.Text.Json.JsonSerializerOptions {
            ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles });
        Assert.DoesNotContain(email.Otp, recorded);
        Assert.DoesNotContain("new-password-456", recorded);
    }

    [Theory]
    [InlineData(15)]
    [InlineData(16)]
    public async Task OtpExpiresAtDeadline(int minutes)
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.RequestAsync("user@example.com", default);
        f.Time.Advance(TimeSpan.FromMinutes(minutes));
        Assert.False(await f.Service.ResetAsync("user@example.com", Assert.Single(f.Mail.Messages).Otp, "new-password-456", null, default));
    }

    [Fact]
    public async Task FiveIncorrectAttemptsInvalidateEvenTheCorrectOtp()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.RequestAsync("user@example.com", default);
        var otp = Assert.Single(f.Mail.Messages).Otp;
        var wrong = otp == "000000" ? "111111" : "000000";
        for (var i = 0; i < 5; i++) Assert.False(await f.Service.ResetAsync("user@example.com", wrong, "new-password-456", null, default));
        Assert.False(await f.Service.ResetAsync("user@example.com", otp, "new-password-456", null, default));
    }

    [Fact]
    public async Task ResendCooldownPreservesCurrentCodeAndNewCodeInvalidatesPreviousGeneration()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.RequestAsync("user@example.com", default);
        var first = Assert.Single(f.Mail.Messages);
        await f.Service.RequestAsync("user@example.com", default); Assert.Single(f.Mail.Messages);
        f.Time.Advance(TimeSpan.FromSeconds(59)); await f.Service.RequestAsync("user@example.com", default); Assert.Single(f.Mail.Messages);
        f.Time.Advance(TimeSpan.FromSeconds(1)); await f.Service.RequestAsync("user@example.com", default); Assert.Equal(2, f.Mail.Messages.Count);
        Assert.NotEqual(first.ChallengeId, f.Mail.Messages[1].ChallengeId);
        // A fresh challenge must reject the previous code. Rare random equality is avoided explicitly.
        if (first.Otp != f.Mail.Messages[1].Otp) Assert.False(await f.Service.ResetAsync("user@example.com", first.Otp, "new-password-456", null, default));
        Assert.True(await f.Service.ResetAsync("user@example.com", f.Mail.Messages[1].Otp, "new-password-456", null, default));
    }

    [Fact]
    public async Task HourlyQuotaSurvivesServiceRecreationAndResetsAfterWindow()
    {
        await using var f = new Fixture(); await f.Seed();
        for (var i = 0; i < 6; i++) { await f.Service.RequestAsync("user@example.com", default); f.Time.Advance(TimeSpan.FromMinutes(1)); }
        Assert.Equal(5, f.Mail.Messages.Count);
        f.Time.Advance(TimeSpan.FromHours(1)); await f.Service.RequestAsync("user@example.com", default);
        Assert.Equal(6, f.Mail.Messages.Count);
    }

    [Fact]
    public async Task UnknownAndInactiveAccountsDoNotIssueChallengesOrMessages()
    {
        await using var f = new Fixture(); await f.Seed(active: false);
        await f.Service.RequestAsync("missing@example.com", default); await f.Service.RequestAsync("user@example.com", default);
        Assert.Empty(f.Mail.Messages); Assert.Empty(await f.Db.PasswordResetChallenges.ToListAsync());
    }

    [Theory]
    [InlineData("")]
    [InlineData("short")]
    [InlineData("        ")]
    public async Task InvalidPasswordDoesNotConsumeOtpAttempts(string password)
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.RequestAsync("user@example.com", default);
        var otp = Assert.Single(f.Mail.Messages).Otp;
        Assert.False(await f.Service.ResetAsync("user@example.com", otp, password, null, default));
        Assert.Equal(0, (await f.Db.PasswordResetChallenges.SingleAsync()).Attempts);
        Assert.True(await f.Service.ResetAsync("user@example.com", otp, "new-password-456", null, default));
    }

    [Fact]
    public async Task PasswordOver128CharactersIsRejectedWithoutBurningCode()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.RequestAsync("user@example.com", default);
        Assert.False(await f.Service.ResetAsync("user@example.com", f.Mail.Messages[0].Otp, new string('a', 129), null, default));
        Assert.Equal(0, (await f.Db.PasswordResetChallenges.SingleAsync()).Attempts);
    }

    [Fact]
    public async Task ChallengeCannotResetAnotherAccountAndSurvivesNewServiceInstance()
    {
        await using var f = new Fixture(); await f.Seed(); var other = await f.Seed(2);
        await f.Service.RequestAsync("user@example.com", default); var otp = Assert.Single(f.Mail.Messages).Otp;
        Assert.False(await f.Service.ResetAsync(other.Email, otp, "new-password-456", null, default));
        Assert.True(f.Passwords.Verify("old-password-123", other.MatKhauHash));
        Assert.True(await f.Service.ResetAsync("user@example.com", otp, "new-password-456", null, default));
    }

    [Fact]
    public async Task ChallengeAndAttemptCountSurviveCompletelyNewDatabaseContext()
    {
        await using var f = new Fixture(); await f.Seed();
        await f.Service.RequestAsync("user@example.com", default);
        var otp = Assert.Single(f.Mail.Messages).Otp;
        var wrong = otp == "000000" ? "111111" : "000000";
        Assert.False(await f.Service.ResetAsync("user@example.com", wrong, "new-password-456", null, default));
        await using var restarted = new Klcn021HealthBeautyContext(f.Options);
        Assert.Equal(1, (await restarted.PasswordResetChallenges.SingleAsync()).Attempts);
        var service = new PasswordRecoveryService(restarted, f.Passwords, f.Mail, Configuration(), f.Time);
        Assert.True(await service.ResetAsync("user@example.com", otp, "new-password-456", null, default));
        Assert.True(f.Passwords.Verify("new-password-456", (await restarted.Taikhoans.SingleAsync()).MatKhauHash));
    }

    [Fact]
    public async Task ChallengeIssuedBeforeAnotherPasswordChangeCannotBeUsed()
    {
        await using var f = new Fixture(); var account = await f.Seed();
        await f.Service.RequestAsync(account.Email, default);
        account.SecurityStamp = Guid.NewGuid().ToString("N");
        account.MatKhauHash = f.Passwords.Hash("changed-elsewhere-123");
        await f.Db.SaveChangesAsync();
        Assert.False(await f.Service.ResetAsync(account.Email, f.Mail.Messages[0].Otp, "new-password-456", null, default));
        Assert.True(f.Passwords.Verify("changed-elsewhere-123", account.MatKhauHash));
    }

    [Fact]
    public async Task AccountDisabledAfterIssuanceCannotBeReactivatedThroughReset()
    {
        await using var f = new Fixture(); var account = await f.Seed(); await f.Service.RequestAsync(account.Email, default);
        account.TrangThai = false; await f.Db.SaveChangesAsync();
        Assert.False(await f.Service.ResetAsync(account.Email, f.Mail.Messages[0].Otp, "new-password-456", null, default));
        Assert.False(account.TrangThai); Assert.True(f.Passwords.Verify("old-password-123", account.MatKhauHash));
    }

    [Fact]
    public async Task QueueRejectionInvalidatesNewChallengeAndUnconfiguredTransportSendsNothing()
    {
        await using var f = new Fixture(); await f.Seed(); f.Mail.Accept = false;
        await f.Service.RequestAsync("user@example.com", default); Assert.Empty(f.Mail.Messages);
        Assert.All(await f.Db.PasswordResetChallenges.ToListAsync(), challenge => Assert.Null(challenge.OtpHash));
        f.Mail.IsConfigured = false; f.Mail.Accept = true; f.Time.Advance(TimeSpan.FromHours(1));
        await f.Service.RequestAsync("user@example.com", default); Assert.Empty(f.Mail.Messages);
    }
    [Fact]
    public async Task TokenCreatedFromStaleAccountDuringResetRaceCannotRefreshSession()
    {
        await using var f = new Fixture(); var account = await f.Seed();
        await f.Service.RequestAsync(account.Email, default);
        Assert.True(await f.Service.ResetAsync(account.Email, f.Mail.Messages[0].Otp, "new-password-456", null, default));
        var tokenService = new TokenService(Configuration());
        // Simulate a refresh request that loaded the pre-reset account and issues its token after reset commits.
        f.Db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = account.TaiKhoanId,
            TokenHash = tokenService.HashRefreshToken("racing-stale-refresh"), SecurityStamp = null,
            CreatedAt = f.Time.Now.UtcDateTime, ExpiresAt = f.Time.Now.UtcDateTime.AddDays(1) });
        await f.Db.SaveChangesAsync();
        var auth = new HealthBeauty.Api.Controllers.AuthController(f.Db, f.Passwords, tokenService, Configuration());
        var result = await auth.Refresh(new HealthBeauty.Api.Contracts.RefreshRequest("racing-stale-refresh"), default);
        Assert.IsType<Microsoft.AspNetCore.Mvc.UnauthorizedObjectResult>(result.Result);
    }
    [Theory]
    [InlineData("")]
    [InlineData("short")]
    public void InvalidExplicitOtpHashKeyIsRejectedBeforeServingRequests(string key)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["Jwt:Key"] = "valid-jwt-key-at-least-32-characters", ["PasswordRecovery:OtpHashKey"] = key }).Build();
        Assert.Throws<InvalidOperationException>(() => PasswordRecoveryService.ValidateConfiguration(config));
    }
}
