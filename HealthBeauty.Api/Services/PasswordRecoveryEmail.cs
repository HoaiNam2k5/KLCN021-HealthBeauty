using System.Net;
using System.Net.Mail;
using System.Text;
using System.Threading.Channels;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace HealthBeauty.Api.Services;

public sealed record PasswordRecoveryEmail(
    int AccountId, string Email, string Otp, string ChallengeId, DateTime ExpiresAt);

public interface IPasswordRecoveryEmailQueue
{
    bool IsConfigured { get; }
    bool TryEnqueue(PasswordRecoveryEmail email);
}

public sealed class PasswordRecoveryEmailQueue(IOptions<SmtpOptions> options) : IPasswordRecoveryEmailQueue
{
    public const int Capacity = 100;
    private readonly Channel<PasswordRecoveryEmail> channel = Channel.CreateBounded<PasswordRecoveryEmail>(
        new BoundedChannelOptions(Capacity)
        {
            SingleReader = true,
            SingleWriter = false,
            FullMode = BoundedChannelFullMode.Wait,
            AllowSynchronousContinuations = false
        });

    public bool IsConfigured => options.Value.IsConfigured;
    public bool TryEnqueue(PasswordRecoveryEmail email) => IsConfigured && channel.Writer.TryWrite(email);
    public IAsyncEnumerable<PasswordRecoveryEmail> ReadAllAsync(CancellationToken cancellationToken) =>
        channel.Reader.ReadAllAsync(cancellationToken);
}

public interface IPasswordRecoveryEmailSender
{
    bool IsConfigured { get; }
    Task SendAsync(PasswordRecoveryEmail email, CancellationToken cancellationToken);
}

public sealed class SmtpPasswordRecoveryEmailSender(IOptions<SmtpOptions> options) : IPasswordRecoveryEmailSender
{
    public bool IsConfigured => options.Value.IsConfigured;

    public async Task SendAsync(PasswordRecoveryEmail email, CancellationToken cancellationToken)
    {
        if (!IsConfigured) throw new InvalidOperationException("Password recovery email is not configured.");
        var settings = options.Value;
        using var message = new MailMessage
        {
            From = new MailAddress(settings.SenderEmail, settings.SenderName, Encoding.UTF8),
            Subject = "HealthBeauty - Mã xác nhận đặt lại mật khẩu",
            SubjectEncoding = Encoding.UTF8,
            Body = BuildHtmlBody(email),
            BodyEncoding = Encoding.UTF8,
            IsBodyHtml = true
        };
        message.To.Add(new MailAddress(email.Email));
        using var client = new SmtpClient(settings.Host, settings.Port)
        {
            EnableSsl = true,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(settings.UserName, settings.Password),
            DeliveryMethod = SmtpDeliveryMethod.Network
        };
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(15));
        await client.SendMailAsync(message, timeout.Token);
    }

    public static string BuildHtmlBody(PasswordRecoveryEmail email)
    {
        var recipient = WebUtility.HtmlEncode(email.Email);
        var otp = WebUtility.HtmlEncode(email.Otp);
        return $"""
            <!doctype html><html lang="vi"><body style="font-family:Arial,sans-serif;color:#302523">
            <h2 style="color:#8c4559">HealthBeauty</h2>
            <p>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho {recipient}.</p>
            <p>Mã xác nhận của bạn:</p><p style="font-size:28px;font-weight:bold;letter-spacing:6px">{otp}</p>
            <p>Mã chỉ sử dụng một lần và có hiệu lực trong thời gian ngắn. Nếu mã hết hạn, hãy yêu cầu mã mới.</p>
            <p>Không chia sẻ mã này với bất kỳ ai. Nhân viên HealthBeauty không yêu cầu bạn cung cấp mã.</p>
            <p>Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.</p>
            </body></html>
            """;
    }
}

public sealed class PasswordRecoveryEmailWorker(
    PasswordRecoveryEmailQueue queue,
    IServiceScopeFactory scopeFactory,
    TimeProvider timeProvider,
    ILogger<PasswordRecoveryEmailWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!queue.IsConfigured)
            logger.LogWarning("Password recovery SMTP is disabled or incomplete; recovery emails cannot be sent.");
        await foreach (var email in queue.ReadAllAsync(stoppingToken))
        {
            try
            {
                await DeliverAsync(email, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception)
            {
                // Provider exception messages may contain addresses or SMTP credentials.
                logger.LogWarning("Password recovery delivery processing failed for account {AccountId}.", email.AccountId);
            }
        }
    }

    public async Task DeliverAsync(PasswordRecoveryEmail email, CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
        var challenge = await db.PasswordResetChallenges.Include(x => x.TaiKhoan)
            .SingleOrDefaultAsync(x => x.TaiKhoanId == email.AccountId, cancellationToken);
        var now = timeProvider.GetUtcNow().UtcDateTime;
        if (challenge is null || challenge.ChallengeId != email.ChallengeId || challenge.UsedAt.HasValue
            || challenge.OtpHash is null || challenge.ExpiresAt <= now || email.ExpiresAt <= now
            || !challenge.TaiKhoan.TrangThai || challenge.SecurityStampAtIssue != challenge.TaiKhoan.SecurityStamp
            || !string.Equals(challenge.TaiKhoan.Email, email.Email, StringComparison.OrdinalIgnoreCase)) return;

        try
        {
            var sender = scope.ServiceProvider.GetRequiredService<IPasswordRecoveryEmailSender>();
            await sender.SendAsync(email, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // The concurrency token prevents this failed delivery from invalidating a newer OTP.
            challenge.OtpHash = null;
            challenge.UsedAt = timeProvider.GetUtcNow().UtcDateTime;
            challenge.Version = Guid.NewGuid().ToString("N");
            try
            {
                await db.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                // A concurrent resend/reset already superseded this generation.
            }
            logger.LogWarning("Password recovery email delivery failed for account {AccountId}.", email.AccountId);
        }
    }
}

public static class PasswordRecoveryEmailRegistration
{
    public static IServiceCollection AddPasswordRecoveryEmail(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<SmtpOptions>(configuration.GetSection(SmtpOptions.SectionName));
        services.AddSingleton<PasswordRecoveryEmailQueue>();
        services.AddSingleton<IPasswordRecoveryEmailQueue>(provider => provider.GetRequiredService<PasswordRecoveryEmailQueue>());
        services.AddScoped<IPasswordRecoveryEmailSender, SmtpPasswordRecoveryEmailSender>();
        services.AddHostedService<PasswordRecoveryEmailWorker>();
        return services;
    }
}
