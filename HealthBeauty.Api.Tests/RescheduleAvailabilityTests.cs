using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class RescheduleAvailabilityTests
{
    private static readonly DateTime Day = DateTime.Today.AddDays(10).AddHours(10);
    private static async Task<Klcn021HealthBeautyContext> Db()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 11, HoTen = "Owner" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 22, HoTen = "Other" });
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 1, HoTen = "Staff" });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Service", ThoiLuongPhut = 60, TrangThai = true });
        db.Lichlamviecs.Add(new Lichlamviec { NhanVienId = 1, NgayLam = DateOnly.FromDateTime(Day), GioBatDau = new TimeOnly(9, 0), GioKetThuc = new TimeOnly(13, 0), TrangThai = "LamViec" });
        db.Lichhens.AddRange(new Lichhen { LichHenId = 7, KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day, TrangThai = "DaXacNhan", Chitietlichhens = [new() { DichVuId = 1 }] },
            new Lichhen { LichHenId = 8, KhachHangId = 2, NhanVienId = 1, NgayGioHen = Day.AddHours(1), TrangThai = "DaXacNhan", Chitietlichhens = [new() { DichVuId = 1 }] });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        return db;
    }
    private static AppointmentManagementController Controller(Klcn021HealthBeautyContext db, int? account = 11, string role = "Customer") => new(db)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = account.HasValue
            ? new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, account.Value.ToString()), new Claim(ClaimTypes.Role, role)], "Test"))
            : new ClaimsPrincipal(new ClaimsIdentity()) } }
    };
    private static List<string?> Starts(OkObjectResult result) => JsonSerializer.SerializeToElement(result.Value,
        new JsonSerializerOptions(JsonSerializerDefaults.Web)).EnumerateArray().Select(x => x.GetProperty("gioBatDau").GetString()).ToList();

    [Fact]
    public async Task OwnerCanExcludeOnlyOwnOldBookingWhileOtherCustomersStillBlockSlots()
    {
        await using var db = await Db(); var controller = Controller(db);
        var original = Starts(Assert.IsType<OkObjectResult>(await controller.AvailableSlots(DateOnly.FromDateTime(Day), 1, default, durationMinutes: 60)));
        Assert.DoesNotContain("10:00:00", original);
        var excluding = Starts(Assert.IsType<OkObjectResult>(await controller.AvailableSlots(DateOnly.FromDateTime(Day), 1, default, durationMinutes: 60, excludeAppointmentId: 7)));
        Assert.Contains("10:00:00", excluding);
        Assert.DoesNotContain("11:00:00", excluding);
        Assert.Equal(Day, (await db.Lichhens.SingleAsync(x => x.LichHenId == 7)).NgayGioHen);
    }

    [Fact]
    public async Task AnonymousAndAnotherCustomerCannotExcludeSomeoneElsesBooking()
    {
        await using var db = await Db();
        Assert.IsType<UnauthorizedResult>(await Controller(db, null).AvailableSlots(DateOnly.FromDateTime(Day), 1, default, excludeAppointmentId: 7));
        Assert.IsType<NotFoundResult>(await Controller(db, 22).AvailableSlots(DateOnly.FromDateTime(Day), 1, default, excludeAppointmentId: 7));
    }

    [Theory]
    [InlineData("DaDen")]
    [InlineData("DangThucHien")]
    [InlineData("HoanThanh")]
    [InlineData("DaHuy")]
    public async Task StartedAndTerminalBookingsCannotBeExcludedForRescheduling(string status)
    {
        await using var db = await Db(); var appointment = await db.Lichhens.SingleAsync(x => x.LichHenId == 7);
        appointment.TrangThai = status; await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Controller(db).AvailableSlots(DateOnly.FromDateTime(Day), 1, default, excludeAppointmentId: 7));
    }

    [Fact]
    public async Task ClerkExclusionRequiresAnActiveReadGrant()
    {
        await using var db = await Db();
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 99, VaiTroId = 3, TrangThai = true, Email = "clerk@test.invalid", MatKhauHash = "unused" });
        db.Quyens.Add(new Quyen { QuyenId = 1, MaQuyen = "APPOINTMENT.READ", TenQuyen = "Read", NhomQuyen = "APPOINTMENT", TrangThai = true });
        await db.SaveChangesAsync();
        var controller = Controller(db, 99, "Reception");
        Assert.IsType<ForbidResult>(await controller.AvailableSlots(DateOnly.FromDateTime(Day), 1, default, excludeAppointmentId: 7));
        db.VaitroQuyens.Add(new VaitroQuyen { VaiTroId = 3, QuyenId = 1, DuocCap = true }); await db.SaveChangesAsync();
        Assert.IsType<OkObjectResult>(await controller.AvailableSlots(DateOnly.FromDateTime(Day), 1, default, excludeAppointmentId: 7));
    }
}
