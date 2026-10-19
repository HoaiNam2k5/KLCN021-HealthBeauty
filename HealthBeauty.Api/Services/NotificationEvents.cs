using System.Globalization;
using HealthBeauty.Api.Models;

namespace HealthBeauty.Api.Services;

public static class NotificationEvents
{
    public static Task AppointmentAsync(INotificationService notifications, Lichhen item, string change, CancellationToken ct)
    {
        var code = $"#LH{item.LichHenId}";
        var time = item.NgayGioHen.ToString("HH:mm dd/MM/yyyy", CultureInfo.InvariantCulture);
        var (title, body) = change switch
        {
            "DaXacNhan" => ($"Lịch hẹn {code} đã được xác nhận", $"HealthBeauty đã xác nhận lịch hẹn lúc {time}. Hẹn gặp quý khách!"),
            "DaDen" => ("Chào mừng quý khách đến HealthBeauty", $"Quý khách đã check-in cho lịch hẹn {code}."),
            "DangThucHien" => ("Dịch vụ đang được thực hiện", $"Lịch hẹn {code} đang được kỹ thuật viên chăm sóc."),
            "HoanThanh" => ($"Lịch hẹn {code} đã hoàn thành", "Cảm ơn quý khách đã sử dụng dịch vụ tại HealthBeauty! Quý khách có thể đánh giá sau khi thanh toán."),
            "DaHuy" => ($"Lịch hẹn {code} đã bị hủy", $"Lịch hẹn lúc {time} đã được hủy."),
            "Rescheduled" => ($"Lịch hẹn {code} đã đổi lịch", $"Thời gian hẹn mới: {time}."),
            _ => ("Thông tin lịch hẹn", $"Lịch hẹn {code} đã được cập nhật.")
        };
        return notifications.StageToCustomerAsync(item.KhachHangId, title, body, "LichHen",
            new() { ["type"] = "APPOINTMENT", ["appointmentId"] = item.LichHenId.ToString(CultureInfo.InvariantCulture) }, ct);
    }

    public static Task PaidAsync(INotificationService notifications, Hoadon invoice, int earnedPoints, CancellationToken ct) =>
        notifications.StageToCustomerAsync(invoice.KhachHangId, $"Thanh toán thành công #{invoice.HoaDonId}",
            $"Hóa đơn {invoice.TongTienSauGiam.ToString("N0", CultureInfo.GetCultureInfo("vi-VN"))} đ đã được thanh toán. Điểm tích lũy: {earnedPoints}.",
            "HoaDon", new() { ["type"] = "INVOICE", ["invoiceId"] = invoice.HoaDonId.ToString(CultureInfo.InvariantCulture),
                ["earnedPoints"] = earnedPoints.ToString(CultureInfo.InvariantCulture) }, ct);
}
