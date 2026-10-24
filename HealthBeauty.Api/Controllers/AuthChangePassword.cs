using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

public sealed partial class AuthController
{
    [Authorize(Roles = "Customer"), HttpPut("change-password")]
    [EnableRateLimiting(MobileAuthenticationRateLimiting.ChangePasswordPolicy)]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var accountId)) return Unauthorized();
        if (string.IsNullOrWhiteSpace(request.CurrentPassword) || request.CurrentPassword.Length > 4096
            || string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length is < 8 or > 128)
            return BadRequest("Current password and a new password of 8 to 128 characters are required.");
        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(ct) : null;
        var now = DateTime.UtcNow;
        var account = await db.Taikhoans.Include(x => x.VaiTro).FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (account is null || !account.TrangThai || account.KhoaDen > now || account.VaiTro?.TenVaiTro != "Customer") return Unauthorized();
        if (!passwords.Verify(request.CurrentPassword, account.MatKhauHash)) return BadRequest("Current password is incorrect.");
        if (request.CurrentPassword == request.NewPassword) return BadRequest("New password must differ from the current password.");
        account.MatKhauHash = passwords.Hash(request.NewPassword);
        account.SecurityStamp = Guid.NewGuid().ToString("N");
        account.SoLanDangNhapSai = 0;
        var sessions = await db.Refreshtokens.Where(x => x.TaiKhoanId == accountId && x.RevokedAt == null).ToListAsync(ct);
        foreach (var session in sessions) { session.RevokedAt = now; session.RevokedByIp = HttpContext.Connection.RemoteIpAddress?.ToString(); }
        db.Auditlogs.Add(new Auditlog { TaiKhoanId = accountId, ActionName = "PasswordChanged", EntityName = "TAIKHOAN",
            EntityId = accountId.ToString(), CreatedAt = now, IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
            NewValues = "Password changed; existing sessions revoked." });
        try
        {
            // Password hash + security stamp are concurrency tokens. A competing password change wins once.
            await db.SaveChangesAsync(ct);
            if (transaction is not null) await transaction.CommitAsync(ct);
            return NoContent();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (transaction is not null) await transaction.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            return Conflict("Account changed. Please sign in again before retrying.");
        }
    }
}
