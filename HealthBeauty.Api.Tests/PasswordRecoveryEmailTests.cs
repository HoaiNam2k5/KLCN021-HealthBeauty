using System.Net;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class PasswordRecoveryEmailTests
{
    private static SmtpOptions Settings() => new()
    {
        Enabled = true, EnableSsl = true, Host = "smtp.example.test", Port = 587,
        UserName = "fake-user", Password = "fake-secret", SenderEmail = "sender@example.test"
    };

    private static PasswordRecoveryEmail Message(DateTime now) =>
        new(1, "user@example.com", "123456", "generation-one", now.AddMinutes(15));

    [Fact]
    public void QueueRejectsOverflowWithoutDroppingPreviouslyAcceptedEmails()
    {
        var queue = new PasswordRecoveryEmailQueue(Options.Create(Settings()));
        var email = Message(DateTime.UtcNow);
        for (var i = 0; i < 100; i++) Assert.True(queue.TryEnqueue(email));
        Assert.False(queue.TryEnqueue(email));
    }

    [Theory]
    [InlineData("disabled")]
    [InlineData("tls-disabled")]
    [InlineData("missing-password")]
    public void InvalidTransportConfigurationDoesNotAcceptEmail(string invalid)
    {
        var settings = Settings();
        if (invalid == "disabled") settings.Enabled = false;
        if (invalid == "tls-disabled") settings.EnableSsl = false;
        if (invalid == "missing-password") settings.Password = "";
        var queue = new PasswordRecoveryEmailQueue(Options.Create(settings));
        Assert.False(queue.IsConfigured);
        Assert.False(queue.TryEnqueue(Message(DateTime.UtcNow)));
    }

    [Fact]
    public void EmailTemplateEncodesRecipientAndOtpAsHtmlText()
    {
        var email = Message(DateTime.UtcNow) with { Email = "<script>alert('recipient')</script>@example.com", Otp = "<b>123&456</b>" };
        var html = SmtpPasswordRecoveryEmailSender.BuildHtmlBody(email);
        Assert.Contains(WebUtility.HtmlEncode(email.Email), html);
        Assert.Contains(WebUtility.HtmlEncode(email.Otp), html);
        Assert.DoesNotContain(email.Email, html);
        Assert.DoesNotContain(email.Otp, html);
    }

    private sealed class Sender : IPasswordRecoveryEmailSender
    {
        public bool IsConfigured => true;
        public int Calls { get; private set; }
        public Func<Task>? Action { get; set; }
        public async Task SendAsync(PasswordRecoveryEmail email, CancellationToken cancellationToken)
        {
            Calls++;
            if (Action is not null) await Action();
        }
    }

    private sealed class Fixture : IAsyncDisposable
    {
        public readonly PasswordRecoveryRegressionTests.Clock Clock = new();
        public readonly Sender Mail = new();
        public readonly ServiceProvider Provider;
        public readonly PasswordRecoveryEmailWorker Worker;
        public Fixture()
        {
            var name = Guid.NewGuid().ToString();
            var services = new ServiceCollection();
            services.AddDbContext<Klcn021HealthBeautyContext>(options => options.UseInMemoryDatabase(name));
            services.AddSingleton<IPasswordRecoveryEmailSender>(Mail);
            Provider = services.BuildServiceProvider();
            Worker = new(new PasswordRecoveryEmailQueue(Options.Create(Settings())),
                Provider.GetRequiredService<IServiceScopeFactory>(), Clock,
                NullLogger<PasswordRecoveryEmailWorker>.Instance);
        }
        public async Task Seed(Action<PasswordResetChallenge>? mutate = null)
        {
            using var scope = Provider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var account = new Taikhoan { TaiKhoanId = 1, Email = "user@example.com", TenTaiKhoan = "Test",
                MatKhauHash = "fake-password-hash", TrangThai = true, VaiTroId = 1, SecurityStamp = "original-stamp" };
            var challenge = new PasswordResetChallenge { TaiKhoanId = 1, TaiKhoan = account,
                ChallengeId = "generation-one", Version = "version-one", OtpHash = "fake-otp-hash",
                ExpiresAt = Clock.Now.UtcDateTime.AddMinutes(15), LastRequestedAt = Clock.Now.UtcDateTime,
                SendWindowStartedAt = Clock.Now.UtcDateTime, SendCount = 1, SecurityStampAtIssue = account.SecurityStamp };
            mutate?.Invoke(challenge);
            db.Taikhoans.Add(account); db.PasswordResetChallenges.Add(challenge);
            await db.SaveChangesAsync();
        }
        public async Task<PasswordResetChallenge> Read()
        {
            using var scope = Provider.CreateScope();
            return await scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>()
                .PasswordResetChallenges.AsNoTracking().SingleAsync();
        }
        public async ValueTask DisposeAsync() { Worker.Dispose(); await Provider.DisposeAsync(); }
    }

    [Theory]
    [InlineData("generation")]
    [InlineData("expired")]
    [InlineData("message-expired")]
    [InlineData("used")]
    [InlineData("inactive")]
    [InlineData("stamp")]
    [InlineData("email")]
    [InlineData("missing-hash")]
    public async Task WorkerSkipsMessagesThatAreNoLongerEligible(string reason)
    {
        await using var f = new Fixture();
        await f.Seed(challenge =>
        {
            switch (reason)
            {
                case "generation": challenge.ChallengeId = "new-generation"; break;
                case "expired": challenge.ExpiresAt = f.Clock.Now.UtcDateTime; break;
                case "used": challenge.UsedAt = f.Clock.Now.UtcDateTime; break;
                case "inactive": challenge.TaiKhoan.TrangThai = false; break;
                case "stamp": challenge.TaiKhoan.SecurityStamp = "changed-stamp"; break;
                case "email": challenge.TaiKhoan.Email = "changed@example.com"; break;
                case "missing-hash": challenge.OtpHash = null; break;
            }
        });
        var email = Message(f.Clock.Now.UtcDateTime);
        if (reason == "message-expired") email = email with { ExpiresAt = f.Clock.Now.UtcDateTime };
        await f.Worker.DeliverAsync(email, default);
        Assert.Equal(0, f.Mail.Calls);
    }

    [Fact]
    public async Task SuccessfulDeliveryKeepsChallengeAvailableForReset()
    {
        await using var f = new Fixture(); await f.Seed();
        await f.Worker.DeliverAsync(Message(f.Clock.Now.UtcDateTime), default);
        Assert.Equal(1, f.Mail.Calls);
        var challenge = await f.Read();
        Assert.Equal("fake-otp-hash", challenge.OtpHash); Assert.Null(challenge.UsedAt);
    }

    [Fact]
    public async Task FailedDeliveryInvalidatesItsOwnChallenge()
    {
        await using var f = new Fixture(); await f.Seed();
        f.Mail.Action = () => throw new InvalidOperationException("Simulated SMTP failure");
        await f.Worker.DeliverAsync(Message(f.Clock.Now.UtcDateTime), default);
        Assert.Equal(1, f.Mail.Calls);
        var challenge = await f.Read();
        Assert.Null(challenge.OtpHash); Assert.NotNull(challenge.UsedAt);
    }

    [Fact]
    public async Task FailedOldDeliveryCannotInvalidateConcurrentlyCreatedNewChallenge()
    {
        await using var f = new Fixture(); await f.Seed();
        f.Mail.Action = async () =>
        {
            using var scope = f.Provider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var current = await db.PasswordResetChallenges.SingleAsync();
            current.ChallengeId = "generation-two"; current.Version = "version-two";
            current.OtpHash = "new-otp-hash"; await db.SaveChangesAsync();
            throw new InvalidOperationException("Simulated late SMTP failure");
        };
        await f.Worker.DeliverAsync(Message(f.Clock.Now.UtcDateTime), default);
        var challenge = await f.Read();
        Assert.Equal("generation-two", challenge.ChallengeId);
        Assert.Equal("new-otp-hash", challenge.OtpHash); Assert.Null(challenge.UsedAt);
    }
}
