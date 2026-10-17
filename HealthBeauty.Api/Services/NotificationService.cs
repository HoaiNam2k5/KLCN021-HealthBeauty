using System.Globalization;
using System.Text.Json;
using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public interface INotificationService
{
    Task StageToCustomerAsync(int customerId, string title, string body, string type,
        Dictionary<string, string>? data = null, CancellationToken ct = default);
    void StagePromotion(string title, string body, int promotionId);
}

// Stage only: the caller saves these rows together with the business changes.
public sealed class NotificationService(Klcn021HealthBeautyContext db) : INotificationService
{
    public async Task StageToCustomerAsync(int customerId, string title, string body, string type,
        Dictionary<string, string>? data = null, CancellationToken ct = default)
    {
        var accountId = await db.Khachhangs.Where(x => x.KhachHangId == customerId)
            .Select(x => x.TaiKhoanId).SingleOrDefaultAsync(ct);
        // A customer without a login must never become a public broadcast.
        if (accountId is null) return;
        db.ThongBaos.Add(New(accountId, customerId, title, body, type, data));
    }

    public void StagePromotion(string title, string body, int promotionId) => db.ThongBaos.Add(
        New(null, null, title, body, "KhuyenMai", new() { ["type"] = "PROMOTION", ["promotionId"] = promotionId.ToString(CultureInfo.InvariantCulture) }));

    private static ThongBao New(int? accountId, int? customerId, string title, string body, string type, Dictionary<string, string>? data)
    {
        var now = DateTime.UtcNow;
        return new ThongBao
        {
            TaiKhoanId = accountId, KhachHangId = customerId,
            TieuDe = title.Length <= 250 ? title : title[..250],
            NoiDung = body.Length <= 1000 ? body : body[..1000], LoaiThongBao = type,
            DuLieuKemTheo = data is null ? null : JsonSerializer.Serialize(data),
            NgayTao = now, NextPushAt = now, PushStatus = "Pending"
        };
    }
}
