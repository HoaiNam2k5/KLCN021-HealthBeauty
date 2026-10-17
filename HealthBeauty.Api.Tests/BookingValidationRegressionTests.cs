using System.Security.Claims;
using System.Text.Json;
using System.Reflection;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class BookingValidationRegressionTests
{
    private static readonly DateTime Day = DateTime.Today.AddDays(10);

    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "One" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Two" });
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 1, TaiKhoanId = 3, HoTen = "Employee" },
            new Nhanvien { NhanVienId = 2, TaiKhoanId = 4, HoTen = "Other" });
        db.Dichvus.AddRange(new Dichvu { DichVuId = 1, TenDichVu = "First", Gia = 100000m, ThoiLuongPhut = 60, TrangThai = true },
            new Dichvu { DichVuId = 2, TenDichVu = "Second", Gia = 200000m, ThoiLuongPhut = 30, TrangThai = true });
        db.Combodichvus.Add(new Combodichvu { ComboId = 1, TenCombo = "Package", GiaCombo = 240000m, TrangThai = true,
            Chitietcombos = [new Chitietcombo { ComboChiTietId = 1, DichVuId = 1, SoLuong = 1 }, new Chitietcombo { ComboChiTietId = 2, DichVuId = 2, SoLuong = 1 }] });
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

    [Fact]
    public async Task StandalonePriceComesFromCatalog()
    {
        await using var db = await Database();
        var result = await AsUser(new AppointmentsController(db)).Create(new(Day, [new(1, null, 1)], null, null, null), default);
        var appointment = Assert.IsType<AppointmentResponse>(Assert.IsType<CreatedAtActionResult>(result.Result).Value);
        Assert.Equal(100000m, Assert.Single(appointment.Items).ExpectedPrice);
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("inactive")]
    [InlineData("expired")]
    [InlineData("not-started")]
    [InlineData("incomplete")]
    [InlineData("unbalanced")]
    public async Task RejectsInvalidComboBooking(string scenario)
    {
        await using var db = await Database();
        var combo = await db.Combodichvus.FindAsync(1);
        if (scenario == "inactive") combo!.TrangThai = false;
        if (scenario == "expired") combo!.NgayKetThucHieuLuc = DateOnly.FromDateTime(DateTime.Today.AddDays(-1));
        if (scenario == "not-started") combo!.NgayBatDauHieuLuc = DateOnly.FromDateTime(Day.AddDays(1));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var comboId = scenario == "missing" ? 999 : 1;
        var items = new List<AppointmentItemRequest> { new(1, comboId, 1), new(2, comboId, 1) };
        if (scenario == "incomplete") items.RemoveAt(1);
        if (scenario == "unbalanced") items.Add(new(1, comboId, 1));
        var result = await AsUser(new AppointmentsController(db)).Create(new(Day, items, null, null, null), default);
        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Empty(await db.Lichhens.ToListAsync());
    }

    [Fact]
    public async Task CompleteComboUsesItsPriceAcrossRepeatedComponents()
    {
        await using var db = await Database();
        var items = new List<AppointmentItemRequest> { new(1, 1, 1), new(2, 1, 1), new(1, 1, 1), new(2, 1, 1) };
        var result = await AsUser(new AppointmentsController(db)).Create(new(Day, items, null, null, null), default);
        var appointment = Assert.IsType<AppointmentResponse>(Assert.IsType<CreatedAtActionResult>(result.Result).Value);
        Assert.Equal(480000m, appointment.Items.Sum(x => x.ExpectedPrice));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task DuplicateComboComponentsReturnBadRequest(bool update)
    {
        await using var db = await Database();
        var request = new ComboRequest("New", 1, null, null, [new(1, 1), new(1, 2)]);
        var controller = new CombosController(db);
        var result = update ? await controller.Update(1, request, default) : await controller.Create(request, default);
        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(2, await db.Chitietcombos.CountAsync());
    }

    [Theory]
    [InlineData("invalid-staff")]
    [InlineData("overlap")]
    [InlineData("self")]
    public async Task UpdatingScheduleChecksStaffAndOtherIntervals(string scenario)
    {
        await using var db = await Database();
        var date = DateOnly.FromDateTime(Day);
        db.Lichlamviecs.AddRange(new Lichlamviec { LichLamViecId = 1, NhanVienId = 1, NgayLam = date, GioBatDau = new(9, 0), GioKetThuc = new(12, 0) },
            new Lichlamviec { LichLamViecId = 2, NhanVienId = 1, NgayLam = date, GioBatDau = new(13, 0), GioKetThuc = new(17, 0) });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var request = new WorkScheduleRequest(scenario == "invalid-staff" ? 999 : 1, date,
            scenario == "overlap" ? new(14, 0) : new(9, 0), scenario == "overlap" ? new(16, 0) : new(12, 0), "HoatDong");
        var result = await new StaffManagementController(db).UpdateSchedule(1, request, default);
        if (scenario == "invalid-staff") Assert.IsType<BadRequestObjectResult>(result);
        else if (scenario == "overlap") Assert.IsType<ConflictObjectResult>(result);
        else Assert.IsType<OkObjectResult>(result);
        Assert.Equal(1, (await db.Lichlamviecs.FindAsync(1))!.NhanVienId);
        Assert.Equal(new TimeOnly(9, 0), (await db.Lichlamviecs.FindAsync(1))!.GioBatDau);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task StaffWithAnyReferencedHistoryCannotBeDeleted(bool shift)
    {
        await using var db = await Database();
        if (shift) db.Lichlamviecs.Add(new Lichlamviec { LichLamViecId = 1, NhanVienId = 1, NgayLam = DateOnly.FromDateTime(Day), GioBatDau = new(9, 0), GioKetThuc = new(17, 0) });
        else db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day, TrangThai = "DaHuy" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.IsType<ConflictObjectResult>(await new StaffManagementController(db).Delete(1, default));
        Assert.NotNull(await db.Nhanviens.FindAsync(1));
    }

    [Theory]
    [InlineData("Admin", 1, 3)]
    [InlineData("Staff", 3, 1)]
    [InlineData("Customer", 1, 2)]
    public async Task AppointmentListSeparatesManagementStaffAndCustomerScopes(string role, int accountId, int expectedCount)
    {
        await using var db = await Database();
        db.Lichhens.AddRange(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day, TrangThai = "ChoXacNhan" },
            new Lichhen { LichHenId = 2, KhachHangId = 2, NhanVienId = 2, NgayGioHen = Day, TrangThai = "ChoXacNhan" },
            new Lichhen { LichHenId = 3, KhachHangId = 1, NgayGioHen = Day, TrangThai = "ChoXacNhan" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var result = Assert.IsType<OkObjectResult>(await AsUser(new AppointmentsController(db), accountId, role).GetMine(null, null, null, null, null));
        var json = JsonSerializer.SerializeToElement(result.Value);
        Assert.Equal(expectedCount, json.GetProperty("items").GetArrayLength());
    }

    [Theory]
    [InlineData(1, true)]
    [InlineData(2, false)]
    [InlineData(null, false)]
    public async Task StaffCanReadOnlyAssignedAppointmentDetail(int? staffId, bool allowed)
    {
        await using var db = await Database();
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = staffId, NgayGioHen = Day, TrangThai = "ChoXacNhan" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var result = await AsUser(new AppointmentManagementController(db), 3, "Staff").Get(1, default);
        if (allowed) Assert.IsType<OkObjectResult>(result); else Assert.IsType<ForbidResult>(result);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task StaffSelfRoutesReturnOnlyTheirRecords(bool missingProfile)
    {
        await using var db = await Database();
        var date = DateOnly.FromDateTime(Day);
        db.Lichlamviecs.AddRange(new Lichlamviec { LichLamViecId = 1, NhanVienId = 1, NgayLam = date, GioBatDau = new(9, 0), GioKetThuc = new(12, 0) },
            new Lichlamviec { LichLamViecId = 2, NhanVienId = 2, NgayLam = date, GioBatDau = new(9, 0), GioKetThuc = new(12, 0) });
        db.Lichhens.AddRange(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1, NgayGioHen = Day, TrangThai = "ChoXacNhan" },
            new Lichhen { LichHenId = 2, KhachHangId = 1, NhanVienId = 2, NgayGioHen = Day, TrangThai = "ChoXacNhan" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var controller = AsUser(new StaffController(db, new HealthBeauty.Api.Services.PasswordService()), missingProfile ? 999 : 3, "Staff");
        var appointments = await controller.MyAppointments(default);
        var schedules = await controller.MySchedules(null, null, default);
        if (missingProfile)
        {
            Assert.IsType<ForbidResult>(appointments);
            Assert.IsType<ForbidResult>(schedules);
        }
        else
        {
            foreach (var result in new[] { appointments, schedules })
            {
                var json = JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(result).Value);
                Assert.Equal(1, json.GetArrayLength());
                Assert.Equal(1, json[0].GetProperty("NhanVienId").GetInt32());
            }
        }
    }

    [Fact]
    public void ReceptionCanListStaffAndStaffSelfReadsDoNotGrantManagementWrites()
    {
        Assert.Contains("Reception", typeof(StaffController).GetMethod("List")!.GetCustomAttribute<AuthorizeAttribute>()!.Roles!.Split(','));
        foreach (var name in new[] { "MyAppointments", "MySchedules" })
            Assert.Equal("Staff", typeof(StaffController).GetMethod(name)!.GetCustomAttribute<AuthorizeAttribute>()!.Roles);
        foreach (var name in new[] { "Create", "Update", "CreateSchedule" })
            Assert.DoesNotContain("Staff", typeof(StaffController).GetMethod(name)!.GetCustomAttribute<AuthorizeAttribute>()!.Roles!.Split(','));
        Assert.DoesNotContain("Staff", typeof(StaffManagementController).GetCustomAttribute<AuthorizeAttribute>()!.Roles!.Split(','));
    }
}
