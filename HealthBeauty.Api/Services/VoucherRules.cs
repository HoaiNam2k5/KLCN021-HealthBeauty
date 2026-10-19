using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace HealthBeauty.Api.Services;
public static class VoucherRules
{
    public static string NormalizeCode(string? code) => (code ?? "").Trim().ToUpperInvariant();
    public static bool ValidDiscount(string? type, decimal amount) => amount >= 0 && amount <= 1000000000m
        && (string.Equals(type?.Trim(), "SoTien", StringComparison.OrdinalIgnoreCase)
            || (string.Equals(type?.Trim(), "PhanTram", StringComparison.OrdinalIgnoreCase) && amount <= 100));
    public static string NormalizeDiscount(string type) => type.Trim().Equals("PhanTram",StringComparison.OrdinalIgnoreCase) ? "PhanTram" : "SoTien";
    public static async Task<Voucher?> FindApplicableAsync(Klcn021HealthBeautyContext db, string? code, int? customerId, CancellationToken ct)
    {
        var normalized=NormalizeCode(code); if(normalized.Length==0) return null;
        var now=DateTime.Now;
        var voucher=await db.Vouchers.Include(x=>x.KhuyenMai).FirstOrDefaultAsync(x=>x.MaCode==normalized && x.TrangThai && !x.UsedAt.HasValue && x.HanSuDung>=now
            && (!x.KhachHangId.HasValue || x.KhachHangId==customerId)
            && (x.PointsCost == 0 || (x.RedeemedAt.HasValue && x.KhachHangId.HasValue && x.KhachHangId == customerId))
            && (!x.KhuyenMai.NgayBatDauHieuLuc.HasValue || x.KhuyenMai.NgayBatDauHieuLuc<=now)
            && (!x.KhuyenMai.NgayKetThucHieuLuc.HasValue || x.KhuyenMai.NgayKetThucHieuLuc>=now),ct);
        return voucher is not null && voucher.GiaTriGiam>=0 && ValidDiscount(voucher.KhuyenMai.LoaiGiam,voucher.KhuyenMai.MucGiam) ? voucher : null;
    }
}
