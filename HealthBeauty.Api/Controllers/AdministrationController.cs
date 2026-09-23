using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize(Roles = "Admin"), Route("api/v1/admin")]
public sealed class AdministrationController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet("roles")]
    public async Task<IActionResult> Roles(CancellationToken ct) => Ok(await db.Vaitros.AsNoTracking().OrderBy(x => x.TenVaiTro).Select(x => new { x.VaiTroId, x.TenVaiTro, x.MoTa }).ToListAsync(ct));

    [HttpGet("permissions")]
    public async Task<IActionResult> Permissions(CancellationToken ct) => Ok(await db.Quyens.AsNoTracking().OrderBy(x => x.NhomQuyen).ThenBy(x => x.MaQuyen).Select(x => new { x.QuyenId, x.MaQuyen, x.TenQuyen, x.NhomQuyen, x.MoTa, x.TrangThai }).ToListAsync(ct));

    [HttpGet("roles/{roleId:int}/permissions")]
    public async Task<IActionResult> RolePermissions(int roleId, CancellationToken ct)
    {
        if (!await db.Vaitros.AnyAsync(x => x.VaiTroId == roleId, ct)) return NotFound();
        return Ok(await db.Quyens.AsNoTracking().OrderBy(x => x.NhomQuyen).ThenBy(x => x.MaQuyen).Select(q => new { q.QuyenId, q.MaQuyen, q.TenQuyen, q.NhomQuyen, Granted = q.VaitroQuyens.Where(v => v.VaiTroId == roleId).Select(v => (bool?)v.DuocCap).FirstOrDefault() ?? false }).ToListAsync(ct));
    }

    [HttpPut("roles/{roleId:int}/permissions/{permissionId:int}")]
    public async Task<IActionResult> SetRolePermission(int roleId, int permissionId, RolePermissionRequest request, CancellationToken ct)
    {
        var grant = await db.VaitroQuyens.FirstOrDefaultAsync(x => x.VaiTroId == roleId && x.QuyenId == permissionId, ct);
        if (grant is null)
        {
            if (!await db.Vaitros.AnyAsync(x => x.VaiTroId == roleId, ct) || !await db.Quyens.AnyAsync(x => x.QuyenId == permissionId, ct)) return NotFound();
            grant = new VaitroQuyen { VaiTroId = roleId, QuyenId = permissionId, DuocCap = request.Granted, NgayGan = DateTime.Now }; db.VaitroQuyens.Add(grant);
        }
        else { grant.DuocCap = request.Granted; grant.NgayGan = DateTime.Now; }
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        db.Auditlogs.Add(new Auditlog { TaiKhoanId = accountId, ActionName = request.Granted ? "PermissionGranted" : "PermissionRevoked", EntityName = "VAITRO_QUYEN", EntityId = $"{roleId}:{permissionId}", NewValues = request.Granted.ToString(), IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(), UserAgent = Request.Headers.UserAgent.ToString(), CreatedAt = DateTime.Now });
        await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpGet("accounts")]
    public async Task<IActionResult> Accounts([FromQuery] string? keyword, CancellationToken ct)
    {
        var query = db.Taikhoans.AsNoTracking().Include(x => x.VaiTro).AsQueryable();
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.Email.Contains(keyword) || (x.TenTaiKhoan != null && x.TenTaiKhoan.Contains(keyword)));
        return Ok(await query.OrderBy(x => x.Email).Take(200).Select(x => new { x.TaiKhoanId, x.Email, x.TenTaiKhoan, Role = x.VaiTro.TenVaiTro, x.TrangThai, x.KhoaDen, x.NgayTao, x.LanDangNhapCuoi }).ToListAsync(ct));
    }

    [HttpPatch("accounts/{accountId:int}/status")]
    public async Task<IActionResult> SetAccountStatus(int accountId, [FromQuery] bool active, CancellationToken ct)
    {
        var account = await db.Taikhoans.FindAsync([accountId], ct); if (account is null) return NotFound();
        if (accountId == int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!) && !active) return BadRequest("Không thể tự khóa tài khoản quản trị đang đăng nhập.");
        account.TrangThai = active;
        if (!active) { account.KhoaDen = null; var tokens = await db.Refreshtokens.Where(x => x.TaiKhoanId == accountId && x.RevokedAt == null).ToListAsync(ct); foreach (var token in tokens) { token.RevokedAt = DateTime.Now; token.RevokedByIp = HttpContext.Connection.RemoteIpAddress?.ToString(); } }
        var actor = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        db.Auditlogs.Add(new Auditlog { TaiKhoanId = actor, ActionName = active ? "AccountActivated" : "AccountDeactivated", EntityName = "TAIKHOAN", EntityId = accountId.ToString(), NewValues = active.ToString(), IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(), UserAgent = Request.Headers.UserAgent.ToString(), CreatedAt = DateTime.Now });
        await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpGet("audit-logs")]
    public async Task<IActionResult> AuditLogs([FromQuery] int take = 100, CancellationToken ct = default)
    {
        take = Math.Clamp(take, 1, 500);
        return Ok(await db.Auditlogs.AsNoTracking().OrderByDescending(x => x.CreatedAt).Take(take).Select(x => new { x.AuditLogId, x.TaiKhoanId, x.ActionName, x.EntityName, x.EntityId, x.CreatedAt, x.IpAddress }).ToListAsync(ct));
    }

    [HttpGet("login-logs")]
    public async Task<IActionResult> LoginLogs([FromQuery] int take = 100, CancellationToken ct = default)
    {
        take = Math.Clamp(take, 1, 500);
        return Ok(await db.Dangnhaplogs.AsNoTracking().OrderByDescending(x => x.CreatedAt).Take(take).Select(x => new { x.DangNhapLogId, x.TaiKhoanId, x.Email, x.ThanhCong, x.LyDoThatBai, x.CreatedAt, x.IpAddress }).ToListAsync(ct));
    }
}
