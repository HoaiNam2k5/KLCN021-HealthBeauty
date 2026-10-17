using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/reviews")]
public sealed class ReviewsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [AllowAnonymous, HttpGet]
    public async Task<IActionResult> List([FromQuery] int? serviceId, CancellationToken ct)
    {
        if (serviceId is <= 0) return BadRequest("ServiceId must be positive.");
        var query = db.Danhgia.AsNoTracking().Where(x => x.TrangThai == "HienThi");
        if (serviceId.HasValue)
            query = query.Where(x => x.HoaDon.Chitiethoadons.Any(i =>
                i.DichVuId == serviceId.Value ||
                (i.Combo != null && i.Combo.Chitietcombos.Any(c => c.DichVuId == serviceId.Value))));

        // Statistics cover every matching visible review, independently of the item limit.
        var summary = await query.GroupBy(x => 1)
            .Select(g => new { Total = g.Count(), Average = g.Average(x => (double)x.SoSao) })
            .SingleOrDefaultAsync(ct);
        var items = await query.OrderByDescending(x => x.NgayDanhGia).ThenByDescending(x => x.DanhGiaId)
            .Select(x => new
            {
                x.DanhGiaId, x.HoaDonId, x.SoSao, x.BinhLuan, x.NgayDanhGia,
                TenKhachHang = x.HoaDon.KhachHang.HoTen ?? "Khách hàng"
            }).Take(200).ToListAsync(ct);
        return Ok(new
        {
            averageRating = summary is null ? 0d : Math.Round(summary.Average, 1, MidpointRounding.AwayFromZero),
            totalReviews = summary?.Total ?? 0,
            items
        });
    }

    [Authorize, HttpPost("invoices/{invoiceId:int}")]
    public async Task<IActionResult> Create(int invoiceId, ReviewRequest request, CancellationToken ct)
    {
        var customerId = await CurrentCustomerId(ct);
        if (customerId is null) return Forbid();
        var invoice = await db.Hoadons.AsNoTracking()
            .FirstOrDefaultAsync(x => x.HoaDonId == invoiceId && x.KhachHangId == customerId, ct);
        if (invoice is null) return NotFound();
        return await CreateReview(invoice, request, ct);
    }

    [Authorize, HttpPost("appointments/{appointmentId:int}")]
    public async Task<IActionResult> CreateForAppointment(int appointmentId, ReviewRequest request, CancellationToken ct)
    {
        var customerId = await CurrentCustomerId(ct);
        if (customerId is null) return Forbid();
        var appointment = await db.Lichhens.AsNoTracking()
            .FirstOrDefaultAsync(x => x.LichHenId == appointmentId && x.KhachHangId == customerId, ct);
        if (appointment is null) return NotFound();
        if (appointment.TrangThai != "HoanThanh") return BadRequest("Chỉ đánh giá lịch hẹn đã hoàn thành.");
        var invoice = await db.Hoadons.AsNoTracking()
            .Where(x => x.LichHenId == appointmentId && x.KhachHangId == customerId)
            .OrderByDescending(x => x.NgayLap).ThenByDescending(x => x.HoaDonId).FirstOrDefaultAsync(ct);
        if (invoice is null) return BadRequest("Lịch hẹn chưa có hóa đơn.");
        return await CreateReview(invoice, request, ct);
    }

    private Task<int?> CurrentCustomerId(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        return db.Khachhangs.Where(x => x.TaiKhoanId == accountId)
            .Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
    }

    private async Task<IActionResult> CreateReview(Hoadon invoice, ReviewRequest request, CancellationToken ct)
    {
        if (request.Stars is < 1 or > 5 || request.Comment?.Length > 1000)
            return BadRequest("Số sao phải từ 1 đến 5; bình luận tối đa 1000 ký tự.");
        if (invoice.TrangThai != "DaThanhToan") return BadRequest("Chỉ đánh giá hóa đơn đã thanh toán.");
        if (await db.Danhgia.AnyAsync(x => x.HoaDonId == invoice.HoaDonId, ct))
            return Conflict("Hóa đơn đã có đánh giá.");
        var review = new Danhgium
        {
            HoaDonId = invoice.HoaDonId, SoSao = request.Stars, BinhLuan = request.Comment?.Trim(),
            NgayDanhGia = DateTime.Now, TrangThai = "HienThi"
        };
        db.Danhgia.Add(review);
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
        {
            db.Entry(review).State = EntityState.Detached;
            return Conflict("Hóa đơn đã có đánh giá.");
        }
        return Created($"/api/v1/reviews/{review.DanhGiaId}", new
        {
            review.DanhGiaId, review.HoaDonId, review.SoSao, review.BinhLuan,
            review.TrangThai, review.NgayDanhGia
        });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("pending")]
    public async Task<IActionResult> Pending(CancellationToken ct) => Ok(await db.Danhgia.AsNoTracking()
        .Where(x => x.TrangThai == "ChoDuyet").OrderBy(x => x.NgayDanhGia)
        .Select(x => new { x.DanhGiaId, x.HoaDonId, x.SoSao, x.BinhLuan, x.NgayDanhGia, x.TrangThai })
        .Take(200).ToListAsync(ct));

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPatch("{id:int}/moderation")]
    public async Task<IActionResult> Moderate(int id, [FromQuery] bool visible, CancellationToken ct)
    {
        var review = await db.Danhgia.FindAsync([id], ct);
        if (review is null) return NotFound();
        review.TrangThai = visible ? "HienThi" : "An";
        await db.SaveChangesAsync(ct);
        return NoContent();
    }
}
