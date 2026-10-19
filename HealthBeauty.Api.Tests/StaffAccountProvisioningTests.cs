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

public sealed class StaffAccountProvisioningTests
{
    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Vaitros.AddRange(new Vaitro { VaiTroId = 1, TenVaiTro = "Admin" },
            new Vaitro { VaiTroId = 4, TenVaiTro = "Staff" }, new Vaitro { VaiTroId = 5, TenVaiTro = "Customer" });
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, VaiTroId = 1, Email = "admin@example.com", MatKhauHash = "unused", TrangThai = true });
        await db.SaveChangesAsync();
        return db;
    }

    private static T User<T>(T controller, int id = 1, string role = "Admin") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString()),
                new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static AdministrationController Admin(Klcn021HealthBeautyContext db) => User(new AdministrationController(db, new PasswordService()));
    private static StaffController Staff(Klcn021HealthBeautyContext db) => User(new StaffController(db, new PasswordService()));
    private static Taikhoan Account(int id, string email, int role = 4) => new() {
        TaiKhoanId = id, VaiTroId = role, Email = email, TenTaiKhoan = "Employee login", MatKhauHash = "unused", TrangThai = true };

    [Fact]
    public async Task CreatingEmployeeCreatesNormalizedHashedLinkedStaffLoginWithoutLeakingSecrets()
    {
        await using var db = await Database();
        var hireDate = new DateOnly(2026, 10, 1);
        var result = Assert.IsType<CreatedResult>(await Staff(db).Create(
            new CreateStaffRequest(" Employee ", " Therapist ", " Facial ", "0901234567", hireDate, " EMPLOYEE@Example.COM ", "password-123"), default));
        var employee = await db.Nhanviens.SingleAsync();
        var account = await db.Taikhoans.SingleAsync(x => x.Email == "employee@example.com");
        Assert.Equal(account.TaiKhoanId, employee.TaiKhoanId);
        Assert.Equal(4, account.VaiTroId);
        Assert.True(account.TrangThai);
        Assert.Equal("Employee", employee.HoTen);
        Assert.Equal("Therapist", employee.ChucVu);
        Assert.Equal("Facial", employee.ChuyenMon);
        Assert.Equal(hireDate, employee.NgayVaoLam);
        Assert.True(new PasswordService().Verify("password-123", account.MatKhauHash));
        var json = JsonSerializer.Serialize(result.Value);
        Assert.DoesNotContain("password-123", json);
        Assert.DoesNotContain(account.MatKhauHash, json);
        Assert.DoesNotContain("MatKhauHash", json);
    }

    [Theory]
    [InlineData("bad-email", "password-123", "Employee")]
    [InlineData("employee@example.com", "short", "Employee")]
    [InlineData("employee@example.com", "password-123", " ")]
    public async Task InvalidEmployeeCredentialsCannotLeavePartialRecords(string email, string password, string name)
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Staff(db).Create(new CreateStaffRequest(name, null, null, null, null, email, password), default));
        Assert.Single(await db.Taikhoans.ToListAsync());
        Assert.Empty(await db.Nhanviens.ToListAsync());
        Assert.Empty(await db.Auditlogs.ToListAsync());
    }

    [Fact]
    public async Task DuplicateEmployeeEmailDoesNotCreateEmployeeOrAccount()
    {
        await using var db = await Database();
        Assert.IsType<ConflictObjectResult>(await Staff(db).Create(new CreateStaffRequest("Employee", null, null, null, null, " ADMIN@EXAMPLE.COM ", "password-123"), default));
        Assert.Single(await db.Taikhoans.ToListAsync());
        Assert.Empty(await db.Nhanviens.ToListAsync());
    }

    [Fact]
    public async Task EmployeeCreationRejectsMissingStaffRoleWithoutPartialRecords()
    {
        await using var db = await Database();
        db.Vaitros.Remove((await db.Vaitros.FindAsync(4))!);
        await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>(await Staff(db).Create(new CreateStaffRequest("Employee", null, null, null, null, "employee@example.com", "password-123"), default));
        Assert.Single(await db.Taikhoans.ToListAsync());
        Assert.Empty(await db.Nhanviens.ToListAsync());
    }

    [Fact]
    public async Task ManagementListExposesAccountLinkWhileCustomerListHidesIt()
    {
        await using var db = await Database();
        db.Taikhoans.Add(Account(2, "staff@example.com"));
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 11, TaiKhoanId = 2, HoTen = "Employee" });
        await db.SaveChangesAsync();
        var management = JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await Staff(db).List(default)).Value);
        Assert.Equal(2, management[0].GetProperty("TaiKhoanId").GetInt32());
        var customer = JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await User(new StaffController(db, new PasswordService()), 3, "Customer").List(default)).Value);
        Assert.Equal(JsonValueKind.Null, customer[0].GetProperty("TaiKhoanId").ValueKind);
        Assert.False(management[0].TryGetProperty("TaiKhoan", out _));
    }

    [Fact]
    public async Task AdminCanCreateLoginForExistingEmployeeWithoutDuplicatingOrReplacingBusinessData()
    {
        await using var db = await Database();
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 10, HoTen = "Existing therapist", ChuyenMon = "Massage" });
        await db.SaveChangesAsync();
        Assert.IsType<CreatedResult>(await Admin(db).CreateAccount(new CreateAccountRequest("existing@example.com", "password-123", "Login display", null, 4, 10), default));
        var account = await db.Taikhoans.SingleAsync(x => x.Email == "existing@example.com");
        var employee = await db.Nhanviens.SingleAsync();
        Assert.Equal(10, employee.NhanVienId);
        Assert.Equal(account.TaiKhoanId, employee.TaiKhoanId);
        Assert.Equal("Existing therapist", employee.HoTen);
        Assert.Equal("Massage", employee.ChuyenMon);
    }

    [Fact]
    public async Task ReplacingEmptyAutoCreatedProfileExposesOnlyTargetEmployeesAppointmentsAndRevokesRefresh()
    {
        await using var db = await Database();
        db.Taikhoans.Add(Account(2, "staff@example.com"));
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 10, TaiKhoanId = 2, HoTen = "Empty profile" },
            new Nhanvien { NhanVienId = 11, HoTen = "Existing employee" }, new Nhanvien { NhanVienId = 12, HoTen = "Other employee" });
        db.Khachhangs.Add(new Khachhang { KhachHangId = 20, TaiKhoanId = 20, HoTen = "Customer" });
        db.Lichhens.AddRange(new Lichhen { LichHenId = 31, KhachHangId = 20, NhanVienId = 11, NgayGioHen = DateTime.Today, TrangThai = "DaXacNhan" },
            new Lichhen { LichHenId = 32, KhachHangId = 20, NhanVienId = 12, NgayGioHen = DateTime.Today, TrangThai = "DaXacNhan" });
        db.Lichlamviecs.Add(new Lichlamviec { LichLamViecId = 40, NhanVienId = 11, NgayLam = DateOnly.FromDateTime(DateTime.Today), GioBatDau = new TimeOnly(8, 0), GioKetThuc = new TimeOnly(17, 0) });
        db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = 2, TokenHash = "old-refresh", ExpiresAt = DateTime.UtcNow.AddDays(1) });
        await db.SaveChangesAsync();
        Assert.IsType<OkObjectResult>(await Admin(db).AssignAccountRole(2, new AssignAccountRoleRequest(4, 11), default));
        Assert.Equal(2, (await db.Nhanviens.FindAsync(11))!.TaiKhoanId);
        Assert.False(await db.Nhanviens.AnyAsync(x => x.NhanVienId == 10 && x.TaiKhoanId == 2));
        Assert.Equal(2, await db.Lichhens.CountAsync());
        Assert.Equal(11, (await db.Lichlamviecs.SingleAsync()).NhanVienId);
        Assert.NotNull((await db.Refreshtokens.SingleAsync()).RevokedAt);
        Assert.True(await db.Auditlogs.AnyAsync(x => x.ActionName == "AccountStaffLinked"));
        var list = Assert.IsType<OkObjectResult>(await User(new AppointmentsController(db), 2, "Staff").GetMine(null, null, null, null, null, cancellationToken: default));
        var data = JsonSerializer.SerializeToElement(list.Value);
        Assert.Equal(1, data.GetProperty("totalCount").GetInt32());
        Assert.Equal(31, data.GetProperty("items")[0].GetProperty("Id").GetInt32());
        Assert.IsType<OkObjectResult>(await User(new AppointmentManagementController(db), 2, "Staff").Get(31, default));
        Assert.IsType<ForbidResult>(await User(new AppointmentManagementController(db), 2, "Staff").Get(32, default));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task CannotReplaceProfileWithAppointmentOrScheduleHistory(bool schedule)
    {
        await using var db = await Database();
        db.Taikhoans.Add(Account(2, "staff@example.com"));
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 10, TaiKhoanId = 2, HoTen = "Existing linked" }, new Nhanvien { NhanVienId = 11, HoTen = "Target" });
        if (schedule) db.Lichlamviecs.Add(new Lichlamviec { NhanVienId = 10, NgayLam = DateOnly.FromDateTime(DateTime.Today), GioBatDau = new TimeOnly(8, 0), GioKetThuc = new TimeOnly(17, 0) });
        else db.Lichhens.Add(new Lichhen { KhachHangId = 20, NhanVienId = 10, NgayGioHen = DateTime.Today, TrangThai = "DaHuy" });
        await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Admin(db).AssignAccountRole(2, new AssignAccountRoleRequest(4, 11), default));
        Assert.Equal(2, (await db.Nhanviens.FindAsync(10))!.TaiKhoanId);
        Assert.Null((await db.Nhanviens.FindAsync(11))!.TaiKhoanId);
        Assert.Equal(schedule ? 1 : 0, await db.Lichlamviecs.CountAsync());
        Assert.Equal(schedule ? 0 : 1, await db.Lichhens.CountAsync());
        Assert.Empty(await db.Auditlogs.ToListAsync());
    }

    [Fact]
    public async Task CannotStealEmployeeAlreadyLinkedToAnotherAccount()
    {
        await using var db = await Database();
        db.Taikhoans.AddRange(Account(2, "staff@example.com"), Account(3, "other@example.com"));
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 11, TaiKhoanId = 3, HoTen = "Other employee" });
        await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Admin(db).AssignAccountRole(2, new AssignAccountRoleRequest(4, 11), default));
        Assert.Equal(3, (await db.Nhanviens.SingleAsync()).TaiKhoanId);
        Assert.Empty(await db.Auditlogs.ToListAsync());
        Assert.IsType<ConflictObjectResult>(await Admin(db).CreateAccount(new CreateAccountRequest("new@example.com", "password-123", "New", null, 4, 11), default));
        Assert.Equal(3, await db.Taikhoans.CountAsync());
    }

    [Fact]
    public async Task ExistingEmployeeLinkIsRejectedForCustomerRoleWithoutWrites()
    {
        await using var db = await Database();
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 11, HoTen = "Employee" });
        await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>(await Admin(db).CreateAccount(new CreateAccountRequest("customer@example.com", "password-123", "Customer", null, 5, 11), default));
        Assert.Single(await db.Taikhoans.ToListAsync());
        Assert.Null((await db.Nhanviens.SingleAsync()).TaiKhoanId);
        Assert.Empty(await db.Khachhangs.ToListAsync());
    }

    [Fact]
    public void LinkingEmployeeThroughRoleAssignmentRequiresAccountWritePermission()
    {
        var admin = User(new ControllerStub()).User;
        Assert.Equal("ACCOUNT.WRITE", DatabasePermissionFilter.RequiredPermission("Administration", "AssignAccountRole", admin));
    }

    private sealed class ControllerStub : ControllerBase { }
}
