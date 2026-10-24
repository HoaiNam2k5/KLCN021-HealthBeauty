using System.Net;
using System.Net.Mail;
using System.Text;
using System.Threading.Channels;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace HealthBeauty.Api.Services;

public sealed record LoginTwoFactorEmail(int AccountId, string Email, string Otp, string ChallengeId, DateTime ExpiresAt);

public interface ILoginTwoFactorEmailQueue
{
    bool IsConfigured { get; }
    bool TryEnqueue(LoginTwoFactorEmail email);
}

public sealed class LoginTwoFactorEmailQueue(IOptions<SmtpOptions> options) : ILoginTwoFactorEmailQueue
{
    public const int Capacity = 100;
    private readonly Channel<LoginTwoFactorEmail> channel = Channel.CreateBounded<LoginTwoFactorEmail>(
        new BoundedChannelOptions(Capacity) { SingleReader = true, SingleWriter = false,
            FullMode = BoundedChannelFullMode.Wait, AllowSynchronousContinuations = false });
    public bool IsConfigured => options.Value.IsConfigured;
    public bool TryEnqueue(LoginTwoFactorEmail email) => IsConfigured && channel.Writer.TryWrite(email);
    public IAsyncEnumerable<LoginTwoFactorEmail> ReadAllAsync(CancellationToken ct) => channel.Reader.ReadAllAsync(ct);
}

public interface ILoginTwoFactorEmailSender
{
    Task SendAsync(LoginTwoFactorEmail email, CancellationToken ct);
}

public sealed class SmtpLoginTwoFactorEmailSender(IOptions<SmtpOptions> options) : ILoginTwoFactorEmailSender
{
    public async Task SendAsync(LoginTwoFactorEmail email, CancellationToken ct)
    {
        var settings = options.Value;
        if (!settings.IsConfigured) throw new InvalidOperationException("Login OTP email is not configured.");
        using var message = new MailMessage
        {
            From = new MailAddress(settings.SenderEmail, settings.SenderName, Encoding.UTF8),
            Subject = "HealthBeauty - Mã xác nhận đăng nhập",
            SubjectEncoding = Encoding.UTF8, BodyEncoding = Encoding.UTF8,
            IsBodyHtml = true, Body = BuildHtmlBody(email)
        };
        message.To.Add(new MailAddress(email.Email));
        using var client = new SmtpClient(settings.Host, settings.Port)
        {
            EnableSsl = true, UseDefaultCredentials = false,
            Credentials = new NetworkCredential(settings.UserName, settings.Password),
            DeliveryMethod = SmtpDeliveryMethod.Network
        };
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(15));
        await client.SendMailAsync(message, timeout.Token);
    }

    public static string BuildHtmlBody(LoginTwoFactorEmail email) => $"""
        <!doctype html><html lang="vi"><body style="font-family:Arial,sans-serif;color:#302523">
        <h2>HealthBeauty</h2><p>Mã xác nhận đăng nhập cho {WebUtility.HtmlEncode(email.Email)}:</p>
        <p style="font-size:28px;font-weight:bold;letter-spacing:6px">{WebUtility.HtmlEncode(email.Otp)}</p>
        <p>Mã chỉ dùng một lần, có hiệu lực tối đa 5 phút kể từ khi xác thực mật khẩu.</p>
        <p>Không chia sẻ mã với bất kỳ ai. Nếu bạn không đăng nhập, hãy đổi mật khẩu tài khoản.</p>
        </body></html>
        """;
}

public sealed class LoginTwoFactorEmailWorker(LoginTwoFactorEmailQueue queue, IServiceScopeFactory scopeFactory,
    TimeProvider clock, ILogger<LoginTwoFactorEmailWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var email in queue.ReadAllAsync(stoppingToken))
        {
            try { await DeliverAsync(email, stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
            catch (Exception) { logger.LogWarning("Login OTP processing failed for account {AccountId}.", email.AccountId); }
        }
    }

    public async Task DeliverAsync(LoginTwoFactorEmail email, CancellationToken ct)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
        var entry = await db.LoginTwoFactorChallenges.Include(x => x.TaiKhoan).ThenInclude(x => x.VaiTro)
            .SingleOrDefaultAsync(x => x.TaiKhoanId == email.AccountId, ct);
        var now = clock.GetUtcNow().UtcDateTime;
        var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        if (!configuration.GetValue<bool>("Authentication:TwoFactor:Enabled") || entry is null
            || entry.ChallengeId != email.ChallengeId || entry.UsedAt.HasValue || entry.OtpHash is null
            || entry.ExpiresAt <= now || email.ExpiresAt <= now || entry.Attempts >= LoginTwoFactorService.MaxAttempts
            || !entry.TaiKhoan.TrangThai || entry.TaiKhoan.KhoaDen > now || entry.TaiKhoan.VaiTro.TenVaiTro != "Customer"
            || entry.SecurityStampAtIssue != entry.TaiKhoan.SecurityStamp
            || !string.Equals(entry.TaiKhoan.Email, email.Email, StringComparison.OrdinalIgnoreCase)) return;
        try { await scope.ServiceProvider.GetRequiredService<ILoginTwoFactorEmailSender>().SendAsync(email, ct); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception)
        {
            entry.OtpHash = null; entry.UsedAt = clock.GetUtcNow().UtcDateTime; entry.Version = Guid.NewGuid().ToString("N");
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateConcurrencyException) { }
            // Do not log provider exceptions: they can contain SMTP credentials or OTP content.
            logger.LogWarning("Login OTP email delivery failed for account {AccountId}.", email.AccountId);
        }
    }
}

public static class LoginTwoFactorRegistration
{
    public static IServiceCollection AddLoginTwoFactor(this IServiceCollection services, IConfiguration config)
    {
        services.Configure<SmtpOptions>(config.GetSection(SmtpOptions.SectionName));
        services.AddSingleton<LoginTwoFactorEmailQueue>();
        services.AddSingleton<ILoginTwoFactorEmailQueue>(sp => sp.GetRequiredService<LoginTwoFactorEmailQueue>());
        services.AddScoped<ILoginTwoFactorEmailSender, SmtpLoginTwoFactorEmailSender>();
        services.AddScoped<LoginTwoFactorService>();
        services.AddHostedService<LoginTwoFactorEmailWorker>();
        return services;
    }
}
