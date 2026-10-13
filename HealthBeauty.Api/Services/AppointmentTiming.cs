using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public static class AppointmentTiming
{
    public static int ItemDurationMinutes(Chitietlichhen item) =>
        item.ThoiLuongThucTe is > 0 ? item.ThoiLuongThucTe.Value
        : item.DichVu?.ThoiLuongPhut is > 0 ? item.DichVu.ThoiLuongPhut : 30;

    public static int DurationMinutes(Lichhen appointment) =>
        appointment.Chitietlichhens.Count == 0 ? 30 : appointment.Chitietlichhens.Sum(ItemDurationMinutes);

    public static async Task<int> LoadDurationMinutesAsync(Klcn021HealthBeautyContext db, int appointmentId, CancellationToken ct)
    {
        // Read without tracking so loaded navigation properties do not affect the entity returned to the client.
        var items = await db.Chitietlichhens.AsNoTracking().Include(x => x.DichVu)
            .Where(x => x.LichHenId == appointmentId).ToListAsync(ct);
        return items.Count == 0 ? 30 : items.Sum(ItemDurationMinutes);
    }

    public static async Task<bool> IsWithinShiftAsync(Klcn021HealthBeautyContext db,
        int? staffId, DateTime start, int durationMinutes, CancellationToken ct)
    {
        // An unassigned appointment is scheduled when a member of staff is selected.
        if (!staffId.HasValue) return true;
        var date = DateOnly.FromDateTime(start);
        var end = start.AddMinutes(durationMinutes > 0 ? durationMinutes : 30);
        var shifts = await db.Lichlamviecs.AsNoTracking()
            .Where(x => x.NhanVienId == staffId.Value && x.NgayLam == date && x.TrangThai != "NghiPhep")
            .ToListAsync(ct);
        return shifts.Any(x => start >= date.ToDateTime(x.GioBatDau) && end <= date.ToDateTime(x.GioKetThuc));
    }

    public static async Task<bool> HasConflictAsync(Klcn021HealthBeautyContext db,
        int customerId, int? staffId, DateTime newStart, int durationMinutes,
        int? excludedAppointmentId, CancellationToken ct)
    {
        var newEnd = newStart.AddMinutes(durationMinutes > 0 ? durationMinutes : 30);
        // Do not restrict to one date: a service can continue past midnight.
        var candidates = await db.Lichhens.AsNoTracking()
            .Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu)
            .Where(x => x.TrangThai != "DaHuy" && x.NgayGioHen < newEnd
                && (!excludedAppointmentId.HasValue || x.LichHenId != excludedAppointmentId.Value)
                && (x.KhachHangId == customerId || (staffId.HasValue && x.NhanVienId == staffId.Value)))
            .ToListAsync(ct);
        return candidates.Any(x => newStart < x.NgayGioHen.AddMinutes(DurationMinutes(x)));
    }
}
