using System.Globalization;
using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public static class PackageSettlement
{
    // Caller saves package CAS, rewards, notification and provider ledger together.
    public static async Task<string?> StageAsync(Klcn021HealthBeautyContext db, INotificationService notifications,
        CustomerPackage purchase, string method, DateTime paidAt, int? actor, CancellationToken ct)
    {
        if (purchase.Status != "Pending") return "Purchase is already paid or cancelled.";
        var customer = await db.Khachhangs.SingleAsync(x => x.KhachHangId == purchase.CustomerId, ct);
        // SQL13 CK_CustomerPackage_Paid requires a real account for every paid
        // purchase. A verified automatic transfer records the owning customer
        // as payer; a clerk payment continues to record that authenticated clerk.
        var recordedPayer = actor ?? customer.TaiKhoanId;
        if (!recordedPayer.HasValue) return "Customer account is required for automatic package payment. Please contact reception.";
        var points = (int)decimal.Floor(purchase.Price / 10000m);
        if (points > 0 && customer.DiemThuong > int.MaxValue - points) return "Reward balance limit exceeded.";
        purchase.Version = Guid.NewGuid();
        purchase.Status = "Paid";
        purchase.PaidAt = paidAt;
        purchase.ExpiresAt = paidAt.AddDays(purchase.ValidityDays);
        purchase.PaymentMethod = method;
        purchase.PaidByAccountId = recordedPayer;
        if (points > 0)
        {
            customer.DiemThuong += points;
            db.Giaodichdiems.Add(new Giaodichdiem
            {
                KhachHangId = customer.KhachHangId, CustomerPackageId = purchase.Id, SoDiem = points,
                LoaiGiaoDich = "TichLuy", NgayGiaoDich = paidAt, GhiChu = "Package purchase"
            });
        }
        await notifications.StageToCustomerAsync(purchase.CustomerId, "Thanh toán gói dịch vụ thành công",
            $"Gói {purchase.Name} đã được kích hoạt. Quý khách có thể đặt lịch bằng số lượt trong gói.", "GoiDichVu",
            new() { ["type"] = "PACKAGE", ["purchaseId"] = purchase.Id.ToString(CultureInfo.InvariantCulture), ["status"] = "Paid" }, ct);
        return null;
    }
}
