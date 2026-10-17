using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/notifications")]
public sealed class NotificationsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    private int AccountId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private Task<int?> CustomerId(CancellationToken ct) => db.Khachhangs.Where(x => x.TaiKhoanId == AccountId)
        .Select(x => (int?)x.KhachHangId).SingleOrDefaultAsync(ct);
    private IQueryable<ThongBao> Visible(int customerId) => db.ThongBaos.AsNoTracking().Where(x =>
        (x.TaiKhoanId == AccountId && (x.KhachHangId == null || x.KhachHangId == customerId)) ||
        (x.TaiKhoanId == null && x.KhachHangId == null));

    [HttpPost("device-token")]
    public async Task<IActionResult> RegisterDevice(DeviceTokenRequest request, CancellationToken ct)
    {
        var customerId = await CustomerId(ct); if (customerId is null) return Forbid();
        if (!ValidToken(request.Token) || request.DeviceType is not ("android" or "ios" or "web"))
            return BadRequest("Token hoặc loại thiết bị không hợp lệ.");
        for (var attempt = 0; ; attempt++)
        {
            var device = await db.ThietBiKhachHangs.SingleOrDefaultAsync(x => x.FcmToken == request.Token, ct);
            if (device is null) { device = new ThietBiKhachHang { FcmToken = request.Token }; db.ThietBiKhachHangs.Add(device); }
            device.TaiKhoanId = AccountId; device.KhachHangId = customerId;
            device.LoaiThietBi = request.DeviceType; device.NgayCapNhat = DateTime.UtcNow; device.TrangThai = true;
            try { await db.SaveChangesAsync(ct); return Ok(new { message = "Đã đăng ký thiết bị nhận thông báo." }); }
            catch (DbUpdateException ex) when (attempt < 2 && IsDuplicate(ex))
            { db.Entry(device).State = EntityState.Detached; }
        }
    }

    [HttpDelete("device-token")]
    public async Task<IActionResult> DeleteDevice([FromQuery] string token, CancellationToken ct)
    {
        var customerId = await CustomerId(ct); if (customerId is null) return Forbid();
        if (!ValidToken(token)) return BadRequest("Token không hợp lệ.");
        // Include the owner in the UPDATE predicate, so an old session cannot disable a rebound token.
        if (db.Database.IsRelational())
            await db.ThietBiKhachHangs.Where(x => x.FcmToken == token && x.TaiKhoanId == AccountId && x.KhachHangId == customerId)
                .ExecuteUpdateAsync(set => set.SetProperty(x => x.TrangThai, false), ct);
        else
        {
            var device = await db.ThietBiKhachHangs.SingleOrDefaultAsync(x => x.FcmToken == token && x.TaiKhoanId == AccountId && x.KhachHangId == customerId, ct);
            if (device is not null) { device.TrangThai = false; await db.SaveChangesAsync(ct); }
        }
        return NoContent();
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        [FromQuery] bool unreadOnly = false, CancellationToken ct = default)
    {
        var customerId = await CustomerId(ct); if (customerId is null) return Forbid();
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 100);
        // Avoid overflow from hostile pagination inputs.
        page = Math.Min(page, int.MaxValue / pageSize);
        var query = Visible(customerId.Value);
        var receipts = db.ThongBaoDaDocs.Where(x => x.TaiKhoanId == AccountId);
        var unreadCount = await query.CountAsync(x => !receipts.Any(r => r.ThongBaoId == x.ThongBaoId), ct);
        if (unreadOnly) query = query.Where(x => !receipts.Any(r => r.ThongBaoId == x.ThongBaoId));
        var totalCount = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.NgayTao).ThenByDescending(x => x.ThongBaoId)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(x => new NotificationResponse(x.ThongBaoId, x.TieuDe, x.NoiDung, x.LoaiThongBao,
                x.DuLieuKemTheo, receipts.Any(r => r.ThongBaoId == x.ThongBaoId), DateTime.SpecifyKind(x.NgayTao, DateTimeKind.Utc))).ToListAsync(ct);
        return Ok(new { items, totalCount, unreadCount, page, pageSize });
    }

    [HttpGet("unread-count")]
    public async Task<IActionResult> UnreadCount(CancellationToken ct)
    {
        var customerId = await CustomerId(ct); if (customerId is null) return Forbid();
        var unreadCount = await Visible(customerId.Value).CountAsync(x =>
            !db.ThongBaoDaDocs.Any(r => r.TaiKhoanId == AccountId && r.ThongBaoId == x.ThongBaoId), ct);
        return Ok(new { unreadCount });
    }

    [HttpPatch("{id:int}/read")]
    public async Task<IActionResult> MarkRead(int id, CancellationToken ct)
    {
        var customerId = await CustomerId(ct); if (customerId is null) return Forbid();
        if (!await Visible(customerId.Value).AnyAsync(x => x.ThongBaoId == id, ct)) return NotFound();
        await AddReceipts([id], ct); return NoContent();
    }

    [HttpPatch("read-all")]
    public async Task<IActionResult> ReadAll(CancellationToken ct)
    {
        var customerId = await CustomerId(ct); if (customerId is null) return Forbid();
        var ids = await Visible(customerId.Value).Select(x => x.ThongBaoId).ToListAsync(ct);
        await AddReceipts(ids, ct); return NoContent();
    }

    private async Task AddReceipts(List<int> ids, CancellationToken ct)
    {
        // Retry unique conflicts when two tabs mark the same notification read concurrently.
        for (var attempt = 0; ; attempt++)
        {
            var existing = await db.ThongBaoDaDocs.Where(x => x.TaiKhoanId == AccountId && ids.Contains(x.ThongBaoId))
                .Select(x => x.ThongBaoId).ToListAsync(ct);
            var rows = ids.Except(existing).Select(id => new ThongBaoDaDoc
                { ThongBaoId = id, TaiKhoanId = AccountId, NgayDoc = DateTime.UtcNow }).ToList();
            if (rows.Count == 0) return;
            db.ThongBaoDaDocs.AddRange(rows);
            try { await db.SaveChangesAsync(ct); return; }
            catch (DbUpdateException ex) when (attempt < 3 && IsDuplicate(ex))
            { foreach (var row in rows) db.Entry(row).State = EntityState.Detached; }
        }
    }

    private static bool ValidToken(string? token) => !string.IsNullOrWhiteSpace(token)
        && token.Length <= 500 && !token.Any(char.IsWhiteSpace);
    private static bool IsDuplicate(DbUpdateException ex) => ex.InnerException is SqlException { Number: 2601 or 2627 };
}
