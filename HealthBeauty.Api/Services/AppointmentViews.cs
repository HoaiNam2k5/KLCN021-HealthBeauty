using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

// Explicit projections preserve the existing detail field names without EF back references.
public static class AppointmentViews
{
    public static object Detail(Lichhen x) => new
    {
        x.LichHenId, x.KhachHangId, x.NhanVienId, x.NgayGioHen, x.GioKetThucDuKien, x.TrangThai, x.GhiChu,
        KhachHang = x.KhachHang is null ? null : new { x.KhachHang.KhachHangId, x.KhachHang.HoTen, x.KhachHang.SoDienThoai },
        NhanVien = x.NhanVien is null ? null : new { x.NhanVien.NhanVienId, x.NhanVien.HoTen, x.NhanVien.ChuyenMon },
        Chitietlichhens = x.Chitietlichhens.Select(i => new
        {
            i.ChiTietLichHenId, i.LichHenId, i.DichVuId, i.ComboId, i.GiaDuKien, i.ThoiLuongThucTe,
            DurationMinutes = AppointmentTiming.ItemDurationMinutes(i),
            DichVu = i.DichVu is null ? null : new { i.DichVu.DichVuId, i.DichVu.TenDichVu, i.DichVu.Gia, i.DichVu.ThoiLuongPhut }
        }).ToList()
    };

    public static async Task<object> LoadDetailAsync(Klcn021HealthBeautyContext db, int id, CancellationToken ct)
    {
        var x = await db.Lichhens.AsNoTracking().Include(x => x.KhachHang).Include(x => x.NhanVien)
            .Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu).SingleAsync(x => x.LichHenId == id, ct);
        return Detail(x);
    }
}
