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

public sealed class StaffBookingEligibilityTests
{
    private static readonly DateTime Day = DateTime.Today.AddDays(12);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private static Klcn021HealthBeautyContext Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var therapist = new Vaitro { VaiTroId = 1, TenVaiTro = "Staff" };
        var reception = new Vaitro { VaiTroId = 2, TenVaiTro = "Reception" };
        var manager = new Vaitro { VaiTroId = 3, TenVaiTro = "Manager" };
        db.Vaitros.AddRange(therapist, reception, manager);
        AddLinked(1, therapist, true, "Reception"); // Account role overrides a stale descriptive position.
        AddLinked(2, reception, true, "Staff");
        AddLinked(3, therapist, false, "KTV");
        AddLinked(4, manager, true, "KTV");
        db.Nhanviens.AddRange(
            new Nhanvien { NhanVienId = 5, HoTen = "Legacy therapist", ChucVu = " KTV " },
            new Nhanvien { NhanVienId = 6, HoTen = "Legacy reception", ChucVu = "Reception" },
            new Nhanvien { NhanVienId = 7, HoTen = "Unknown legacy" },
            new Nhanvien { NhanVienId = 8, HoTen = "Vietnamese title", ChucVu = "K\u1ef9 thu\u1eadt vi\u00ean" });
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 100, HoTen = "Customer" });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Service", Gia = 100, ThoiLuongPhut = 30, TrangThai = true });
        for (var id = 1; id <= 8; id++) db.Lichlamviecs.Add(new Lichlamviec {
            LichLamViecId = id, NhanVienId = id, NgayLam = DateOnly.FromDateTime(Day),
            GioBatDau = new TimeOnly(9, 0), GioKetThuc = new TimeOnly(12, 0), TrangThai = "HoatDong" });
        db.SaveChanges();
        db.ChangeTracker.Clear();
        return db;

        void AddLinked(int id, Vaitro role, bool active, string position)
        {
            var account = new Taikhoan { TaiKhoanId = id, VaiTro = role, VaiTroId = role.VaiTroId,
                Email = $"staff{id}@example.com", MatKhauHash = "unused", TrangThai = active };
            db.Taikhoans.Add(account);
            db.Nhanviens.Add(new Nhanvien { NhanVienId = id, TaiKhoanId = id, TaiKhoan = account,
                HoTen = $"Employee {id}", ChucVu = position, AvatarUrl = $"https://example.com/{id}.png" });
        }
    }

    private static T User<T>(T controller, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([
                new Claim(ClaimTypes.NameIdentifier, "100"), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }

    private static JsonElement ResultJson(object? value) => JsonSerializer.SerializeToElement(value, Json);

    [Fact]
    public async Task LegacyTherapistTitleRemainsBookableWithoutAnAccount()
    {
        await using var db = Database();
        db.Nhanviens.Add(new Nhanvien { NhanVienId = 9, HoTen = "Legacy therapist title", ChucVu = " therapist " });
        await db.SaveChangesAsync();
        Assert.True(await TechnicianEligibility.ExistsAsync(db, 9, default));
        db.ChangeTracker.Clear();
        var rows = ResultJson(Assert.IsType<OkObjectResult>(await User(new StaffController(db, new PasswordService())).List(default)).Value);
        Assert.Contains(rows.EnumerateArray(), x => x.GetProperty("nhanVienId").GetInt32() == 9);
    }

    [Fact]
    public async Task CustomerListUsesActiveAccountRoleAndExplicitLegacyTechnicians()
    {
        await using var db = Database();
        var controller = User(new StaffController(db, new PasswordService()));
        var rows = ResultJson(Assert.IsType<OkObjectResult>(await controller.List(default)).Value);
        Assert.Equal(new[] { 1, 5, 8 }, rows.EnumerateArray().Select(x => x.GetProperty("nhanVienId").GetInt32()).Order().ToArray());
        var linked = rows.EnumerateArray().Single(x => x.GetProperty("nhanVienId").GetInt32() == 1);
        Assert.Equal("Staff", linked.GetProperty("role").GetString());
        Assert.True(linked.GetProperty("isActive").GetBoolean());
        Assert.Equal("https://example.com/1.png", linked.GetProperty("avatarUrl").GetString());
        Assert.All(rows.EnumerateArray(), x => Assert.Equal(JsonValueKind.Null, x.GetProperty("taiKhoanId").ValueKind));
        Assert.DoesNotContain("matKhauHash", rows.ToString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ManagementListPreservesOtherRolesAndInactiveEmployees()
    {
        await using var db = Database();
        var rows = ResultJson(Assert.IsType<OkObjectResult>(await User(new StaffController(db, new PasswordService()), "Reception").List(default)).Value);
        Assert.Equal(8, rows.GetArrayLength());
        var receptionist = rows.EnumerateArray().Single(x => x.GetProperty("nhanVienId").GetInt32() == 2);
        Assert.Equal("Reception", receptionist.GetProperty("role").GetString());
        Assert.Equal(2, receptionist.GetProperty("taiKhoanId").GetInt32());
        Assert.False(rows.EnumerateArray().Single(x => x.GetProperty("nhanVienId").GetInt32() == 3).GetProperty("isActive").GetBoolean());
    }

    [Fact]
    public async Task AvatarPersistsAcrossDetailListPreserveReplaceAndClear()
    {
        await using var db = Database();
        var staff = User(new StaffController(db, new PasswordService()), "Reception");
        Assert.IsType<OkObjectResult>(await staff.Update(1, new("Changed", "KTV", "Facial", null, null), default));
        Assert.Equal("https://example.com/1.png", (await db.Nhanviens.FindAsync(1))!.AvatarUrl);
        Assert.IsType<OkObjectResult>(await staff.Update(1, new("Changed", "KTV", "Facial", null, null, " https://example.com/new.png "), default));
        db.ChangeTracker.Clear();
        var detail = ResultJson(Assert.IsType<OkObjectResult>(await new StaffManagementController(db).Get(1, default)).Value);
        Assert.Equal("https://example.com/new.png", detail.GetProperty("avatarUrl").GetString());
        Assert.Equal("Staff", detail.GetProperty("role").GetString());
        Assert.IsType<OkObjectResult>(await staff.Update(1, new("Changed", "KTV", "Facial", null, null, ""), default));
        Assert.Null((await db.Nhanviens.FindAsync(1))!.AvatarUrl);
        var property = db.Model.FindEntityType(typeof(Nhanvien))!.FindProperty(nameof(Nhanvien.AvatarUrl))!;
        Assert.Equal(2048, property.GetMaxLength());
        Assert.True(property.IsNullable);
    }

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("data:image/png;base64,test")]
    [InlineData("/relative/photo.png")]
    [InlineData("https://user:password@example.com/photo.png")]
    [InlineData("https://example.com/photo\r\n.png")]
    public async Task InvalidAvatarDoesNotMutateEmployee(string url)
    {
        await using var db = Database();
        var staff = User(new StaffController(db, new PasswordService()), "Reception");
        Assert.IsType<BadRequestObjectResult>(await staff.Update(1, new("Must not change", null, null, null, null, url), default));
        Assert.Equal("Employee 1", (await db.Nhanviens.FindAsync(1))!.HoTen);
        Assert.Equal("https://example.com/1.png", (await db.Nhanviens.FindAsync(1))!.AvatarUrl);
        Assert.IsType<BadRequestObjectResult>(await staff.Create(new("New", null, null, null, null, "new@example.com", "password-123", url), default));
        Assert.Equal(8, await db.Nhanviens.CountAsync());
    }

    [Fact]
    public async Task StaffCreationPersistsAvatar()
    {
        await using var db = Database();
        var result = Assert.IsType<CreatedResult>(await User(new StaffController(db, new PasswordService()), "Reception").Create(
            new("New", "KTV", "Facial", null, null, "new@example.com", "password-123", "https://example.com/new.png"), default));
        var body = ResultJson(result.Value);
        var id = body.GetProperty("nhanVienId").GetInt32();
        Assert.Equal("https://example.com/new.png", body.GetProperty("avatarUrl").GetString());
        db.ChangeTracker.Clear();
        Assert.Equal("https://example.com/new.png", (await db.Nhanviens.FindAsync(id))!.AvatarUrl);
    }

    [Theory]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(6)]
    [InlineData(7)]
    public async Task NonTechnicianCannotBeAssignedOnCreateUpdateOrReschedule(int id)
    {
        await using var db = Database();
        var create = await User(new AppointmentsController(db)).Create(
            new(Day.AddHours(9), [new AppointmentItemRequest(1, null, 0)], null, null, id), default);
        Assert.IsType<BadRequestObjectResult>(create.Result);
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1,
            NgayGioHen = Day.AddHours(9), TrangThai = "DaXacNhan" });
        await db.SaveChangesAsync();
        var update = new AppointmentUpdateRequest(Day.AddHours(10), id, null);
        Assert.IsType<BadRequestObjectResult>(await User(new AppointmentManagementController(db), "Reception").Update(1, update, default));
        Assert.IsType<BadRequestObjectResult>(await User(new AppointmentManagementController(db)).Reschedule(1, update, default));
        Assert.Equal(1, (await db.Lichhens.FindAsync(1))!.NhanVienId);
        Assert.Single(db.Lichhens);
    }

    [Fact]
    public async Task AvailabilityExcludesReceptionAndInactiveShiftsEvenWithoutSpecificStaff()
    {
        await using var db = Database();
        var controller = new AppointmentManagementController(db);
        var date = DateOnly.FromDateTime(Day);
        var rows = ResultJson(Assert.IsType<OkObjectResult>(await controller.AvailableSlots(date, null, default)).Value);
        Assert.Equal(new[] { 1, 5, 8 }, rows.EnumerateArray().Select(x => x.GetProperty("nhanVienId").GetInt32()).Distinct().Order().ToArray());
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableSlots(date, 2, default));
        Assert.IsType<BadRequestObjectResult>(await controller.AvailableDays(date, date, default, 2));
        Assert.IsType<OkObjectResult>(await controller.AvailableDays(date, date, default, 1));
    }

    [Fact]
    public void EligibilityTranslatesForSqlServerWithoutConnecting()
    {
        using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseSqlServer("Server=localhost;Database=TranslationOnly;Integrated Security=true;TrustServerCertificate=true").Options);
        var sql = TechnicianEligibility.Query(db).Select(x => x.NhanVienId).ToQueryString();
        Assert.Contains("Staff", sql);
        Assert.Contains("UPPER", sql);
        Assert.Contains("TrangThai", sql);
        var eligible = TechnicianEligibility.Query(db).Select(x => x.NhanVienId);
        var shiftSql = db.Lichlamviecs.Where(x => eligible.Contains(x.NhanVienId)).ToQueryString();
        Assert.Contains("Staff", shiftSql);
        Assert.Contains("LICHLAMVIEC", shiftSql);
    }
}
