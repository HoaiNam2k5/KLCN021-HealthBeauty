using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;
using HealthBeauty.Api.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public sealed class PasswordRecoveryService(
    Klcn021HealthBeautyContext db, IPasswordService passwords, IPasswordRecoveryEmailQueue queue,
    IConfiguration config, TimeProvider clock)
{
    public const int OtpMinutes = 15;
    public const int MaxAttempts = 5;
    private DateTime Now => clock.GetUtcNow().UtcDateTime;
    private static string Normalize(string email) => email.Trim().ToLowerInvariant();
    private static bool ValidEmail(string? email) => !string.IsNullOrWhiteSpace(email)
        && email.Trim().Length <= 255 && new EmailAddressAttribute().IsValid(email.Trim());

    private string Hash(int accountId, string challengeId, string otp)
    {
        var key = GetHashKey(config);
        return Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(key),
            Encoding.UTF8.GetBytes($"HealthBeauty:PasswordRecovery:{accountId}:{challengeId}:{otp}")));
    }

    public static void ValidateConfiguration(IConfiguration configuration) => _ = GetHashKey(configuration);

    private static string GetHashKey(IConfiguration configuration)
    {
        var key = configuration["PasswordRecovery:OtpHashKey"] ?? configuration["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(key) || key.Length < 32)
            throw new InvalidOperationException("Configure a password recovery hash key with at least 32 characters.");
        return key;
    }

    public async Task RequestAsync(string email, CancellationToken ct)
    {
        if (!ValidEmail(email) || !queue.IsConfigured) return;
        email = Normalize(email);
        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(ct) : null;
        var account = await db.Taikhoans.AsNoTracking().FirstOrDefaultAsync(x => x.Email.ToLower() == email && x.TrangThai, ct);
        if (account is null) return;
        var now = Now;
        var entry = await db.PasswordResetChallenges.FindAsync([account.TaiKhoanId], ct);
        if (entry is not null && now - entry.LastRequestedAt < TimeSpan.FromSeconds(60)) return;
        if (entry is not null && now - entry.SendWindowStartedAt < TimeSpan.FromHours(1) && entry.SendCount >= 5) return;
        if (entry is null)
        {
            entry = new PasswordResetChallenge { TaiKhoanId = account.TaiKhoanId, SendWindowStartedAt = now };
            db.PasswordResetChallenges.Add(entry);
        }
        if (now - entry.SendWindowStartedAt >= TimeSpan.FromHours(1))
        {
            entry.SendWindowStartedAt = now; entry.SendCount = 0;
        }
        var otp = RandomNumberGenerator.GetInt32(1_000_000).ToString("D6", System.Globalization.CultureInfo.InvariantCulture);
        entry.ChallengeId = Guid.NewGuid().ToString("N"); entry.Version = Guid.NewGuid().ToString("N");
        entry.OtpHash = Hash(account.TaiKhoanId, entry.ChallengeId, otp);
        entry.ExpiresAt = now.AddMinutes(OtpMinutes); entry.Attempts = 0; entry.UsedAt = null;
        entry.LastRequestedAt = now; entry.SendCount++; entry.SecurityStampAtIssue = account.SecurityStamp;
        try
        {
            await db.SaveChangesAsync(ct);
            if (transaction is not null) await transaction.CommitAsync(ct);
        }
        catch (DbUpdateConcurrencyException) { db.ChangeTracker.Clear(); return; }
        catch (DbUpdateException e) when (e.InnerException is SqlException { Number: 2601 or 2627 })
        { db.ChangeTracker.Clear(); return; }
        if (transaction is not null) await transaction.DisposeAsync();
        if (!queue.TryEnqueue(new PasswordRecoveryEmail(account.TaiKhoanId, email, otp, entry.ChallengeId, entry.ExpiresAt)))
        {
            // The channel is bounded. Never leave a usable code that could not be queued.
            entry.OtpHash = null; entry.UsedAt = Now; entry.Version = Guid.NewGuid().ToString("N");
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateConcurrencyException) { db.ChangeTracker.Clear(); }
        }
    }

    public async Task<bool> ResetAsync(string email, string otp, string newPassword, string? ipAddress, CancellationToken ct)
    {
        if (!ValidEmail(email) || string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 8 || newPassword.Length > 128
            || otp is null || otp.Length != 6 || otp.Any(x => x < '0' || x > '9')) return false;
        email = Normalize(email);
        for (var retry = 0; retry < 3; retry++)
        {
            await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(ct) : null;
            try
            {
                var account = await db.Taikhoans.FirstOrDefaultAsync(x => x.Email.ToLower() == email && x.TrangThai, ct);
                if (account is null) return false;
                var entry = await db.PasswordResetChallenges.FindAsync([account.TaiKhoanId], ct);
                var now = Now;
                if (entry is null || entry.OtpHash is null || entry.UsedAt.HasValue || entry.ExpiresAt <= now
                    || entry.Attempts >= MaxAttempts || entry.SecurityStampAtIssue != account.SecurityStamp) return false;
                var expected = entry.OtpHash;
                // Reserve a counted attempt before checking the guess. Concurrent losing requests
                // retry the current version; a guess is never checked without consuming an attempt.
                entry.Attempts++; entry.Version = Guid.NewGuid().ToString("N");
                if (entry.Attempts == MaxAttempts) { entry.OtpHash = null; entry.UsedAt = now; }
                await db.SaveChangesAsync(ct);
                var actual = Hash(account.TaiKhoanId, entry.ChallengeId, otp);
                if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected), Encoding.ASCII.GetBytes(actual)))
                {
                    if (transaction is not null) await transaction.CommitAsync(ct);
                    return false;
                }
                account.MatKhauHash = passwords.Hash(newPassword);
                account.SecurityStamp = Guid.NewGuid().ToString("N");
                account.SoLanDangNhapSai = 0; account.KhoaDen = null;
                entry.OtpHash = null; entry.UsedAt = now; entry.Version = Guid.NewGuid().ToString("N");
                var sessions = await db.Refreshtokens.Where(x => x.TaiKhoanId == account.TaiKhoanId && x.RevokedAt == null).ToListAsync(ct);
                foreach (var session in sessions) { session.RevokedAt = now; session.RevokedByIp = ipAddress; }
                db.Auditlogs.Add(new Auditlog { TaiKhoanId = account.TaiKhoanId, ActionName = "PasswordReset", EntityName = "TAIKHOAN",
                    EntityId = account.TaiKhoanId.ToString(), CreatedAt = now, IpAddress = ipAddress,
                    NewValues = "Password changed; existing sessions revoked." });
                await db.SaveChangesAsync(ct);
                if (transaction is not null) await transaction.CommitAsync(ct);
                return true;
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
        return false;
    }
}
