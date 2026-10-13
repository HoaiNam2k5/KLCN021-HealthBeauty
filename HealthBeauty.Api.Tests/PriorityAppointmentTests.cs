using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class PriorityAppointmentTests
{
    private static readonly DateTime Day = DateTime.Today.AddDays(10);
    private static async Task<Klcn021HealthBeautyContext> Db(string status = "DaXacNhan")
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "One" }, new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Two" });
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 1, HoTen = "Staff" });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Service", ThoiLuongPhut = 60, Gia = 1000m, TrangThai = true });
        db.Lichlamviecs.Add(new Lichlamviec { LichLamViecId = 1, NhanVienId = 1, NgayLam = DateOnly.FromDateTime(Day), GioBatDau = new TimeOnly(9,0), GioKetThuc = new TimeOnly(17,0), TrangThai = "HoatDong" });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day.AddHours(9), TrangThai = status,
            Chitietlichhens = [new Chitietlichhen { ChiTietLichHenId = 1, DichVuId = 1, ThoiLuongThucTe = 60, GiaDuKien = 1000m }] });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static T User<T>(T controller, int id = 1, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static JsonElement Json(OkObjectResult result) => JsonSerializer.SerializeToElement(result.Value);

    [Fact] public async Task DetailResponsesSerializeAndPreserveIdentifiers()
    {
        await using var db = await Db();
        var appointment = Json(Assert.IsType<OkObjectResult>(await User(new AppointmentManagementController(db)).Get(1, default)));
        Assert.Equal(1, appointment.GetProperty("LichHenId").GetInt32());
        Assert.Equal("Service", appointment.GetProperty("Chitietlichhens")[0].GetProperty("DichVu").GetProperty("TenDichVu").GetString());
        var staff = Json(Assert.IsType<OkObjectResult>(await User(new StaffManagementController(db), role: "Admin").Get(1, default)));
        Assert.Equal(1, staff.GetProperty("NhanVienId").GetInt32());
        Assert.Single(staff.GetProperty("Lichlamviecs").EnumerateArray());
        Assert.False(staff.TryGetProperty("TaiKhoan", out _));
    }
    [Fact] public async Task CustomerCannotReadOtherAppointmentButAdminWithCustomerProfileCan()
    {
        await using var db = await Db();
        Assert.IsType<ForbidResult>(await User(new AppointmentManagementController(db), 2).Get(1, default));
        Assert.IsType<OkObjectResult>(await User(new AppointmentManagementController(db), 2, "Admin").Get(1, default));
    }
    [Theory]
    [InlineData("HoanThanh")][InlineData("DaHuy")][InlineData("DangThucHien")]
    public async Task TerminalOrStartedAppointmentCannotBeCancelledOrMoved(string status)
    {
        await using var db = await Db(status);
        var controller = User(new AppointmentManagementController(db));
        Assert.IsType<ConflictObjectResult>(await controller.Cancel(1, default));
        Assert.IsType<ConflictObjectResult>(await controller.Reschedule(1, new AppointmentUpdateRequest(Day.AddHours(11),1,null), default));
        Assert.IsType<ConflictObjectResult>(await User(controller, role: "Reception").Update(1, new AppointmentUpdateRequest(Day.AddHours(11),1,null), default));
        Assert.Equal(status, (await db.Lichhens.FindAsync(1))!.TrangThai);
        Assert.Equal(Day.AddHours(9), (await db.Lichhens.FindAsync(1))!.NgayGioHen);
    }
    [Theory][InlineData("ChoXacNhan")][InlineData("DaXacNhan")][InlineData("DaDen")]
    public async Task PendingArrivalCanStillBeCancelled(string status)
    {
        await using var db = await Db(status);
        Assert.IsType<NoContentResult>(await User(new AppointmentManagementController(db)).Cancel(1, default));
        Assert.Equal("DaHuy", (await db.Lichhens.FindAsync(1))!.TrangThai);
    }
    [Theory][InlineData(3,0,false)][InlineData(16,30,false)][InlineData(16,0,true)]
    public async Task BookingMustFitEntireShift(int hour,int minute,bool valid)
    {
        await using var db = await Db();
        var result = await User(new AppointmentsController(db),2).Create(new CreateAppointmentRequest(Day.AddHours(hour).AddMinutes(minute),[new AppointmentItemRequest(1,null,0)],null,null,1),default);
        if(valid) Assert.IsType<CreatedAtActionResult>(result.Result); else Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Equal(valid ? 2 : 1, await db.Lichhens.CountAsync());
    }
    [Theory][InlineData(false)][InlineData(true)]
    public async Task BothChangeRoutesRejectOutOfShift(bool put)
    {
        await using var db = await Db();
        var controller = User(new AppointmentManagementController(db), role: put ? "Reception" : "Customer");
        var request = new AppointmentUpdateRequest(Day.AddHours(16.5),1,null);
        var result = put ? await controller.Update(1,request,default) : await controller.Reschedule(1,request,default);
        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(Day.AddHours(9), (await db.Lichhens.FindAsync(1))!.NgayGioHen);
    }
    [Fact] public async Task LeaveOrMissingShiftCannotBeBooked()
    {
        await using var db = await Db();
        (await db.Lichlamviecs.SingleAsync()).TrangThai="NghiPhep"; await db.SaveChangesAsync();
        var controller = User(new AppointmentsController(db),2);
        var request = new CreateAppointmentRequest(Day.AddHours(11),[new AppointmentItemRequest(1,null,0)],null,null,1);
        Assert.IsType<BadRequestObjectResult>((await controller.Create(request,default)).Result);
        db.Lichlamviecs.RemoveRange(db.Lichlamviecs); await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>((await controller.Create(request,default)).Result);
    }
    [Fact] public async Task AvailabilityKeepsUnoccupiedShiftAndUsesServiceDuration()
    {
        await using var db = await Db();
        var slots = Json(Assert.IsType<OkObjectResult>(await new AppointmentManagementController(db).AvailableSlots(DateOnly.FromDateTime(Day),1,default,serviceId:1)));
        Assert.Equal(13,slots.GetArrayLength()); // 10:00 through 16:00, every 30 minutes.
        Assert.Equal("10:00:00", slots[0].GetProperty("GioBatDau").GetString());
        Assert.Equal("11:00:00", slots[0].GetProperty("GioKetThuc").GetString());
        Assert.Equal("16:00:00", slots[12].GetProperty("GioBatDau").GetString());
    }
    [Fact] public async Task AvailabilityAccountsForPreviousDayAndCancelledAppointments()
    {
        await using var db = await Db("DaHuy");
        var previous = new Lichhen { LichHenId=2, KhachHangId=2, NhanVienId=1, NgayGioHen=Day.AddHours(-1),TrangThai="DaXacNhan",
            Chitietlichhens=[new Chitietlichhen { ChiTietLichHenId=2,DichVuId=1,ThoiLuongThucTe=660 }] };
        db.Lichhens.Add(previous); await db.SaveChangesAsync();
        var slots=Json(Assert.IsType<OkObjectResult>(await new AppointmentManagementController(db).AvailableSlots(DateOnly.FromDateTime(Day),1,default)));
        Assert.Equal("10:00:00",slots[0].GetProperty("GioBatDau").GetString());
        previous.TrangThai="DaHuy"; await db.SaveChangesAsync();
        slots=Json(Assert.IsType<OkObjectResult>(await new AppointmentManagementController(db).AvailableSlots(DateOnly.FromDateTime(Day),1,default)));
        Assert.Equal("09:00:00",slots[0].GetProperty("GioBatDau").GetString());
    }
    [Theory][InlineData(0)][InlineData(-1)][InlineData(1441)]
    public async Task AvailabilityRejectsInvalidDuration(int duration)
    {
        await using var db = await Db();
        Assert.IsType<BadRequestObjectResult>(await new AppointmentManagementController(db).AvailableSlots(DateOnly.FromDateTime(Day),1,default,durationMinutes:duration));
    }
}
