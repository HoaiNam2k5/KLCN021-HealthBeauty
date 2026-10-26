using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AppointmentInvoiceLifecycleTests
{
    private const string Key = "test-only-completion-payment-secret-32chars";
    private sealed class ConflictContext(DbContextOptions<Klcn021HealthBeautyContext> options) : Klcn021HealthBeautyContext(options)
    {
        public bool FailSave { get; set; }
        public override Task<int> SaveChangesAsync(CancellationToken ct = default) =>
            FailSave ? throw new DbUpdateConcurrencyException("Simulated lifecycle CAS conflict") : base.SaveChangesAsync(ct);
    }
    private static async Task<ConflictContext> Database(string status = "DangThucHien")
    {
        var db = new ConflictContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Taikhoans.AddRange(new Taikhoan { TaiKhoanId = 1, Email = "customer1@test.invalid", MatKhauHash = "unused", TrangThai = true },
            new Taikhoan { TaiKhoanId = 2, Email = "customer2@test.invalid", MatKhauHash = "unused", TrangThai = true });
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "One", DiemThuong = 50 },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Two" });
        db.Dichvus.AddRange(new Dichvu { DichVuId = 1, TenDichVu = "One", Gia = 900000, TrangThai = true },
            new Dichvu { DichVuId = 2, TenDichVu = "Two", Gia = 800000, TrangThai = true });
        db.Lichhens.Add(new Lichhen { LichHenId = 7, KhachHangId = 1, TrangThai = status, NgayGioHen = DateTime.Now,
            Chitietlichhens = [new() { DichVuId = 1, GiaDuKien = 100000 }, new() { DichVuId = 2, GiaDuKien = 200000 }] });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static T User<T>(T controller, string role = "Reception", int id = 99) where T : ControllerBase
    {
        controller.ControllerContext = new() { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static BankTransfersController Bank(Klcn021HealthBeautyContext db)
    {
        var controller = new BankTransfersController(db, Options.Create(new BankTransferOptions { Enabled = true, BankName = "MBBank",
            BankCode = "MBBank", AccountNumber = "00112233", AccountName = "TEST", WebhookApiKey = Key }), new NotificationService(db))
            { ControllerContext = new() { HttpContext = new DefaultHttpContext() } };
        controller.Request.Headers.Authorization = "Apikey " + Key;
        return controller;
    }
    private static async Task<Hoadon> Complete(Klcn021HealthBeautyContext db)
    {
        Assert.IsType<NoContentResult>(await User(new AppointmentManagementController(db)).Status(7, new("HoanThanh"), default));
        return await db.Hoadons.Include(x => x.Chitiethoadons).SingleAsync();
    }
    private static async Task Voucher(Klcn021HealthBeautyContext db, int percent = 10)
    {
        db.Khuyenmais.Add(new Khuyenmai { KhuyenMaiId = 1, TenKhuyenMai = "Offer", LoaiGiam = "PhanTram", MucGiam = percent,
            NgayBatDauHieuLuc = DateTime.Now.AddDays(-1), NgayKetThucHieuLuc = DateTime.Now.AddDays(1) });
        db.Vouchers.Add(new Voucher { VoucherId = 1, KhuyenMaiId = 1, MaCode = "OFF", KhachHangId = 1,
            GiaTriGiam = 300000, HanSuDung = DateTime.Now.AddDays(1), TrangThai = true });
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task ConfirmationCompletionPendingNoticePaymentAndCustomerHistoryFormOneLifecycle()
    {
        await using var db = await Database("ChoXacNhan");
        var appointments = User(new AppointmentManagementController(db));
        foreach (var status in new[] { "DaXacNhan", "DaDen", "DangThucHien" })
        {
            Assert.IsType<NoContentResult>(await appointments.Status(7, new(status), default));
            Assert.Empty(await db.Hoadons.ToListAsync());
        }
        var invoice = await Complete(db);
        Assert.Equal("ChuaThanhToan", invoice.TrangThai);
        Assert.Equal(300000m, invoice.TongTienSauGiam);
        Assert.Equal(2, invoice.Chitiethoadons.Count);
        var pending = Assert.Single(await db.ThongBaos.Where(x => x.LoaiThongBao == "HoaDon").ToListAsync());
        Assert.Equal(1, pending.TaiKhoanId);
        var data = JsonDocument.Parse(pending.DuLieuKemTheo!).RootElement;
        Assert.Equal("INVOICE", data.GetProperty("type").GetString());
        Assert.Equal("7", data.GetProperty("appointmentId").GetString());
        Assert.False(data.TryGetProperty("invoiceId", out _));
        Assert.IsType<ConflictObjectResult>(await appointments.Status(7, new("HoanThanh"), default));
        Assert.Single(await db.Hoadons.ToListAsync());
        Assert.IsType<ConflictObjectResult>(await User(new InvoicesController(db)).Create(new(7, [new(1, null, 1), new(2, null, 1)], null), default));
        var own = User(new InvoicesController(db), "Customer", 1);
        var filtered = Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(Assert.IsType<OkObjectResult>(await own.List(default, status: "ChuaThanhToan", appointmentId: 7)).Value);
        Assert.Equal(invoice.HoaDonId, Assert.Single(filtered).Id);
        var other = User(new InvoicesController(db), "Customer", 2);
        Assert.Empty(Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(Assert.IsType<OkObjectResult>(await other.List(default, status: "ChuaThanhToan", appointmentId: 7)).Value));
        var request = new SePayWebhookRequest(123, "MBBank", "00112233", "in", 300000m, "HB" + invoice.HoaDonId,
            "HB" + invoice.HoaDonId, "TEST-123", DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss"));
        Assert.IsType<OkObjectResult>(await Bank(db).Webhook(request, default));
        Assert.IsType<OkObjectResult>(await Bank(db).Webhook(request, default));
        Assert.Equal("DaThanhToan", invoice.TrangThai);
        Assert.Single(await db.Thanhtoans.ToListAsync());
        Assert.Single(await db.Giaodichdiems.Where(x => x.SoDiem > 0).ToListAsync());
        Assert.Equal(80, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Equal(2, await db.ThongBaos.CountAsync(x => x.LoaiThongBao == "HoaDon"));
        Assert.Empty(Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(Assert.IsType<OkObjectResult>(await own.List(default, status: "ChuaThanhToan")).Value));
        Assert.Equal("DaThanhToan", Assert.Single(Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(Assert.IsType<OkObjectResult>(await own.List(default, status: "DaThanhToan")).Value)).Status);
    }

    [Fact]
    public async Task RepeatedComboCopiesUseBookedAllocationNotCurrentCatalogPrice()
    {
        await using var db = await Database();
        db.Chitietlichhens.RemoveRange(await db.Chitietlichhens.ToListAsync());
        db.Combodichvus.Add(new Combodichvu { ComboId = 3, TenCombo = "Two copies", GiaCombo = 999999, TrangThai = true,
            Chitietcombos = [new() { DichVuId = 1, SoLuong = 1 }, new() { DichVuId = 2, SoLuong = 1 }] });
        db.Chitietlichhens.AddRange(Enumerable.Range(0, 4).Select(i => new Chitietlichhen { LichHenId = 7, ComboId = 3, DichVuId = i % 2 + 1, GiaDuKien = 50000 }));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var invoice = await Complete(db);
        var line = Assert.Single(invoice.Chitiethoadons);
        Assert.Equal(3, line.ComboId); Assert.Null(line.DichVuId);
        Assert.Equal(2, line.SoLuong); Assert.Equal(100000m, line.DonGia);
        Assert.Equal(200000m, invoice.TongTienSauGiam);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task FreeAndPackageFundedCompletionsNeverRequestSecondCharge(bool package)
    {
        await using var db = await Database();
        if (package) (await db.Lichhens.FindAsync(7))!.CustomerPackageId = 10;
        else foreach (var item in await db.Chitietlichhens.ToListAsync()) item.GiaDuKien = 0;
        await db.SaveChangesAsync();
        var invoice = await Complete(db);
        Assert.Equal(0m, invoice.TongTienSauGiam); Assert.Equal("DaThanhToan", invoice.TrangThai);
        Assert.Empty(await db.Thanhtoans.ToListAsync()); Assert.Empty(await db.Giaodichdiems.ToListAsync());
        Assert.DoesNotContain(await db.ThongBaos.ToListAsync(), x => x.TieuDe == "Hóa đơn đang chờ thanh toán");
    }

    [Fact]
    public async Task LegacyEmptyAppointmentCompletesWithZeroPaidReceiptAndNoPaymentRequest()
    {
        await using var db = await Database();
        db.Chitietlichhens.RemoveRange(await db.Chitietlichhens.ToListAsync());
        await db.SaveChangesAsync();
        var invoice = await Complete(db);
        Assert.Empty(invoice.Chitiethoadons);
        Assert.Equal(0, invoice.TongTienSauGiam);
        Assert.Equal("DaThanhToan", invoice.TrangThai);
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.DoesNotContain(await db.ThongBaos.ToListAsync(), x => x.TieuDe == "Hóa đơn đang chờ thanh toán");
    }

    [Fact]
    public async Task CancellationDoesNotCreateInvoiceAndCustomerOrTechnicianCannotComplete()
    {
        await using var db = await Database("ChoXacNhan");
        Assert.IsType<ForbidResult>(await User(new AppointmentManagementController(db), "Customer", 1).Status(7, new("HoanThanh"), default));
        Assert.IsType<ForbidResult>(await User(new AppointmentManagementController(db), "Staff", 3).Status(7, new("HoanThanh"), default));
        Assert.IsType<NoContentResult>(await User(new AppointmentManagementController(db)).Status(7, new("DaHuy", "Customer requested cancellation"), default));
        Assert.Empty(await db.Hoadons.ToListAsync());
    }

    [Fact]
    public async Task CompletionConcurrencyFailurePersistsNeitherStatusInvoiceNorNotice()
    {
        await using var db = await Database(); db.FailSave = true;
        Assert.IsType<ConflictObjectResult>(await User(new AppointmentManagementController(db)).Status(7, new("HoanThanh"), default));
        Assert.Empty(await db.Hoadons.ToListAsync()); Assert.Empty(await db.ThongBaos.ToListAsync());
        Assert.Equal("DangThucHien", (await db.Lichhens.FindAsync(7))!.TrangThai);
    }

    [Fact]
    public async Task FirstDiscountUsesVoucherAndClampedPointsExactlyOnceWithoutChangingLines()
    {
        await using var db = await Database(); var invoice = await Complete(db); await Voucher(db);
        var controller = User(new InvoicesController(db));
        var response = Assert.IsType<InvoiceResponse>(Assert.IsType<OkObjectResult>(await controller.Discounts(invoice.HoaDonId, new(" off ", 20), default)).Value);
        Assert.Equal(269980m, response.Total); Assert.Equal(300000m, response.Subtotal);
        Assert.Equal(30, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.False((await db.Vouchers.FindAsync(1))!.TrangThai);
        Assert.Equal(-20, Assert.Single(await db.Giaodichdiems.ToListAsync()).SoDiem);
        Assert.IsType<ConflictObjectResult>(await controller.Discounts(invoice.HoaDonId, new(null, 1), default));
        Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.Equal(300000m, invoice.Chitiethoadons.Sum(x => x.DonGia * x.SoLuong));
    }

    [Fact]
    public async Task HundredPercentDiscountAutoSettlesWithoutPaymentRowOrEarnedPoints()
    {
        await using var db = await Database(); var invoice = await Complete(db); await Voucher(db, 100);
        var response = Assert.IsType<InvoiceResponse>(Assert.IsType<OkObjectResult>(await User(new InvoicesController(db)).Discounts(invoice.HoaDonId, new("OFF"), default)).Value);
        Assert.Equal(0, response.Total); Assert.Equal("DaThanhToan", response.Status);
        Assert.Empty(await db.Thanhtoans.ToListAsync()); Assert.Empty(await db.Giaodichdiems.ToListAsync());
        Assert.Equal(50, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
    }

    [Fact]
    public async Task DiscountConcurrencyFailureDoesNotConsumePointsVoucherOrInvoiceBalance()
    {
        await using var db = await Database(); var invoice = await Complete(db); await Voucher(db); db.FailSave = true;
        Assert.IsType<ConflictObjectResult>(await User(new InvoicesController(db)).Discounts(invoice.HoaDonId, new("OFF", 20), default));
        Assert.Equal(300000m, (await db.Hoadons.FindAsync(invoice.HoaDonId))!.TongTienSauGiam);
        Assert.True((await db.Vouchers.FindAsync(1))!.TrangThai);
        Assert.Equal(50, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Empty(await db.Giaodichdiems.ToListAsync());
    }

    [Fact]
    public async Task FilterAndDiscountAuthorizationAndValidationStayClosed()
    {
        await using var db = await Database(); var invoice = await Complete(db);
        var customer = User(new InvoicesController(db), "Customer", 1);
        Assert.IsType<ForbidResult>(await customer.Discounts(invoice.HoaDonId, new(null, 1), default));
        Assert.IsType<BadRequestObjectResult>(await customer.List(default, status: "invalid"));
        Assert.IsType<BadRequestObjectResult>(await customer.List(default, appointmentId: -1));
        Assert.Equal("INVOICE.WRITE", DatabasePermissionFilter.RequiredPermission("Invoices", "Discounts", User(new InvoicesController(db)).User));
        var controller = User(new InvoicesController(db));
        Assert.IsType<BadRequestObjectResult>(await controller.Discounts(invoice.HoaDonId, new(null), default));
        Assert.IsType<BadRequestObjectResult>(await controller.Discounts(invoice.HoaDonId, new(null, 51), default));
        Assert.IsType<BadRequestObjectResult>(await controller.Discounts(invoice.HoaDonId, new("missing"), default));
        Assert.Equal(300000m, invoice.TongTienSauGiam);
    }

    [Fact]
    public async Task LegacyManualCreateStagesPendingNoticeForTheOwnedAppointment()
    {
        await using var db = await Database("HoanThanh");
        Assert.IsType<CreatedAtActionResult>(await User(new InvoicesController(db)).Create(new(7, [new(1, null, 1), new(2, null, 1)], null), default));
        var notice = Assert.Single(await db.ThongBaos.ToListAsync());
        Assert.Equal("HoaDon", notice.LoaiThongBao); Assert.Equal(1, notice.TaiKhoanId);
        Assert.Equal("7", JsonDocument.Parse(notice.DuLieuKemTheo!).RootElement.GetProperty("appointmentId").GetString());
    }
}
