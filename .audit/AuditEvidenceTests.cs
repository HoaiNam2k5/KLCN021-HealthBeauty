using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace HealthBeauty.Api.Audit;

// These tests assert observed defects, not the desired corrected behavior.
public sealed class AuditEvidenceTests
{
    private static readonly DateTime Day = DateTime.Today.AddDays(5);
    private static async Task<Klcn021HealthBeautyContext> Db(string status = "DaXacNhan")
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Vaitros.Add(new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" });
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, VaiTroId = 1, Email = "audit@example.invalid", MatKhauHash = new PasswordService().Hash("AuditPassword123"), TrangThai = true });
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Audit Customer", DiemThuong = 500 });
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 1, HoTen = "Audit Staff" });
        db.Lichlamviecs.Add(new Lichlamviec { LichLamViecId = 1, NhanVienId = 1, NgayLam = DateOnly.FromDateTime(Day), GioBatDau = new TimeOnly(9, 0), GioKetThuc = new TimeOnly(17, 0), TrangThai = "HoatDong" });
        db.Dichvus.AddRange(new Dichvu { DichVuId = 1, TenDichVu = "Expensive", Gia = 1000m, ThoiLuongPhut = 60, TrangThai = true }, new Dichvu { DichVuId = 2, TenDichVu = "Cheap", Gia = 100m, ThoiLuongPhut = 15, TrangThai = true });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day.AddHours(9), TrangThai = status,
            Chitietlichhens = [new Chitietlichhen { ChiTietLichHenId = 1, DichVuId = 1, ThoiLuongThucTe = 60, GiaDuKien = 1000m }] });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static T User<T>(T controller, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "1"), new Claim(ClaimTypes.Role, role)], "Audit")) } };
        return controller;
    }

    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_AppointmentDetailHasJsonCycle()
    {
        await using var db = await Db();
        var result = Assert.IsType<OkObjectResult>(await User(new AppointmentManagementController(db)).Get(1, default));
        Assert.Throws<JsonException>(() => JsonSerializer.Serialize(result.Value));
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_StaffDetailWithShiftHasJsonCycle()
    {
        await using var db = await Db();
        var result = Assert.IsType<OkObjectResult>(await User(new StaffManagementController(db), "Admin").Get(1, default));
        Assert.Throws<JsonException>(() => JsonSerializer.Serialize(result.Value));
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_CustomerCanCancelCompletedAppointment()
    {
        await using var db = await Db("HoanThanh");
        Assert.IsType<NoContentResult>(await User(new AppointmentManagementController(db)).Cancel(1, default));
        Assert.Equal("DaHuy", (await db.Lichhens.FindAsync(1))!.TrangThai);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_CustomerCanMoveCompletedAppointment()
    {
        await using var db = await Db("HoanThanh");
        Assert.IsType<OkObjectResult>(await User(new AppointmentManagementController(db)).Reschedule(1, new AppointmentUpdateRequest(Day.AddHours(11), 1, null), default));
        Assert.Equal(Day.AddHours(11), (await db.Lichhens.FindAsync(1))!.NgayGioHen);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_OneBookingHidesWholeWorkingShift()
    {
        await using var db = await Db();
        var result = Assert.IsType<OkObjectResult>(await new AppointmentManagementController(db).AvailableSlots(DateOnly.FromDateTime(Day), 1, default));
        Assert.Empty((System.Collections.IEnumerable)result.Value!);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_CustomerCanBookAtThreeAMOutsideShift()
    {
        await using var db = await Db();
        var result = await User(new AppointmentsController(db)).Create(new CreateAppointmentRequest(Day.AddHours(3), [new AppointmentItemRequest(1, null, 0)], null, null, 1), default);
        Assert.IsType<CreatedAtActionResult>(result.Result);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_BookingAcceptsClientPriceOneInsteadOfOneThousand()
    {
        await using var db = await Db();
        var result = await User(new AppointmentsController(db)).Create(new CreateAppointmentRequest(Day.AddHours(11), [new AppointmentItemRequest(1, null, 1m)], null, null, 1), default);
        var response = Assert.IsType<AppointmentResponse>(Assert.IsType<CreatedAtActionResult>(result.Result).Value);
        Assert.Equal(1m, Assert.Single(response.Items).ExpectedPrice);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_CustomerCanUnderbillCancelledAppointmentAndConfirmPayment()
    {
        await using var db = await Db("DaHuy");
        var controller = User(new InvoicesController(db));
        Assert.IsType<CreatedAtActionResult>(await controller.Create(new CreateInvoiceRequest(1, [new InvoiceLineRequest(2, null, 1)], null), default));
        var invoice = await db.Hoadons.SingleAsync();
        Assert.Equal(100m, invoice.TongTienSauGiam);
        Assert.IsType<OkObjectResult>(await controller.Pay(invoice.HoaDonId, new PaymentRequest("TienMat"), default));
        Assert.Equal("DaThanhToan", invoice.TrangThai);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_RedeemTwoHundredPointsForOneHundredDiscount()
    {
        await using var db = await Db("HoanThanh");
        (await db.Dichvus.FindAsync(1))!.Gia=100m; await db.SaveChangesAsync();
        Assert.IsType<CreatedAtActionResult>(await User(new InvoicesController(db)).Create(new CreateInvoiceRequest(1, [new InvoiceLineRequest(1, null, 1)], null, 200), default));
        Assert.Equal(300, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Equal(0m, (await db.Hoadons.SingleAsync()).TongTienSauGiam);
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_PaymentAttemptsToInsertZeroAmount()
    {
        await using var db = await Db("HoanThanh");
        (await db.Dichvus.FindAsync(1))!.Gia=100m; await db.SaveChangesAsync();
        var controller = User(new InvoicesController(db));
        await controller.Create(new CreateInvoiceRequest(1, [new InvoiceLineRequest(1, null, 1)], null, 100), default);
        var invoice = await db.Hoadons.SingleAsync();
        Assert.IsType<OkObjectResult>(await User(controller, "Admin").Pay(invoice.HoaDonId, new PaymentRequest("TienMat"), default));
        Assert.Equal(0m, (await db.Thanhtoans.SingleAsync()).SoTien); // SQL CHECK requires > 0.
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_FiveFailedLoginsDoNotLockOrLogAccount()
    {
        await using var db = await Db();
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> { ["Jwt:Key"] = "audit-only-key-never-used-for-real-users-123", ["Jwt:Issuer"] = "Audit", ["Jwt:Audience"] = "Audit" }).Build();
        var controller = User(new AuthController(db, new PasswordService(), new TokenService(config), config));
        for(var i=0;i<5;i++) Assert.IsType<UnauthorizedObjectResult>((await controller.Login(new LoginRequest("audit@example.invalid", "WrongPassword"), default)).Result);
        var account = await db.Taikhoans.FindAsync(1);
        Assert.Equal(0, account!.SoLanDangNhapSai); Assert.Null(account.KhoaDen); Assert.Equal(0, await db.Dangnhaplogs.CountAsync());
    }
    [Fact(Skip = "Historical defect fixed; see main regression suite.")] public async Task Evidence_AdminCannotListPendingReviews()
    {
        await using var db = await Db("HoanThanh");
        db.Hoadons.Add(new Hoadon { HoaDonId = 1, LichHenId = 1, KhachHangId = 1, TrangThai = "DaThanhToan" });
        db.Danhgia.Add(new Danhgium { DanhGiaId = 1, HoaDonId = 1, SoSao = 5, TrangThai = "ChoDuyet" });
        await db.SaveChangesAsync();
        var result=Assert.IsType<OkObjectResult>(await User(new ReviewsController(db), "Admin").List(null, default));
        Assert.Empty((System.Collections.IEnumerable)result.Value!);
    }
}
