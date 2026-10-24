using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;
using HealthBeauty.Api.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public sealed class LoginTwoFactorService(
    Klcn021HealthBeautyContext db, ILoginTwoFactorEmailQueue queue, IConfiguration config, TimeProvider clock)
{
    public const int OtpMinutes = 5;
    public const int MaxAttempts = 5;
    private DateTime Now => clock.GetUtcNow().UtcDateTime;
    public bool Enabled => config.GetValue<bool>("Authentication:TwoFactor:Enabled");
    public bool IsConfigured => queue.IsConfigured;
    public bool IsRequired(Taikhoan account) => Enabled && account.VaiTro?.TenVaiTro == "Customer";
    private static bool ValidEmail(string? email) => !string.IsNullOrWhiteSpace(email)
        && email.Trim().Length <= 255 && new EmailAddressAttribute().IsValid(email.Trim());
    private static string Normalize(string email) => email.Trim().ToLowerInvariant();

    private string Hash(int accountId, string challengeId, string otp)
    {
        var key = config["Authentication:TwoFactor:OtpHashKey"] ?? config["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(key) || key.Length < 32)
            throw new InvalidOperationException("Configure a login OTP hash key with at least 32 characters.");
        return Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(key),
            Encoding.UTF8.GetBytes($"HealthBeauty:LoginTwoFactor:{accountId}:{challengeId}:{otp}")));
    }

    private bool ValidAccount(Taikhoan account, DateTime now) => IsRequired(account) && account.TrangThai
        && (!account.KhoaDen.HasValue || account.KhoaDen <= now);

    private static bool Pending(LoginTwoFactorChallenge entry, Taikhoan account, DateTime now) =>
        entry.OtpHash is not null && !entry.UsedAt.HasValue && entry.ExpiresAt > now
        && entry.PasswordVerifiedAt.AddMinutes(OtpMinutes) > now
        && entry.Attempts < MaxAttempts && entry.SecurityStampAtIssue == account.SecurityStamp;

    // The controller must call this only after successfully checking the password.
    public async Task<bool> StartAsync(int accountId, CancellationToken ct = default)
    {
        if (!Enabled || !queue.IsConfigured) return false;
        var account = await db.Taikhoans.Include(x => x.VaiTro).FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        var now = Now;
        if (account is null || !ValidAccount(account, now)) return false;
        var entry = await db.LoginTwoFactorChallenges.FindAsync([accountId], ct);
        if (entry is not null && now - entry.LastRequestedAt < TimeSpan.FromSeconds(60))
            return Pending(entry, account, now);
        if (entry is not null && now - entry.SendWindowStartedAt < TimeSpan.FromHours(1) && entry.SendCount >= 5) return false;
        if (entry is null)
        {
            entry = new LoginTwoFactorChallenge { TaiKhoanId = accountId, SendWindowStartedAt = now };
            db.LoginTwoFactorChallenges.Add(entry);
        }
        entry.PasswordVerifiedAt = now;
        entry.Attempts = 0;
        return await IssueAsync(entry, account, now, ct);
    }

    // Email alone is not proof of the password: never create or revive a challenge here.
    public async Task<bool> ResendAsync(string email, CancellationToken ct = default)
    {
        if (!Enabled || !queue.IsConfigured || !ValidEmail(email)) return false;
        email = Normalize(email);
        var entry = await db.LoginTwoFactorChallenges.Include(x => x.TaiKhoan).ThenInclude(x => x.VaiTro)
            .FirstOrDefaultAsync(x => x.TaiKhoan.Email.ToLower() == email, ct);
        var now = Now;
        if (entry is null || !ValidAccount(entry.TaiKhoan, now) || !Pending(entry, entry.TaiKhoan, now)
            || now - entry.LastRequestedAt < TimeSpan.FromSeconds(60)
            || (now - entry.SendWindowStartedAt < TimeSpan.FromHours(1) && entry.SendCount >= 5)) return false;
        return await IssueAsync(entry, entry.TaiKhoan, now, ct);
    }

    private async Task<bool> IssueAsync(LoginTwoFactorChallenge entry, Taikhoan account, DateTime now, CancellationToken ct)
    {
        if (now - entry.SendWindowStartedAt >= TimeSpan.FromHours(1))
        {
            entry.SendWindowStartedAt = now; entry.SendCount = 0;
        }
        var otp = RandomNumberGenerator.GetInt32(1_000_000).ToString("D6", System.Globalization.CultureInfo.InvariantCulture);
        entry.ChallengeId = Guid.NewGuid().ToString("N"); entry.Version = Guid.NewGuid().ToString("N");
        entry.OtpHash = Hash(account.TaiKhoanId, entry.ChallengeId, otp);
        // A resend cannot extend proof of a correct password beyond the original five minutes.
        entry.ExpiresAt = entry.PasswordVerifiedAt.AddMinutes(OtpMinutes);
        entry.UsedAt = null; entry.LastRequestedAt = now; entry.SendCount++;
        entry.SecurityStampAtIssue = account.SecurityStamp;
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { db.ChangeTracker.Clear(); return false; }
        catch (DbUpdateException e) when (e.InnerException is SqlException { Number: 2601 or 2627 })
        { db.ChangeTracker.Clear(); return false; }
        if (queue.TryEnqueue(new LoginTwoFactorEmail(account.TaiKhoanId, account.Email, otp, entry.ChallengeId, entry.ExpiresAt))) return true;
        entry.OtpHash = null; entry.UsedAt = Now; entry.Version = Guid.NewGuid().ToString("N");
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { db.ChangeTracker.Clear(); }
        return false;
    }

    public async Task<Taikhoan?> VerifyAsync(string email, string otp, CancellationToken ct = default)
    {
        if (!Enabled || !ValidEmail(email) || otp is null || otp.Length != 6 || otp.Any(x => x < '0' || x > '9')) return null;
        email = Normalize(email);
        for (var retry = 0; retry < 3; retry++)
        {
            await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(ct) : null;
            try
            {
                var account = await db.Taikhoans.Include(x => x.VaiTro).FirstOrDefaultAsync(x => x.Email.ToLower() == email, ct);
                var now = Now;
                if (account is null || !ValidAccount(account, now)) return null;
                var entry = await db.LoginTwoFactorChallenges.FindAsync([account.TaiKhoanId], ct);
                if (entry is null || !Pending(entry, account, now)) return null;
                var expected = entry.OtpHash!;
                entry.Attempts++; entry.Version = Guid.NewGuid().ToString("N");
                if (entry.Attempts == MaxAttempts) { entry.OtpHash = null; entry.UsedAt = now; }
                // Persist a counted guess before comparison; concurrent losing requests retry current state.
                await db.SaveChangesAsync(ct);
                var actual = Hash(account.TaiKhoanId, entry.ChallengeId, otp);
                if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected), Encoding.ASCII.GetBytes(actual)))
                {
                    if (transaction is not null) await transaction.CommitAsync(ct);
                    return null;
                }
                entry.OtpHash = null; entry.UsedAt = now; entry.Version = Guid.NewGuid().ToString("N");
                account.LanDangNhapCuoi = now;
                await db.SaveChangesAsync(ct);
                if (transaction is not null) await transaction.CommitAsync(ct);
                return account;
            }
            catch (DbUpdateConcurrencyException)
            {
                if (transaction is not null) await transaction.RollbackAsync(ct);
                db.ChangeTracker.Clear();
            }
            catch (DbUpdateException e) when (e.InnerException is SqlException { Number: 1205 })
            {
                if (transaction is not null) await transaction.RollbackAsync(ct);
                db.ChangeTracker.Clear();
            }
        }
        return null;
    }
}
