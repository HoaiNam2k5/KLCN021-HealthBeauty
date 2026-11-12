using System.Linq.Expressions;
using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

/// <summary>Employee profiles also exist for reception and management accounts.</summary>
public static class TechnicianEligibility
{
    public static readonly Expression<Func<Nhanvien, bool>> Predicate = staff =>
        staff.TaiKhoanId.HasValue
            ? staff.TaiKhoan != null && staff.TaiKhoan.TrangThai
                && staff.TaiKhoan.VaiTro.TenVaiTro == "Staff"
            : staff.ChucVu != null && (staff.ChucVu.Trim().ToUpper() == "STAFF"
                || staff.ChucVu.Trim().ToUpper() == "KTV"
                || staff.ChucVu.Trim().ToUpper() == "TECHNICIAN"
                || staff.ChucVu.Trim().ToUpper() == "THERAPIST"
                || staff.ChucVu.Trim().ToUpper() == "K\u1ef8 THU\u1eacT VI\u00caN"
                || staff.ChucVu.Trim().ToUpper() == "KY THUAT VIEN");

    public static IQueryable<Nhanvien> Query(Klcn021HealthBeautyContext db) =>
        db.Nhanviens.AsNoTracking().Where(Predicate);

    public static Task<bool> ExistsAsync(Klcn021HealthBeautyContext db, int id, CancellationToken ct) =>
        Query(db).AnyAsync(staff => staff.NhanVienId == id, ct);
}