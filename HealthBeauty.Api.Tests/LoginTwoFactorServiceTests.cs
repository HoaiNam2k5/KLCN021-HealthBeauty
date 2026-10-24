using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class LoginTwoFactorServiceTests
{
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = new(2026, 10, 23, 8, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
        public void Advance(TimeSpan interval) => Now += interval;
    }

    private sealed class MailQueue : ILoginTwoFactorEmailQueue
    {
        public bool IsConfigured { get; set; } = true;
        public bool Accept { get; set; } = true;
        public List<LoginTwoFactorEmail> Messages { get; } = [];
        public bool TryEnqueue(LoginTwoFactorEmail email)
        {
            if (!Accept) return false;
            Messages.Add(email); return true;
        }
    }

    private sealed class Fixture : IAsyncDisposable
    {
        public DbContextOptions<Klcn021HealthBeautyContext> Options { get; } = new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        public Klcn021HealthBeautyContext Db { get; }
        public Clock Time { get; } = new();
        public MailQueue Mail { get; } = new();
        public IConfiguration Config { get; } = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["Jwt:Key"] = "login-two-factor-tests-key-longer-than-32-characters",
            ["Authentication:TwoFactor:Enabled"] = "true"
        }).Build();
        public LoginTwoFactorService Service => new(Db, Mail, Config, Time);
        public Fixture() => Db = new(Options);
        public async Task<Taikhoan> Seed(string role = "Customer")
        {
            var account = new Taikhoan { TaiKhoanId = 1, Email = "customer@example.test", TrangThai = true,
                MatKhauHash = "not-used-in-otp-tests", SecurityStamp = "stamp-one", VaiTroId = 1,
                VaiTro = new Vaitro { VaiTroId = 1, TenVaiTro = role } };
            Db.Taikhoans.Add(account); await Db.SaveChangesAsync(); return account;
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    [Fact]
    public async Task CorrectOtpIsHashedBoundToAccountAndSingleUseAcrossContexts()
    {
        await using var f = new Fixture(); await f.Seed();
        Assert.True(await f.Service.StartAsync(1));
        var email = Assert.Single(f.Mail.Messages);
        Assert.Matches("^[0-9]{6}$", email.Otp);
        var stored = await f.Db.LoginTwoFactorChallenges.SingleAsync();
        Assert.NotEqual(email.Otp, stored.OtpHash);
        Assert.Equal(64, stored.OtpHash!.Length);
        await using var second = new Klcn021HealthBeautyContext(f.Options);
        var service = new LoginTwoFactorService(second, f.Mail, f.Config, f.Time);
        var account = await service.VerifyAsync(" CUSTOMER@EXAMPLE.TEST ", email.Otp);
        Assert.NotNull(account); Assert.Equal(1, account.TaiKhoanId);
        Assert.Null(await service.VerifyAsync(email.Email, email.Otp));
        Assert.Empty(await second.PasswordResetChallenges.ToListAsync());
    }

    [Fact]
    public async Task WrongAttemptsPersistAcrossServiceRestartAndLockAfterFiveGuesses()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.StartAsync(1);
        var email = f.Mail.Messages.Single(); var wrong = email.Otp == "000000" ? "111111" : "000000";
        for (var i = 1; i <= 5; i++)
        {
            await using var context = new Klcn021HealthBeautyContext(f.Options);
            var service = new LoginTwoFactorService(context, f.Mail, f.Config, f.Time);
            Assert.Null(await service.VerifyAsync(email.Email, wrong));
            Assert.Equal(i, (await context.LoginTwoFactorChallenges.SingleAsync()).Attempts);
        }
        await using var restarted = new Klcn021HealthBeautyContext(f.Options);
        Assert.Null(await new LoginTwoFactorService(restarted, f.Mail, f.Config, f.Time).VerifyAsync(email.Email, email.Otp));
        Assert.NotNull((await restarted.LoginTwoFactorChallenges.SingleAsync()).UsedAt);
    }

    [Theory]
    [InlineData("expired")]
    [InlineData("inactive")]
    [InlineData("locked")]
    [InlineData("stamp-changed")]
    [InlineData("role-changed")]
    [InlineData("disabled")]
    public async Task AccountAndChallengeInvalidationRejectOtp(string invalidation)
    {
        await using var f = new Fixture(); var account = await f.Seed(); await f.Service.StartAsync(1);
        var email = f.Mail.Messages.Single();
        if (invalidation == "expired") f.Time.Advance(TimeSpan.FromMinutes(5));
        if (invalidation == "inactive") account.TrangThai = false;
        if (invalidation == "locked") account.KhoaDen = f.Time.Now.UtcDateTime.AddMinutes(1);
        if (invalidation == "stamp-changed") account.SecurityStamp = "stamp-two";
        if (invalidation == "role-changed") account.VaiTro.TenVaiTro = "Admin";
        if (invalidation == "disabled") f.Config["Authentication:TwoFactor:Enabled"] = "false";
        await f.Db.SaveChangesAsync();
        Assert.Null(await f.Service.VerifyAsync(email.Email, email.Otp));
        Assert.False(await f.Service.ResendAsync(email.Email));
    }

    [Fact]
    public async Task ResendCannotCreateChallengeFromEmailWithoutPasswordProof()
    {
        await using var f = new Fixture(); await f.Seed();
        Assert.False(await f.Service.ResendAsync("customer@example.test"));
        Assert.Empty(f.Mail.Messages); Assert.Empty(await f.Db.LoginTwoFactorChallenges.ToListAsync());
    }

    [Fact]
    public async Task ResendWaitsSixtySecondsRotatesCodeAndCannotExtendOriginalPasswordProof()
    {
        await using var f = new Fixture(); await f.Seed(); Assert.True(await f.Service.StartAsync(1));
        var first = f.Mail.Messages.Single();
        Assert.False(await f.Service.ResendAsync(first.Email));
        f.Time.Advance(TimeSpan.FromSeconds(60));
        Assert.True(await f.Service.ResendAsync(first.Email));
        var next = f.Mail.Messages.Last();
        Assert.NotEqual(first.ChallengeId, next.ChallengeId);
        Assert.Equal(first.ExpiresAt, next.ExpiresAt);
        f.Time.Advance(TimeSpan.FromMinutes(4));
        Assert.False(await f.Service.ResendAsync(first.Email));
        Assert.Null(await f.Service.VerifyAsync(next.Email, next.Otp));
    }

    [Fact]
    public async Task ResendingDoesNotResetCountedWrongGuesses()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.StartAsync(1);
        var first = f.Mail.Messages.Single(); var wrong = first.Otp == "000000" ? "111111" : "000000";
        for (var i = 0; i < 4; i++) Assert.Null(await f.Service.VerifyAsync(first.Email, wrong));
        f.Time.Advance(TimeSpan.FromSeconds(61)); Assert.True(await f.Service.ResendAsync(first.Email));
        var next = f.Mail.Messages.Last(); wrong = next.Otp == "000000" ? "111111" : "000000";
        Assert.Equal(4, (await f.Db.LoginTwoFactorChallenges.SingleAsync()).Attempts);
        Assert.Null(await f.Service.VerifyAsync(next.Email, wrong));
        Assert.Null(await f.Service.VerifyAsync(next.Email, next.Otp));
    }

    [Fact]
    public async Task UsedOtpCannotBeResentAndRecentRepeatedLoginKeepsSamePendingChallenge()
    {
        await using var f = new Fixture(); await f.Seed(); Assert.True(await f.Service.StartAsync(1));
        Assert.True(await f.Service.StartAsync(1)); Assert.Single(f.Mail.Messages);
        var message = f.Mail.Messages.Single(); Assert.NotNull(await f.Service.VerifyAsync(message.Email, message.Otp));
        f.Time.Advance(TimeSpan.FromSeconds(61));
        Assert.False(await f.Service.ResendAsync(message.Email));
        Assert.Single(f.Mail.Messages);
    }

    [Fact]
    public async Task HourlyCapSurvivesExpiredChallengeAndPasswordVerifiedLogin()
    {
        await using var f = new Fixture(); await f.Seed();
        for (var i = 0; i < 5; i++) { Assert.True(await f.Service.StartAsync(1)); f.Time.Advance(TimeSpan.FromSeconds(61)); }
        Assert.False(await f.Service.StartAsync(1)); Assert.Equal(5, f.Mail.Messages.Count);
        f.Time.Advance(TimeSpan.FromHours(1)); Assert.True(await f.Service.StartAsync(1));
        Assert.Equal(1, (await f.Db.LoginTwoFactorChallenges.SingleAsync()).SendCount);
    }

    [Theory]
    [InlineData("disabled")]
    [InlineData("not-configured")]
    [InlineData("admin")]
    [InlineData("inactive")]
    public async Task DisabledOrUnsupportedAccountDoesNotCreateChallenge(string invalid)
    {
        await using var f = new Fixture(); var account = await f.Seed(invalid == "admin" ? "Admin" : "Customer");
        if (invalid == "disabled") f.Config["Authentication:TwoFactor:Enabled"] = "false";
        if (invalid == "not-configured") f.Mail.IsConfigured = false;
        if (invalid == "inactive") account.TrangThai = false;
        await f.Db.SaveChangesAsync(); Assert.False(await f.Service.StartAsync(1));
        Assert.Empty(await f.Db.LoginTwoFactorChallenges.ToListAsync()); Assert.Empty(f.Mail.Messages);
    }

    [Fact]
    public async Task QueueFailureInvalidatesUnsentChallenge()
    {
        await using var f = new Fixture(); await f.Seed(); f.Mail.Accept = false;
        Assert.False(await f.Service.StartAsync(1));
        var entry = await f.Db.LoginTwoFactorChallenges.SingleAsync();
        Assert.Null(entry.OtpHash); Assert.NotNull(entry.UsedAt);
    }

    [Fact]
    public async Task SuccessfulVerificationRejectsOtherEmail()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.StartAsync(1);
        var message = f.Mail.Messages.Single();
        Assert.Null(await f.Service.VerifyAsync("other@example.test", message.Otp));
        Assert.NotNull(await f.Service.VerifyAsync(message.Email, message.Otp));
    }

    [Fact]
    public async Task PasswordResetChallengeCannotBeUsedForLogin()
    {
        await using var f = new Fixture(); await f.Seed();
        f.Db.PasswordResetChallenges.Add(new PasswordResetChallenge { TaiKhoanId = 1, ChallengeId = "reset-generation",
            Version = "reset-version", OtpHash = "not-a-login-hash", ExpiresAt = f.Time.Now.UtcDateTime.AddMinutes(15),
            LastRequestedAt = f.Time.Now.UtcDateTime, SendWindowStartedAt = f.Time.Now.UtcDateTime, SendCount = 1 });
        await f.Db.SaveChangesAsync();
        Assert.Null(await f.Service.VerifyAsync("customer@example.test", "123456"));
        Assert.Null((await f.Db.PasswordResetChallenges.SingleAsync()).UsedAt);
        Assert.Empty(await f.Db.LoginTwoFactorChallenges.ToListAsync());
    }

    [Fact]
    public void MailQueueIsBoundedAndLoginBodyEscapesContent()
    {
        var settings = new SmtpOptions { Enabled = true, Host = "smtp.example.test", UserName = "user", Password = "fake",
            SenderEmail = "sender@example.test" };
        var queue = new LoginTwoFactorEmailQueue(Options.Create(settings));
        var message = new LoginTwoFactorEmail(1, "<customer@example.test>", "123456", "generation", DateTime.UtcNow.AddMinutes(5));
        for (var i = 0; i < LoginTwoFactorEmailQueue.Capacity; i++) Assert.True(queue.TryEnqueue(message));
        Assert.False(queue.TryEnqueue(message));
        var body = SmtpLoginTwoFactorEmailSender.BuildHtmlBody(message);
        Assert.Contains("&lt;customer@example.test&gt;", body); Assert.Contains("123456", body);
        Assert.DoesNotContain("<customer@example.test>", body);
    }

    private sealed class FailingSender : ILoginTwoFactorEmailSender
    {
        public int Calls { get; private set; }
        public Task SendAsync(LoginTwoFactorEmail email, CancellationToken ct) { Calls++; throw new InvalidOperationException("fake failure"); }
    }

    [Fact]
    public async Task MailWorkerSkipsSupersededChallengeAndInvalidatesFailedCurrentDelivery()
    {
        await using var f = new Fixture(); await f.Seed(); await f.Service.StartAsync(1);
        var first = f.Mail.Messages.Single(); f.Time.Advance(TimeSpan.FromSeconds(61)); await f.Service.ResendAsync(first.Email);
        var latest = f.Mail.Messages.Last(); var sender = new FailingSender();
        var services = new ServiceCollection().AddSingleton(f.Config).AddScoped(_ => new Klcn021HealthBeautyContext(f.Options))
            .AddSingleton<ILoginTwoFactorEmailSender>(sender).BuildServiceProvider();
        using var provider = services;
        var queue = new LoginTwoFactorEmailQueue(Options.Create(new SmtpOptions()));
        var worker = new LoginTwoFactorEmailWorker(queue, provider.GetRequiredService<IServiceScopeFactory>(), f.Time,
            NullLogger<LoginTwoFactorEmailWorker>.Instance);
        await worker.DeliverAsync(first, default); Assert.Equal(0, sender.Calls);
        await worker.DeliverAsync(latest, default); Assert.Equal(1, sender.Calls);
        await using var check = new Klcn021HealthBeautyContext(f.Options);
        Assert.Null((await check.LoginTwoFactorChallenges.SingleAsync()).OtpHash);
    }
}
