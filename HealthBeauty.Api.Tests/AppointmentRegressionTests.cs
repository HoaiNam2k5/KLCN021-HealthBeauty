using System.Security.Claims;
using System.Reflection;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AppointmentRegressionTests
{
    private static readonly DateTime Day = DateTime.Today.AddDays(10);

    private static async Task<Klcn021HealthBeautyContext> Database(int? storedDuration = 60, string status = "DaXacNhan", DateTime? start = null)
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Customer One" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Customer Two" });
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 1, HoTen = "Staff One" }, new Nhanvien { NhanVienId = 2, HoTen = "Staff Two" });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Service", Gia = 100000m, ThoiLuongPhut = 60, TrangThai = true });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1,
            NgayGioHen = start ?? Day.AddHours(9), TrangThai = status,
            Chitietlichhens = [new Chitietlichhen { ChiTietLichHenId = 1, DichVuId = 1, ThoiLuongThucTe = storedDuration, GiaDuKien = 100000m }] });
        db.Lichlamviecs.AddRange(Enumerable.Range(1, 2).Select(id => new Lichlamviec {
            LichLamViecId = id, NhanVienId = id, NgayLam = DateOnly.FromDateTime(Day),
            GioBatDau = new TimeOnly(7, 0), GioKetThuc = new TimeOnly(18, 0), TrangThai = "HoatDong" }));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        return db;
    }

    private static T AsUser<T>(T controller, int accountId = 1, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }

    [Theory]
    [InlineData(9, 30, 1, 2, true)] // Same customer, different staff.
    [InlineData(9, 30, 2, 1, true)] // Different customer, same staff.
    [InlineData(8, 30, 1, 2, true)] // Starts before an existing appointment.
    [InlineData(9, 0, 1, 1, true)]
    [InlineData(10, 0, 1, 1, false)] // Touching endpoints do not overlap.
    [InlineData(8, 0, 1, 1, false)]
    [InlineData(9, 30, 2, 2, false)] // Unrelated customer and staff.
    public async Task CreateChecksWholeInterval(int hour, int minute, int accountId, int staffId, bool conflict)
    {
        await using var db = await Database();
        var result = await AsUser(new AppointmentsController(db), accountId).Create(
            new CreateAppointmentRequest(Day.AddHours(hour).AddMinutes(minute), [new AppointmentItemRequest(1, null, 0)], null, null, staffId), default);
        if (conflict) Assert.IsType<ConflictObjectResult>(result.Result);
        else Assert.IsType<CreatedAtActionResult>(result.Result);
    }

    [Fact]
    public async Task CreateIgnoresCancelledAppointments()
    {
        await using var db = await Database(status: "DaHuy");
        var result = await AsUser(new AppointmentsController(db)).Create(new CreateAppointmentRequest(Day.AddHours(9.5), [new AppointmentItemRequest(1, null, 0)], null, null, 1), default);
        Assert.IsType<CreatedAtActionResult>(result.Result);
    }

    [Fact]
    public async Task CreateDetectsAppointmentFromPreviousDay()
    {
        await using var db = await Database(start: Day.AddMinutes(-30));
        var result = await AsUser(new AppointmentsController(db)).Create(new CreateAppointmentRequest(Day.AddMinutes(15), [new AppointmentItemRequest(1, null, 0)], null, null, 1), default);
        Assert.IsType<ConflictObjectResult>(result.Result);
    }

    [Theory]
    [InlineData(null)]
    [InlineData(0)]
    [InlineData(-10)]
    public async Task CreateFallsBackToServiceDuration(int? storedDuration)
    {
        await using var db = await Database(storedDuration);
        var result = await AsUser(new AppointmentsController(db)).Create(new CreateAppointmentRequest(Day.AddHours(9.5), [new AppointmentItemRequest(1, null, 0)], null, null, 1), default);
        Assert.IsType<ConflictObjectResult>(result.Result);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task ChangingAppointmentRejectsConflictAndLeavesOriginalTime(bool usePut)
    {
        await using var db = await Database();
        db.Lichhens.Add(new Lichhen { LichHenId = 2, KhachHangId = 1, NhanVienId = 2, NgayGioHen = Day.AddHours(12), TrangThai = "ChoXacNhan",
            Chitietlichhens = [new Chitietlichhen { ChiTietLichHenId = 2, DichVuId = 1, ThoiLuongThucTe = 60 }] });
        await db.SaveChangesAsync();
        var controller = AsUser(new AppointmentManagementController(db), role: usePut ? "Reception" : "Customer");
        var request = new AppointmentUpdateRequest(Day.AddHours(9.5), 2, null);
        var result = usePut ? await controller.Update(2, request, default) : await controller.Reschedule(2, request, default);
        Assert.IsType<ConflictObjectResult>(result);
        Assert.Equal(Day.AddHours(12), (await db.Lichhens.FindAsync(2))!.NgayGioHen);
    }

    [Fact]
    public async Task RescheduleExcludesOwnAppointment()
    {
        await using var db = await Database();
        var result = await AsUser(new AppointmentManagementController(db)).Reschedule(1, new AppointmentUpdateRequest(Day.AddHours(9.5), 1, null), default);
        var response = Assert.IsType<OkObjectResult>(result);
        var json = System.Text.Json.JsonSerializer.Serialize(response.Value);
        Assert.Contains("LichHenId", json);
    }

    [Fact]
    public async Task ResponseHasDurationAndKeepsDecimalPrice()
    {
        await using var db = await Database(45);
        var result = Assert.IsType<OkObjectResult>(await AsUser(new AppointmentsController(db)).GetMine(null, null, null, null, null));
        var items = result.Value!.GetType().GetProperty("items")!.GetValue(result.Value) as IEnumerable<AppointmentResponse>;
        var item = Assert.Single(Assert.Single(items!).Items);
        var property = typeof(AppointmentItemResponse).GetProperty("DurationMinutes");
        Assert.NotNull(property);
        Assert.Equal(45, property!.GetValue(item));
        Assert.Equal(typeof(decimal), typeof(AppointmentItemResponse).GetProperty("ExpectedPrice")!.PropertyType);
    }

    [Fact]
    public void CustomerCanListStaffWhileWritesRequireManagementRole()
    {
        var method = typeof(StaffController).GetMethod("List")!;
        var roles = method.GetCustomAttributes<AuthorizeAttribute>().Concat(typeof(StaffController).GetCustomAttributes<AuthorizeAttribute>()).ToList();
        var anonymous = method.IsDefined(typeof(AllowAnonymousAttribute));
        Assert.True(anonymous || roles.All(a => string.IsNullOrEmpty(a.Roles) || a.Roles.Split(',').Contains("Customer")));
        foreach (var name in new[] { "Create", "Update", "Schedules", "CreateSchedule" })
        {
            var attributes = typeof(StaffController).GetMethod(name)!.GetCustomAttributes<AuthorizeAttribute>()
                .Concat(typeof(StaffController).GetCustomAttributes<AuthorizeAttribute>()).ToList();
            Assert.Contains(attributes, a => a.Roles == "Admin,Manager,Reception");
            Assert.DoesNotContain(attributes, a => a.Roles?.Split(',').Contains("Customer") == true || a.Roles?.Split(',').Contains("Staff") == true);
        }
    }
}
