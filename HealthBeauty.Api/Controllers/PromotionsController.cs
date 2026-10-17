using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
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

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost]
    public async Task<IActionResult> Create(PromotionRequest request, CancellationToken ct)
    {
        if (request.StartsAt.HasValue && request.EndsAt.HasValue && request.EndsAt < request.StartsAt) return BadRequest("Ngày kết thúc phải sau ngày bắt đầu.");
        if (!VoucherRules.ValidDiscount(request.DiscountType, request.Discount)) return BadRequest("Loại giảm phải là PhanTram hoặc SoTien; mức giảm không hợp lệ.");
        var item = new Khuyenmai { TenKhuyenMai = request.Name.Trim(), LoaiGiam = VoucherRules.NormalizeDiscount(request.DiscountType), MucGiam = request.Discount, DieuKienApDung = request.Condition?.Trim(), NgayBatDauHieuLuc = request.StartsAt, NgayKetThucHieuLuc = request.EndsAt };
        db.Khuyenmais.Add(item); await db.SaveChangesAsync(ct); return Created($"api/v1/promotions/{item.KhuyenMaiId}", item);
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, PromotionRequest request, CancellationToken ct)
    {
        var item = await db.Khuyenmais.FindAsync([id], ct); if (item is null) return NotFound();
        if (request.StartsAt.HasValue && request.EndsAt.HasValue && request.EndsAt < request.StartsAt) return BadRequest("Ngày kết thúc phải sau ngày bắt đầu.");
        if (!VoucherRules.ValidDiscount(request.DiscountType, request.Discount)) return BadRequest("Loại giảm phải là PhanTram hoặc SoTien; mức giảm không hợp lệ.");
        item.TenKhuyenMai = request.Name.Trim(); item.LoaiGiam = VoucherRules.NormalizeDiscount(request.DiscountType); item.MucGiam = request.Discount; item.DieuKienApDung = request.Condition?.Trim(); item.NgayBatDauHieuLuc = request.StartsAt; item.NgayKetThucHieuLuc = request.EndsAt;
        await db.SaveChangesAsync(ct); return Ok(item);
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct) { var item=await db.Khuyenmais.FindAsync([id],ct); if(item is null)return NotFound(); if(await db.Vouchers.AnyAsync(x=>x.KhuyenMaiId==id,ct))return Conflict("Khuyến mãi còn voucher tham chiếu."); db.Khuyenmais.Remove(item); await db.SaveChangesAsync(ct); return NoContent(); }

    [Authorize, HttpPost("vouchers/validate")]
    public async Task<IActionResult> ValidateVoucher([FromQuery] string code, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        var voucher = await VoucherRules.FindApplicableAsync(db, code, customerId, ct);
        return voucher is null ? NotFound(new { Valid = false }) : Ok(new { Valid = true, voucher.MaCode, voucher.GiaTriGiam, voucher.HanSuDung, voucher.KhuyenMai.TenKhuyenMai });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost("vouchers")]
    public async Task<IActionResult> CreateVoucher(VoucherRequest request, CancellationToken ct)
    {
        var validation = await ValidateVoucherRequest(request, null, ct);
        if (validation is not null) return validation;
        var code = VoucherRules.NormalizeCode(request.Code);
        var voucher = new Voucher { MaCode = code, KhuyenMaiId = request.PromotionId, KhachHangId = request.CustomerId, GiaTriGiam = request.DiscountValue, HanSuDung = request.ExpiresAt, TrangThai = true };
        db.Vouchers.Add(voucher); await db.SaveChangesAsync(ct); return Created("api/v1/promotions/vouchers/" + voucher.VoucherId, new { voucher.VoucherId,voucher.MaCode,voucher.KhuyenMaiId,voucher.KhachHangId,voucher.GiaTriGiam,voucher.HanSuDung,voucher.TrangThai });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("~/api/v1/vouchers")]
    public async Task<IActionResult> ListVouchers([FromQuery] string? keyword, [FromQuery] bool? active, CancellationToken ct)
    {
        var query = db.Vouchers.AsNoTracking().Include(x => x.KhuyenMai).Include(x => x.KhachHang).AsQueryable();
        if (active.HasValue) query = query.Where(x => x.TrangThai == active.Value);
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.MaCode.Contains(keyword) || x.KhuyenMai.TenKhuyenMai.Contains(keyword) || (x.KhachHang != null && x.KhachHang.HoTen.Contains(keyword)));
        return Ok(await query.OrderByDescending(x => x.HanSuDung).Take(500)
            .Select(x => new VoucherResponse(x.VoucherId, x.MaCode, x.KhuyenMaiId, x.KhuyenMai.TenKhuyenMai, x.KhachHangId, x.KhachHang != null ? x.KhachHang.HoTen : null, x.GiaTriGiam, x.HanSuDung, x.TrangThai))
            .ToListAsync(ct));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("vouchers/{id:int}")]
    public async Task<IActionResult> UpdateVoucher(int id, VoucherRequest request, CancellationToken ct)
    {
        var item=await db.Vouchers.FindAsync([id],ct); if(item is null)return NotFound();
        var validation=await ValidateVoucherRequest(request,id,ct); if(validation is not null)return validation;
        item.MaCode=VoucherRules.NormalizeCode(request.Code);item.KhuyenMaiId=request.PromotionId;item.KhachHangId=request.CustomerId;
        item.GiaTriGiam=request.DiscountValue;item.HanSuDung=request.ExpiresAt;await db.SaveChangesAsync(ct);
        return Ok(new { item.VoucherId,item.MaCode,item.KhuyenMaiId,item.KhachHangId,item.GiaTriGiam,item.HanSuDung,item.TrangThai });
    }
    private async Task<IActionResult?> ValidateVoucherRequest(VoucherRequest request,int? excludedId,CancellationToken ct)
    {
        var code=VoucherRules.NormalizeCode(request.Code);
        if(code.Length==0 || code.Length>30 || request.DiscountValue<0 || request.ExpiresAt<=DateTime.Now) return BadRequest("Voucher code, discount and expiry are invalid.");
        if(!await db.Khuyenmais.AnyAsync(x=>x.KhuyenMaiId==request.PromotionId,ct)) return BadRequest("Promotion does not exist.");
        if(request.CustomerId.HasValue && !await db.Khachhangs.AnyAsync(x=>x.KhachHangId==request.CustomerId.Value,ct)) return BadRequest("Customer does not exist.");
        if(await db.Vouchers.AnyAsync(x=>x.MaCode==code && (!excludedId.HasValue || x.VoucherId!=excludedId.Value),ct)) return Conflict("Voucher code already exists.");
        return null;
    }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpPatch("vouchers/{id:int}/status")]
    public async Task<IActionResult> VoucherStatus(int id, [FromQuery] bool active, CancellationToken ct) { var item=await db.Vouchers.FindAsync([id],ct); if(item is null)return NotFound(); item.TrangThai=active; await db.SaveChangesAsync(ct); return NoContent(); }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpDelete("vouchers/{id:int}")]
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

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("pending")]
    public async Task<IActionResult> Pending(CancellationToken ct) => Ok(await db.Danhgia.AsNoTracking()
        .Where(x => x.TrangThai == "ChoDuyet").OrderBy(x => x.NgayDanhGia)
        .Select(x => new { x.DanhGiaId,x.HoaDonId,x.SoSao,x.BinhLuan,x.NgayDanhGia,x.TrangThai }).Take(200).ToListAsync(ct));

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPatch("{id:int}/moderation")]
    public async Task<IActionResult> Moderate(int id, [FromQuery] bool visible, CancellationToken ct)
    {
        var review = await db.Danhgia.FindAsync([id], ct); if (review is null) return NotFound(); review.TrangThai = visible ? "HienThi" : "An"; await db.SaveChangesAsync(ct); return NoContent();
    }
}
