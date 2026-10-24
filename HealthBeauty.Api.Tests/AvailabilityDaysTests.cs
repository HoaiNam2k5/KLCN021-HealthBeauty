using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AvailabilityDaysTests
{
    private static readonly DateOnly Day = DateOnly.FromDateTime(DateTime.Today.AddDays(10));
    private static JsonElement Json(IActionResult result) => JsonSerializer.SerializeToElement(
        Assert.IsType<OkObjectResult>(result).Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));

    private static async Task<Klcn021HealthBeautyContext> Db()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 1, HoTen = "One" }, new Nhanvien { NhanVienId = 2, HoTen = "Two" });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Service", ThoiLuongPhut = 60, TrangThai = true });
        db.Lichlamviecs.AddRange(
            new Lichlamviec { LichLamViecId = 1, NhanVienId = 1, NgayLam = Day, GioBatDau = new(9, 0), GioKetThuc = new(11, 0) },
            new Lichlamviec { LichLamViecId = 2, NhanVienId = 2, NgayLam = Day, GioBatDau = new(9, 0), GioKetThuc = new(10, 0) },
            new Lichlamviec { LichLamViecId = 3, NhanVienId = 2, NgayLam = Day.AddDays(2), GioBatDau = new(13, 0), GioKetThuc = new(14, 0) });
        await db.SaveChangesAsync();
        return db;
    }

    [Fact]
    public async Task RangeAgreesWithDayEndpointAndDeduplicatesStaffTimes()
    {
        await using var db = await Db();
        var controller = new AppointmentManagementController(db);
        var days = Json(await controller.AvailableDays(Day, Day.AddDays(2), default, durationMinutes: 60));
        Assert.Equal(2, days.GetArrayLength());
        Assert.Equal(Day.ToString("yyyy-MM-dd"), days[0].GetProperty("date").GetString());
        var daily = Json(await controller.AvailableSlots(Day, null, default, durationMinutes: 60));
        var expected = daily.EnumerateArray().Select(x => x.GetProperty("gioBatDau").GetString()).Distinct().Order();
        Assert.Equal(expected, days[0].GetProperty("startTimes").EnumerateArray().Select(x => x.GetString()));
        Assert.Equal(3, days[0].GetProperty("startTimes").GetArrayLength());
        Assert.Equal(new[] { "date", "startTimes" }, days[0].EnumerateObject().Select(x => x.Name));
    }

    [Fact]
    public async Task SelectedStaffDoesNotIncludeOtherStaffWorkingDays()
    {
        await using var db = await Db();
        var result = Json(await new AppointmentManagementController(db).AvailableDays(Day, Day.AddDays(2), default, staffId: 1));
        Assert.Single(result.EnumerateArray());
        Assert.Equal(Day.ToString("yyyy-MM-dd"), result[0].GetProperty("date").GetString());
    }

    [Fact]
    public async Task LeaveAndMissingShiftsDoNotProduceAvailableDays()
    {
        await using var db = await Db();
        (await db.Lichlamviecs.FindAsync(1))!.TrangThai = "NghiPhep";
        await db.SaveChangesAsync();
        Assert.Empty(Json(await new AppointmentManagementController(db).AvailableDays(Day, Day.AddDays(2), default, staffId: 1)).EnumerateArray());
    }

    [Fact]
    public async Task DurationCannotBridgeSeparateShifts()
    {
        await using var db = await Db();
        db.Lichlamviecs.Add(new Lichlamviec { NhanVienId = 1, NgayLam = Day, GioBatDau = new(12, 0), GioKetThuc = new(14, 0) });
        await db.SaveChangesAsync();
        Assert.Empty(Json(await new AppointmentManagementController(db).AvailableDays(Day, Day, default, staffId: 1, durationMinutes: 150)).EnumerateArray());
    }

    [Theory]
    [InlineData("DaXacNhan", 0)]
    [InlineData("DaHuy", 3)]
    public async Task FullyBusyDayIsAbsentButCanceledAppointmentsReleaseIt(string status, int count)
    {
        await using var db = await Db();
        db.Lichhens.Add(new Lichhen { KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day.ToDateTime(new(9, 0)), TrangThai = status,
            Chitietlichhens = [new Chitietlichhen { DichVuId = 1, ThoiLuongThucTe = 120 }] });
        await db.SaveChangesAsync();
        var days = Json(await new AppointmentManagementController(db).AvailableDays(Day, Day, default, staffId: 1, durationMinutes: 60));
        if (count == 0) Assert.Empty(days.EnumerateArray());
        else Assert.Equal(count, days[0].GetProperty("startTimes").GetArrayLength());
    }

    [Fact]
    public async Task PriorDayAppointmentBlocksOverlapButAllowsTouchingEndpoint()
    {
        await using var db = await Db();
        db.Lichhens.Add(new Lichhen { KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day.AddDays(-1).ToDateTime(new(23, 30)), TrangThai = "DaXacNhan",
            Chitietlichhens = [new Chitietlichhen { DichVuId = 1, ThoiLuongThucTe = 600 }] });
        await db.SaveChangesAsync();
        var days = Json(await new AppointmentManagementController(db).AvailableDays(Day, Day, default, staffId: 1, durationMinutes: 60));
        Assert.Equal(new[] { "09:30:00", "10:00:00" }, days[0].GetProperty("startTimes").EnumerateArray().Select(x => x.GetString()));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(0)]
    [InlineData(1441)]
    public async Task InvalidDurationIsRejected(int duration)
    {
        await using var db = await Db();
        Assert.IsType<BadRequestObjectResult>(await new AppointmentManagementController(db).AvailableDays(Day, Day, default, durationMinutes: duration));
    }

    [Fact]
    public async Task InvalidRangeAndUnknownStaffAreRejected()
    {
        await using var db = await Db();
        var controller = new AppointmentManagementController(db);
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableDays(default, Day, default));
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableDays(Day, Day.AddDays(-1), default));
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableDays(Day, Day.AddDays(61), default));
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableDays(DateOnly.MaxValue, DateOnly.MaxValue, default));
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableDays(Day, Day, default, staffId: 999));
        Assert.IsType<OkObjectResult>(await controller.AvailableDays(Day, Day.AddDays(60), default));
    }

    [Fact]
    public async Task ExpiredStartsAreNotAdvertised()
    {
        await using var db = await Db();
        db.Lichlamviecs.Add(new Lichlamviec { NhanVienId = 1, NgayLam = DateOnly.FromDateTime(DateTime.Today.AddDays(-1)), GioBatDau = new(9, 0), GioKetThuc = new(17, 0) });
        await db.SaveChangesAsync();
        Assert.Empty(Json(await new AppointmentManagementController(db).AvailableDays(DateOnly.FromDateTime(DateTime.Today.AddDays(-1)), DateOnly.FromDateTime(DateTime.Today.AddDays(-1)), default)).EnumerateArray());
    }
}
