using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace HealthBeauty.Api.Services;
public static class ServicePackageLifecycle
{
    public static async Task<string?> ReserveAsync(Klcn021HealthBeautyContext db, Lichhen appointment, int packageId, CancellationToken ct)
    {
        var package = await db.CustomerPackages.Include(x => x.Items).SingleOrDefaultAsync(x => x.Id == packageId, ct);
        if (package is null || package.CustomerId != appointment.KhachHangId) return "Package does not belong to this customer.";
        if (package.Status != "Paid" || !package.ExpiresAt.HasValue || appointment.NgayGioHen > package.ExpiresAt.Value || DateTime.Now > package.ExpiresAt.Value) return "Package is unpaid or expires before this appointment.";
        var quantities = appointment.Chitietlichhens.GroupBy(x => x.DichVuId).ToList();
        if (quantities.Count == 0 || appointment.Chitietlichhens.Any(x => x.ComboId.HasValue)) return "A package appointment requires covered ordinary services.";
        foreach (var group in quantities)
        {
            var entitlement = package.Items.SingleOrDefault(x => x.ServiceId == group.Key);
            if (entitlement is null || entitlement.Granted - entitlement.Reserved - entitlement.Used < group.Count()) return "Insufficient available sessions for a booked service.";
        }
        foreach (var group in quantities)
        {
            var entitlement = package.Items.Single(x => x.ServiceId == group.Key);
            var quantity = group.Count();
            entitlement.Version = Guid.NewGuid();
            entitlement.Reserved += quantity;
            db.PackageUsages.Add(new PackageUsage
            {
                CustomerPackageItemId = entitlement.Id,
                Appointment = appointment,
                Quantity = quantity,
                CreatedAt = DateTime.Now
            });
        }
        appointment.CustomerPackageId = packageId;
        return null;
    }
    public static async Task<bool> ValidDateAsync(Klcn021HealthBeautyContext db, Lichhen a, DateTime date, CancellationToken ct) => !a.CustomerPackageId.HasValue || await db.CustomerPackages.AnyAsync(x => x.Id == a.CustomerPackageId && x.Status == "Paid" && x.ExpiresAt >= date, ct);
    public static async Task SettleAsync(Klcn021HealthBeautyContext db, Lichhen a, bool complete, CancellationToken ct)
    {
        if (!a.CustomerPackageId.HasValue) return;
        var usages = await db.PackageUsages.Where(x => x.AppointmentId == a.LichHenId && x.Status == "Reserved").ToListAsync(ct);
        var ids = usages.Select(x => x.CustomerPackageItemId).ToList();
        var items = await db.CustomerPackageItems.Where(x => ids.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        foreach (var usage in usages)
        {
            var item = items[usage.CustomerPackageItemId];
            item.Version = Guid.NewGuid();
            item.Reserved -= usage.Quantity;
            if (complete) item.Used += usage.Quantity;
            usage.Status = complete ? "Consumed" : "Released";
            usage.SettledAt = DateTime.Now;
        }
        if (complete && !await db.Hoadons.AnyAsync(x => x.LichHenId == a.LichHenId, ct))
        {
            var details = await db.Chitietlichhens.Where(x => x.LichHenId == a.LichHenId).ToListAsync(ct);
            db.Hoadons.Add(new Hoadon
            {
                LichHenId = a.LichHenId,
                KhachHangId = a.KhachHangId,
                NgayLap = DateTime.Now,
                TrangThai = "DaThanhToan",
                TongTienTruocGiam = 0,
                TongTienSauGiam = 0,
                Chitiethoadons = details.GroupBy(x => x.DichVuId).Select(g => new Chitiethoadon
                {
                    DichVuId = g.Key,
                    SoLuong = g.Count(),
                    DonGia = 0
                }
            ).ToList()
            });
        }
    }
}
