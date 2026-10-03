using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/promotions")]
public sealed class PromotionsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [AllowAnonymous, HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await db.Khuyenmais.AsNoTracking().Where(x => (!x.NgayBatDauHieuLuc.HasValue || x.NgayBatDauHieuLuc <= DateTime.Now) && (!x.NgayKetThucHieuLuc.HasValue || x.NgayKetThucHieuLuc >= DateTime.Now))
        .OrderBy(x => x.NgayKetThucHieuLuc).Select(x => new { x.KhuyenMaiId, x.TenKhuyenMai, x.LoaiGiam, x.MucGiam, x.DieuKienApDung, x.NgayBatDauHieuLuc, x.NgayKetThucHieuLuc }).ToListAsync(ct));

    [Authorize(Roles = "Admin,Manager"), HttpPost]
    public async Task<IActionResult> Create(PromotionRequest request, CancellationToken ct)
    {
        if (request.StartsAt.HasValue && request.EndsAt.HasValue && request.EndsAt < request.StartsAt) return BadRequest("Ngày kết thúc phải sau ngày bắt đầu.");
        if (request.DiscountType.Equals("PhanTram", StringComparison.OrdinalIgnoreCase) && request.Discount > 100) return BadRequest("Mức giảm phần trăm không được vượt quá 100.");
        var item = new Khuyenmai { TenKhuyenMai = request.Name.Trim(), LoaiGiam = request.DiscountType.Trim(), MucGiam = request.Discount, DieuKienApDung = request.Condition?.Trim(), NgayBatDauHieuLuc = request.StartsAt, NgayKetThucHieuLuc = request.EndsAt };
        db.Khuyenmais.Add(item); await db.SaveChangesAsync(ct); return Created($"api/v1/promotions/{item.KhuyenMaiId}", item);
    }

    [Authorize(Roles = "Admin,Manager"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, PromotionRequest request, CancellationToken ct)
    {
        var item = await db.Khuyenmais.FindAsync([id], ct); if (item is null) return NotFound();
        if (request.StartsAt.HasValue && request.EndsAt.HasValue && request.EndsAt < request.StartsAt) return BadRequest("Ngày kết thúc phải sau ngày bắt đầu.");
        if (request.DiscountType.Equals("PhanTram", StringComparison.OrdinalIgnoreCase) && request.Discount > 100) return BadRequest("Mức giảm phần trăm không được vượt quá 100.");
        item.TenKhuyenMai = request.Name.Trim(); item.LoaiGiam = request.DiscountType.Trim(); item.MucGiam = request.Discount; item.DieuKienApDung = request.Condition?.Trim(); item.NgayBatDauHieuLuc = request.StartsAt; item.NgayKetThucHieuLuc = request.EndsAt;
        await db.SaveChangesAsync(ct); return Ok(item);
    }

    [Authorize(Roles = "Admin,Manager"), HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct) { var item=await db.Khuyenmais.FindAsync([id],ct); if(item is null)return NotFound(); if(await db.Vouchers.AnyAsync(x=>x.KhuyenMaiId==id&&x.TrangThai,ct))return Conflict("Khuyến mãi còn voucher đang hoạt động."); db.Khuyenmais.Remove(item); await db.SaveChangesAsync(ct); return NoContent(); }

    [Authorize, HttpPost("vouchers/validate")]
    public async Task<IActionResult> ValidateVoucher([FromQuery] string code, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        var now = DateTime.Now;
        var voucher = await db.Vouchers.AsNoTracking().Include(x => x.KhuyenMai).FirstOrDefaultAsync(x => x.MaCode == code.Trim() && x.TrangThai && x.HanSuDung >= now && (!x.KhachHangId.HasValue || x.KhachHangId == customerId)
            && (!x.KhuyenMai.NgayBatDauHieuLuc.HasValue || x.KhuyenMai.NgayBatDauHieuLuc <= now) && (!x.KhuyenMai.NgayKetThucHieuLuc.HasValue || x.KhuyenMai.NgayKetThucHieuLuc >= now), ct);
        return voucher is null ? NotFound(new { Valid = false }) : Ok(new { Valid = true, voucher.MaCode, voucher.GiaTriGiam, voucher.HanSuDung, voucher.KhuyenMai.TenKhuyenMai });
    }

    [Authorize(Roles = "Admin,Manager"), HttpPost("vouchers")]
    public async Task<IActionResult> CreateVoucher(VoucherRequest request, CancellationToken ct)
    {
        if (request.ExpiresAt <= DateTime.Now) return BadRequest("Hạn sử dụng phải ở tương lai.");
        if (!await db.Khuyenmais.AnyAsync(x => x.KhuyenMaiId == request.PromotionId, ct)) return BadRequest("Chương trình khuyến mãi không tồn tại.");
        if (request.CustomerId.HasValue && !await db.Khachhangs.AnyAsync(x => x.KhachHangId == request.CustomerId.Value, ct)) return BadRequest("Khách hàng không tồn tại.");
        var code = request.Code.Trim().ToUpperInvariant(); if (await db.Vouchers.AnyAsync(x => x.MaCode == code, ct)) return Conflict("Mã voucher đã tồn tại.");
        var voucher = new Voucher { MaCode = code, KhuyenMaiId = request.PromotionId, KhachHangId = request.CustomerId, GiaTriGiam = request.DiscountValue, HanSuDung = request.ExpiresAt, TrangThai = true };
        db.Vouchers.Add(voucher); await db.SaveChangesAsync(ct); return Created("api/v1/promotions/vouchers/" + voucher.VoucherId, voucher);
    }

    [Authorize(Roles = "Admin,Manager"), HttpPut("vouchers/{id:int}")]
    public async Task<IActionResult> UpdateVoucher(int id, VoucherRequest request, CancellationToken ct) { var item=await db.Vouchers.FindAsync([id],ct); if(item is null)return NotFound(); item.MaCode=request.Code.Trim().ToUpperInvariant(); item.KhuyenMaiId=request.PromotionId; item.KhachHangId=request.CustomerId; item.GiaTriGiam=request.DiscountValue; item.HanSuDung=request.ExpiresAt; await db.SaveChangesAsync(ct); return Ok(item); }
    [Authorize(Roles = "Admin,Manager"), HttpPatch("vouchers/{id:int}/status")]
    public async Task<IActionResult> VoucherStatus(int id, [FromQuery] bool active, CancellationToken ct) { var item=await db.Vouchers.FindAsync([id],ct); if(item is null)return NotFound(); item.TrangThai=active; await db.SaveChangesAsync(ct); return NoContent(); }
    [Authorize(Roles = "Admin,Manager"), HttpDelete("vouchers/{id:int}")]
    public async Task<IActionResult> DeleteVoucher(int id, CancellationToken ct) { var item=await db.Vouchers.FindAsync([id],ct); if(item is null)return NotFound(); item.TrangThai=false; await db.SaveChangesAsync(ct); return NoContent(); }
}

[ApiController, Route("api/v1/reviews")]
public sealed class ReviewsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [AllowAnonymous, HttpGet]
    public async Task<IActionResult> List([FromQuery] int? serviceId, CancellationToken ct)
    {
        var query = db.Danhgia.AsNoTracking().Where(x => x.TrangThai == "HienThi").AsQueryable();
        if (serviceId.HasValue) query = query.Where(x => x.HoaDon.Chitiethoadons.Any(i => i.DichVuId == serviceId.Value || i.Combo!.Chitietcombos.Any(c => c.DichVuId == serviceId.Value)));
        return Ok(await query.OrderByDescending(x => x.NgayDanhGia).Select(x => new { x.DanhGiaId, x.HoaDonId, x.SoSao, x.BinhLuan, x.NgayDanhGia }).Take(200).ToListAsync(ct));
    }

    [Authorize, HttpPost("invoices/{invoiceId:int}")]
    public async Task<IActionResult> Create(int invoiceId, ReviewRequest request, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct); if (customer is null) return Forbid();
        var invoice = await db.Hoadons.FirstOrDefaultAsync(x => x.HoaDonId == invoiceId && x.KhachHangId == customer.KhachHangId, ct);
        if (invoice is null) return NotFound();
        if (invoice.TrangThai != "DaThanhToan") return BadRequest("Chỉ đánh giá hóa đơn đã thanh toán.");
        if (await db.Danhgia.AnyAsync(x => x.HoaDonId == invoiceId, ct)) return Conflict("Hóa đơn đã có đánh giá.");
        var review = new Danhgium { HoaDonId = invoiceId, SoSao = request.Stars, BinhLuan = request.Comment?.Trim(), NgayDanhGia = DateTime.Now, TrangThai = "ChoDuyet" };
        db.Danhgia.Add(review); await db.SaveChangesAsync(ct); return Created($"api/v1/reviews/{review.DanhGiaId}", new { review.DanhGiaId, review.HoaDonId, review.SoSao, review.BinhLuan, review.TrangThai });
    }

    [Authorize(Roles = "Admin,Manager"), HttpPatch("{id:int}/moderation")]
    public async Task<IActionResult> Moderate(int id, [FromQuery] bool visible, CancellationToken ct)
    {
        var review = await db.Danhgia.FindAsync([id], ct); if (review is null) return NotFound(); review.TrangThai = visible ? "HienThi" : "An"; await db.SaveChangesAsync(ct); return NoContent();
    }
}
