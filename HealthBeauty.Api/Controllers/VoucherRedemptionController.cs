using System.Security.Claims;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/customers/me")]
public sealed class VoucherRedemptionController(Klcn021HealthBeautyContext db) : ControllerBase
{
    private Task<Khachhang?> Customer(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        return db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
    }

    private IQueryable<Voucher> Offers(DateTime now) => db.Vouchers.Include(x => x.KhuyenMai)
        .Where(x => x.TrangThai && !x.UsedAt.HasValue && x.PointsCost > 0 && !x.KhachHangId.HasValue && !x.RedeemedAt.HasValue && x.HanSuDung >= now
            && (!x.KhuyenMai.NgayBatDauHieuLuc.HasValue || x.KhuyenMai.NgayBatDauHieuLuc <= now)
            && (!x.KhuyenMai.NgayKetThucHieuLuc.HasValue || x.KhuyenMai.NgayKetThucHieuLuc >= now));

    private static bool ValidDiscount(Voucher voucher) => voucher.GiaTriGiam >= 0
        && VoucherRules.ValidDiscount(voucher.KhuyenMai.LoaiGiam, voucher.KhuyenMai.MucGiam);

    [HttpGet("voucher-offers")]
    public async Task<IActionResult> ListOffers(CancellationToken ct)
    {
        if (await Customer(ct) is null) return Forbid();
        var offers = await Offers(DateTime.Now).AsNoTracking().OrderBy(x => x.PointsCost).ThenBy(x => x.VoucherId).Take(500).ToListAsync(ct);
        return Ok(offers.Where(ValidDiscount).Select(x => new { Id = x.VoucherId, PromotionId = x.KhuyenMaiId,
            PromotionName = x.KhuyenMai.TenKhuyenMai, DiscountValue = x.GiaTriGiam, ExpiresAt = x.HanSuDung, x.PointsCost }));
    }

    [HttpPost("vouchers/{id:int}/redeem")]
    public async Task<IActionResult> Redeem(int id, CancellationToken ct)
    {
        var customer = await Customer(ct);
        if (customer is null) return Forbid();
        var voucher = await db.Vouchers.Include(x => x.KhuyenMai).FirstOrDefaultAsync(x => x.VoucherId == id, ct);
        if (voucher is null) return NotFound();
        if (voucher.KhachHangId.HasValue || voucher.RedeemedAt.HasValue)
            return Conflict("Voucher was already claimed. No additional points were charged.");
        if (!await Offers(DateTime.Now).AnyAsync(x => x.VoucherId == id, ct) || !ValidDiscount(voucher)) return NotFound();
        if (customer.DiemThuong < voucher.PointsCost) return BadRequest("Insufficient reward points.");
        customer.DiemThuong -= voucher.PointsCost;
        voucher.KhachHangId = customer.KhachHangId;
        voucher.RedeemedAt = DateTime.Now;
        db.Giaodichdiems.Add(new Giaodichdiem { KhachHangId = customer.KhachHangId, VoucherId = voucher.VoucherId,
            SoDiem = -voucher.PointsCost, LoaiGiaoDich = "DoiVoucher", NgayGiaoDich = DateTime.Now,
            GhiChu = "Reward points exchanged for voucher " + voucher.MaCode });
        if (!await NotificationPersistence.TrySaveAsync(db, ct))
            return Conflict("Reward balance or voucher changed. Please reload before trying again.");
        return Ok(new { VoucherId = voucher.VoucherId, Code = voucher.MaCode, PointsSpent = voucher.PointsCost,
            RemainingPoints = customer.DiemThuong });
    }
}
