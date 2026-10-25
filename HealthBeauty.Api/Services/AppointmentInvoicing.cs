using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public static class AppointmentInvoicing
{
    // Caller commits appointment, invoice and notice in one SaveChanges.
    public static async Task<string?> StageAsync(Klcn021HealthBeautyContext db,
        INotificationService notifications, Lichhen appointment, CancellationToken ct)
    {
        if (appointment.CustomerPackageId.HasValue ||
            await db.Hoadons.AnyAsync(x => x.LichHenId == appointment.LichHenId, ct)) return null;
        var details = await db.Chitietlichhens.Where(x => x.LichHenId == appointment.LichHenId).ToListAsync(ct);
        if (details.Any(x => x.GiaDuKien < 0)) return "Giá dịch vụ đã đặt không hợp lệ. Vui lòng kiểm tra trước khi hoàn thành.";
        var comboIds = details.Where(x => x.ComboId.HasValue).Select(x => x.ComboId!.Value).Distinct().ToList();
        var combos = await db.Combodichvus.Include(x => x.Chitietcombos).Where(x => comboIds.Contains(x.ComboId)).ToDictionaryAsync(x => x.ComboId, ct);
        var invoice = new Hoadon
        {
            LichHenId = appointment.LichHenId, KhachHangId = appointment.KhachHangId,
            NgayLap = DateTime.Now, TrangThai = "ChuaThanhToan"
        };
        foreach (var group in details.Where(x => !x.ComboId.HasValue).GroupBy(x => new { x.DichVuId, x.GiaDuKien }))
            invoice.Chitiethoadons.Add(new Chitiethoadon { DichVuId = group.Key.DichVuId, SoLuong = group.Count(), DonGia = group.Key.GiaDuKien });
        foreach (var group in details.Where(x => x.ComboId.HasValue).GroupBy(x => x.ComboId!.Value))
        {
            var total = group.Sum(x => x.GiaDuKien);
            var copies = 1;
            if (combos.TryGetValue(group.Key, out var combo) && combo.Chitietcombos.Count > 0)
            {
                var counts = group.GroupBy(x => x.DichVuId).ToDictionary(x => x.Key, x => x.Count());
                var quantities = combo.Chitietcombos.Select(x => x.SoLuong > 0 && counts.TryGetValue(x.DichVuId, out var count)
                    && count % x.SoLuong == 0 ? count / x.SoLuong : 0).Distinct().ToList();
                if (counts.Count == combo.Chitietcombos.Count && quantities.Count == 1 && quantities[0] > 0
                    && decimal.Round(total / quantities[0], 2) * quantities[0] == total) copies = quantities[0];
            }
            // Historical combo edits cannot change the booked total; use an aggregate line when quantity is no longer inferable.
            invoice.Chitiethoadons.Add(new Chitiethoadon { ComboId = group.Key, SoLuong = copies, DonGia = total / copies });
        }
        invoice.TongTienTruocGiam = invoice.TongTienSauGiam = invoice.Chitiethoadons.Sum(x => x.SoLuong * x.DonGia);
        if (invoice.TongTienSauGiam == 0) invoice.TrangThai = "DaThanhToan";
        db.Hoadons.Add(invoice);
        await NotificationEvents.InvoiceReadyAsync(notifications, invoice, ct);
        return null;
    }
}
