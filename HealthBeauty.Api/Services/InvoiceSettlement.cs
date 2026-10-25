using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

// Save together: invoice/customer rowversions also protect races with staff payments.
public static class InvoiceSettlement
{
    public static async Task<Thanhtoan?> StageAsync(Klcn021HealthBeautyContext db,
        INotificationService notifications, Hoadon invoice, string method, DateTime paidAt, CancellationToken ct)
    {
        invoice.TrangThai = "DaThanhToan";
        Thanhtoan? payment = null;
        var earned = 0;
        if (invoice.TongTienSauGiam > 0)
        {
            payment = new Thanhtoan
            {
                HoaDonId = invoice.HoaDonId, PhuongThuc = method,
                SoTien = invoice.TongTienSauGiam, NgayGioThanhToan = paidAt, TrangThai = "ThanhCong"
            };
            invoice.Thanhtoans.Add(payment);
            var customer = await db.Khachhangs.FirstAsync(x => x.KhachHangId == invoice.KhachHangId, ct);
            earned = decimal.ToInt32(decimal.Floor(invoice.TongTienSauGiam / 10000m));
            if (earned > 0)
            {
                customer.DiemThuong += earned;
                db.Giaodichdiems.Add(new Giaodichdiem
                {
                    KhachHangId = customer.KhachHangId, HoaDonId = invoice.HoaDonId,
                    SoDiem = earned, LoaiGiaoDich = "TichLuy", NgayGiaoDich = paidAt,
                    GhiChu = "Tích điểm thanh toán"
                });
            }
        }
        await NotificationEvents.PaidAsync(notifications, invoice, earned, ct);
        return payment;
    }
}
