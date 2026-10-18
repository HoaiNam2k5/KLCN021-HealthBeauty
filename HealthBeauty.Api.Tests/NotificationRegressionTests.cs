using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class NotificationRegressionTests
{
    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Taikhoans.AddRange(Enumerable.Range(1, 2).Select(id => new Taikhoan {
            TaiKhoanId = id, Email = $"customer{id}@example.invalid", MatKhauHash = "unused", TrangThai = true }));
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 11, TaiKhoanId = 1, HoTen = "First" },
            new Khachhang { KhachHangId = 22, TaiKhoanId = 2, HoTen = "Second" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }

    private static T AsUser<T>(T controller, int account = 1, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, account.ToString()),
                new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static JsonElement Json(object? value) => JsonSerializer.SerializeToElement(value,
        new JsonSerializerOptions(JsonSerializerDefaults.Web));
    private static ThongBao Notice(int id, int? account = null, int? customer = null) => new() {
        ThongBaoId = id, TaiKhoanId = account, KhachHangId = customer, TieuDe = $"Notice {id}",
        NoiDung = "Body", LoaiThongBao = "KhuyenMai", NgayTao = new DateTime(2026, 10, 1, 10, 0, 0) };
    private static async Task<JsonElement> Inbox(Klcn021HealthBeautyContext db, int account = 1, bool unread = false,
        int page = 1, int size = 20) => Json(Assert.IsType<OkObjectResult>(
            await AsUser(new NotificationsController(db), account).List(page, size, unread, default)).Value);

    [Fact]
    public async Task DeviceTokenIsUniqueAndRebindsOnAnotherAccountLogin()
    {
        await using var db = await Database();
        await AsUser(new NotificationsController(db)).RegisterDevice(new DeviceTokenRequest("device-token", "android"), default);
        await AsUser(new NotificationsController(db)).RegisterDevice(new DeviceTokenRequest("device-token", "android"), default);
        var device = Assert.Single(await db.ThietBiKhachHangs.ToListAsync());
        Assert.Equal(1, device.TaiKhoanId); Assert.Equal(11, device.KhachHangId); Assert.True(device.TrangThai);
        await AsUser(new NotificationsController(db), 2).RegisterDevice(new DeviceTokenRequest("device-token", "ios"), default);
        db.ChangeTracker.Clear(); device = Assert.Single(await db.ThietBiKhachHangs.ToListAsync());
        Assert.Equal(2, device.TaiKhoanId); Assert.Equal(22, device.KhachHangId); Assert.True(device.TrangThai);
    }

    [Fact]
    public async Task DeviceDeletionCannotDisableAnotherAccountsTokenAndCanBeRepeated()
    {
        await using var db = await Database();
        await AsUser(new NotificationsController(db)).RegisterDevice(new DeviceTokenRequest("owned-token", "android"), default);
        Assert.IsType<NoContentResult>(await AsUser(new NotificationsController(db), 2).DeleteDevice("owned-token", default));
        Assert.True((await db.ThietBiKhachHangs.SingleAsync()).TrangThai);
        var own = AsUser(new NotificationsController(db));
        Assert.IsType<NoContentResult>(await own.DeleteDevice("owned-token", default));
        Assert.IsType<NoContentResult>(await own.DeleteDevice("owned-token", default));
        Assert.False(await db.ThietBiKhachHangs.AnyAsync(x => x.TrangThai));
    }

    [Theory]
    [InlineData("", "android")]
    [InlineData("   ", "ios")]
    [InlineData("valid-token", "unsupported")]
    public async Task InvalidDeviceRequestDoesNotPersist(string token, string platform)
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await AsUser(new NotificationsController(db))
            .RegisterDevice(new DeviceTokenRequest(token, platform), default));
        Assert.Empty(await db.ThietBiKhachHangs.ToListAsync());
    }

    [Fact]
    public async Task LongOrWhitespaceContainingTokenIsRejectedAndWebTokenIsSupported()
    {
        await using var db = await Database(); var c = AsUser(new NotificationsController(db));
        foreach (var token in new[] { new string('x', 501), "token with space", "token\nnewline" })
            Assert.IsType<BadRequestObjectResult>(await c.RegisterDevice(new DeviceTokenRequest(token, "web"), default));
        Assert.Empty(await db.ThietBiKhachHangs.ToListAsync());
        Assert.IsType<OkObjectResult>(await c.RegisterDevice(new DeviceTokenRequest("web-token", "web"), default));
        Assert.Equal("web", (await db.ThietBiKhachHangs.SingleAsync()).LoaiThietBi);
    }

    [Fact]
    public async Task UnreadCountEndpointMatchesInboxAndDoesNotCountOtherCustomers()
    {
        await using var db = await Database(); db.ThongBaos.AddRange(Notice(1), Notice(2, 1, 11), Notice(3, 2, 22));
        await db.SaveChangesAsync(); var c = AsUser(new NotificationsController(db));
        Assert.Equal(2, Json(Assert.IsType<OkObjectResult>(await c.UnreadCount(default)).Value).GetProperty("unreadCount").GetInt32());
        await c.MarkRead(2, default);
        Assert.Equal(1, Json(Assert.IsType<OkObjectResult>(await c.UnreadCount(default)).Value).GetProperty("unreadCount").GetInt32());
    }

    [Fact]
    public async Task MissingCustomerProfileCannotRegisterOrReadInbox()
    {
        await using var db = await Database(); var c = AsUser(new NotificationsController(db), 99);
        Assert.IsType<ForbidResult>(await c.RegisterDevice(new DeviceTokenRequest("token", "android"), default));
        Assert.IsType<ForbidResult>(await c.List());
        Assert.Empty(await db.ThietBiKhachHangs.ToListAsync());
    }

    [Fact]
    public async Task InboxDoesNotExposeOtherCustomersIncludingUnlinkedPrivateNotice()
    {
        await using var db = await Database();
        db.ThongBaos.AddRange(Notice(1), Notice(2, 1, 11), Notice(3, 2, 22), Notice(4, null, 22));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var json = await Inbox(db); Assert.Equal(2, json.GetProperty("totalCount").GetInt32());
        Assert.Equal(new[] { 2, 1 }, json.GetProperty("items").EnumerateArray().Select(x => x.GetProperty("id").GetInt32()));
        var c = AsUser(new NotificationsController(db));
        Assert.IsType<NotFoundResult>(await c.MarkRead(3, default));
        Assert.IsType<NotFoundResult>(await c.MarkRead(4, default));
        Assert.Empty(await db.ThongBaoDaDocs.ToListAsync());
    }

    [Fact]
    public async Task BroadcastReadStateIsPrivatePerAccountAndRepeatedReadIsIdempotent()
    {
        await using var db = await Database(); db.ThongBaos.AddRange(Notice(1), Notice(2, 1, 11));
        await db.SaveChangesAsync(); var c = AsUser(new NotificationsController(db));
        Assert.IsType<NoContentResult>(await c.MarkRead(1, default));
        Assert.IsType<NoContentResult>(await c.MarkRead(1, default));
        Assert.Single(await db.ThongBaoDaDocs.ToListAsync());
        var own = await Inbox(db); Assert.Equal(1, own.GetProperty("unreadCount").GetInt32());
        Assert.True(own.GetProperty("items").EnumerateArray().Single(x => x.GetProperty("id").GetInt32() == 1).GetProperty("isRead").GetBoolean());
        var other = await Inbox(db, 2); Assert.Equal(1, other.GetProperty("unreadCount").GetInt32());
        Assert.False(other.GetProperty("items")[0].GetProperty("isRead").GetBoolean());
        var unread = await Inbox(db, unread: true); Assert.Equal(1, unread.GetProperty("totalCount").GetInt32());
        Assert.Equal(2, unread.GetProperty("items")[0].GetProperty("id").GetInt32());
    }

    [Fact]
    public async Task ReadAllOnlyMarksVisibleSnapshotAndLeavesFutureBroadcastUnread()
    {
        await using var db = await Database(); db.ThongBaos.AddRange(Notice(1), Notice(2, 1, 11), Notice(3, 2, 22));
        await db.SaveChangesAsync(); var c = AsUser(new NotificationsController(db));
        Assert.IsType<NoContentResult>(await c.ReadAll(default));
        Assert.IsType<NoContentResult>(await c.ReadAll(default));
        Assert.Equal(2, await db.ThongBaoDaDocs.CountAsync());
        Assert.Equal(0, (await Inbox(db)).GetProperty("unreadCount").GetInt32());
        Assert.Equal(2, (await Inbox(db, 2)).GetProperty("unreadCount").GetInt32());
        db.ThongBaos.Add(Notice(4)); await db.SaveChangesAsync();
        Assert.Equal(1, (await Inbox(db)).GetProperty("unreadCount").GetInt32());
    }

    [Fact]
    public async Task PaginationHasStableIdTieBreakerAndClampsInvalidAndOversizedPages()
    {
        await using var db = await Database(); db.ThongBaos.AddRange(Enumerable.Range(1, 105).Select(id => Notice(id)));
        await db.SaveChangesAsync();
        var first = await Inbox(db, page: -5, size: 1000);
        Assert.Equal(100, first.GetProperty("items").GetArrayLength());
        Assert.Equal(105, first.GetProperty("items")[0].GetProperty("id").GetInt32());
        var second = await Inbox(db, page: 2, size: 100);
        Assert.Equal(new[] { 5, 4, 3, 2, 1 }, second.GetProperty("items").EnumerateArray().Select(x => x.GetProperty("id").GetInt32()));
        Assert.Equal(105, second.GetProperty("unreadCount").GetInt32());
    }

    [Fact]
    public async Task ServiceStagesOnlyAndSkipsCustomerWithoutLinkedAccount()
    {
        await using var db = await Database();
        db.Khachhangs.Add(new Khachhang { KhachHangId = 33, HoTen = "Unlinked" }); await db.SaveChangesAsync();
        var service = new NotificationService(db);
        await service.StageToCustomerAsync(11, "Title", "Body", "LichHen", new Dictionary<string, string> { ["appointmentId"] = "17" });
        await service.StageToCustomerAsync(33, "Private", "Body", "LichHen");
        Assert.Empty(await db.ThongBaos.AsNoTracking().ToListAsync());
        await db.SaveChangesAsync(); var notice = Assert.Single(await db.ThongBaos.ToListAsync());
        Assert.Equal(1, notice.TaiKhoanId); Assert.Equal(11, notice.KhachHangId);
        Assert.Equal("17", JsonDocument.Parse(notice.DuLieuKemTheo!).RootElement.GetProperty("appointmentId").GetString());
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task AppointmentChangesNotifyOnlyAfterValidTransitionAndNeverOnDuplicate(bool cancel)
    {
        await using var db = await Database();
        db.Lichhens.Add(new Lichhen { LichHenId = 7, KhachHangId = 11, NgayGioHen = DateTime.Today.AddDays(2), TrangThai = "ChoXacNhan" });
        await db.SaveChangesAsync();
        var c = AsUser(new AppointmentManagementController(db), 1, cancel ? "Customer" : "Reception");
        Assert.IsType<NoContentResult>(cancel ? await c.Cancel(7, default) : await c.Status(7, new AppointmentStatusRequest("DaXacNhan"), default));
        var notice = Assert.Single(await db.ThongBaos.ToListAsync()); Assert.Equal(1, notice.TaiKhoanId);
        Assert.Contains("7", notice.DuLieuKemTheo!);
        Assert.IsType<ConflictObjectResult>(cancel ? await c.Cancel(7, default) : await c.Status(7, new AppointmentStatusRequest("DaXacNhan"), default));
        Assert.Single(await db.ThongBaos.ToListAsync());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(100000)]
    public async Task InvoiceSettlementNotifiesForBothZeroAndPaidAndRejectsDuplicate(decimal amount)
    {
        await using var db = await Database();
        db.Hoadons.Add(new Hoadon { HoaDonId = 8, KhachHangId = 11, TrangThai = "ChuaThanhToan", TongTienSauGiam = amount });
        await db.SaveChangesAsync(); var c = AsUser(new InvoicesController(db), 99, "Reception");
        Assert.IsType<BadRequestObjectResult>(await c.Pay(8, new PaymentRequest("TienMat", "ThatBai"), default));
        Assert.Empty(await db.ThongBaos.ToListAsync());
        Assert.IsType<OkObjectResult>(await c.Pay(8, new PaymentRequest("TienMat"), default));
        var notice = Assert.Single(await db.ThongBaos.ToListAsync()); Assert.Equal(1, notice.TaiKhoanId);
        Assert.Contains("8", notice.DuLieuKemTheo!);
        Assert.IsType<ConflictObjectResult>(await c.Pay(8, new PaymentRequest("TienMat"), default));
        Assert.Single(await db.ThongBaos.ToListAsync());
    }

    [Fact]
    public async Task PromotionsAreBroadcastButCustomerVoucherIsPrivateAndDuplicatesDoNotNotify()
    {
        await using var db = await Database(); var c = AsUser(new PromotionsController(db), 99, "Reception");
        Assert.IsType<CreatedResult>(await c.Create(new PromotionRequest("Offer", "PhanTram", 10, null, null, null), default));
        var broadcast = Assert.Single(await db.ThongBaos.ToListAsync());
        Assert.Null(broadcast.TaiKhoanId); Assert.Null(broadcast.KhachHangId);
        int promotionId = (await db.Khuyenmais.SingleAsync()).KhuyenMaiId;
        var request = new VoucherRequest("PERSONAL", promotionId, 11, 10, DateTime.Now.AddDays(7));
        Assert.IsType<CreatedResult>(await c.CreateVoucher(request, default));
        Assert.Equal(2, await db.ThongBaos.CountAsync());
        Assert.Single(await db.ThongBaos.Where(x => x.TaiKhoanId == 1 && x.KhachHangId == 11).ToListAsync());
        Assert.IsType<ConflictObjectResult>(await c.CreateVoucher(request, default));
        Assert.Equal(2, await db.ThongBaos.CountAsync());
        Assert.Equal(1, (await Inbox(db, 2)).GetProperty("totalCount").GetInt32());
    }
}
