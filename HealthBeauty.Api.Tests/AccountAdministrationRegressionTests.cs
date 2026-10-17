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

namespace HealthBeauty.Api.Tests;

public sealed class AccountAdministrationRegressionTests
{
    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var names = new[] { "Admin", "Manager", "Reception", "Staff", "Customer", "Unsupported" };
        for (var i = 0; i < names.Length; i++) db.Vaitros.Add(new Vaitro { VaiTroId = i + 1, TenVaiTro = names[i] });
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, VaiTroId = 1, Email = "admin@example.com", TenTaiKhoan = "Admin", MatKhauHash = "unused", TrangThai = true });
        await db.SaveChangesAsync();
        return db;
    }

    private static T AsUser<T>(T controller, int accountId = 1, string role = "Admin") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static AdministrationController Admin(Klcn021HealthBeautyContext db, int accountId = 1, string role = "Admin") => AsUser(new AdministrationController(db, new PasswordService()), accountId, role);
    private static AuthController Auth(Klcn021HealthBeautyContext db, int accountId) => AsUser(new AuthController(db, new PasswordService(), new TokenService(new ConfigurationBuilder().Build()), new ConfigurationBuilder().Build()), accountId, "Reception");

    [Theory]
    [InlineData(1, false)] [InlineData(2, false)] [InlineData(3, false)] [InlineData(4, false)] [InlineData(5, true)]
    public async Task CreateHashesPasswordNormalizesFieldsAndCreatesCorrectLinkedProfile(int roleId, bool customer)
    {
        await using var db = await Database();
        var result = Assert.IsType<CreatedResult>(await Admin(db).CreateAccount(new CreateAccountRequest(" New@Example.com ", "password-123", " New User ", "0901234567", roleId), default));
        var response = Assert.IsType<AdminAccountResponse>(result.Value);
        var account = await db.Taikhoans.SingleAsync(x => x.Email == "new@example.com");
        Assert.True(new PasswordService().Verify("password-123", account.MatKhauHash));
        Assert.NotEqual("password-123", account.MatKhauHash);
        Assert.Equal("New User", response.FullName);
        Assert.Equal(roleId, response.RoleId);
        Assert.Equal(customer ? 1 : 0, await db.Khachhangs.CountAsync());
        Assert.Equal(customer ? 0 : 1, await db.Nhanviens.CountAsync());
        if (customer) Assert.Equal(account.TaiKhoanId, (await db.Khachhangs.SingleAsync()).TaiKhoanId);
        else Assert.Equal(account.TaiKhoanId, (await db.Nhanviens.SingleAsync()).TaiKhoanId);
        var audit = await db.Auditlogs.SingleAsync();
        Assert.Equal("AccountCreated", audit.ActionName);
        Assert.Equal(account.TaiKhoanId.ToString(), audit.EntityId);
        Assert.DoesNotContain("password-123", audit.NewValues!);
        Assert.DoesNotContain(account.MatKhauHash, JsonSerializer.Serialize(response));
    }

    [Theory]
    [InlineData("bad", "password-123", "Name", null, 5)]
    [InlineData("user@example.com", "short", "Name", null, 5)]
    [InlineData("user@example.com", "password-123", "  ", null, 5)]
    [InlineData("user@example.com", "password-123", "Name", "bad-phone", 5)]
    [InlineData("user@example.com", "password-123", "Name", "0901234567123456", 5)]
    [InlineData("user@example.com", "password-123", "Name", null, 999)]
    [InlineData("user@example.com", "password-123", "Name", null, 6)]
    public async Task InvalidCreationCannotLeaveAccountOrProfile(string email, string password, string name, string? phone, int role)
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Admin(db).CreateAccount(new CreateAccountRequest(email, password, name, phone, role), default));
        Assert.Single(await db.Taikhoans.ToListAsync());
        Assert.Empty(await db.Khachhangs.ToListAsync());
        Assert.Empty(await db.Nhanviens.ToListAsync());
        Assert.Empty(await db.Auditlogs.ToListAsync());
    }

    [Fact]
    public async Task DuplicateEmailIsCaseInsensitiveAndDoesNotWrite()
    {
        await using var db = await Database();
        Assert.IsType<ConflictObjectResult>(await Admin(db).CreateAccount(new CreateAccountRequest(" ADMIN@EXAMPLE.COM ", "password-123", "Name", null, 5), default));
        Assert.Single(await db.Taikhoans.ToListAsync());
        Assert.Empty(await db.Auditlogs.ToListAsync());
    }

    [Fact]
    public async Task ChangingRolesPreservesProfilesBalanceRevokesRefreshAndAudits()
    {
        await using var db = await Database();
        var account = new Taikhoan { TaiKhoanId = 2, VaiTroId = 5, Email = "target@example.com", TenTaiKhoan = "Target", MatKhauHash = "unused", TrangThai = true };
        db.Taikhoans.Add(account);
        db.Khachhangs.Add(new Khachhang { TaiKhoanId = 2, HoTen = "Target", SoDienThoai = "0901234567", DiemThuong = 50 });
        db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = 2, TokenHash = "existing-refresh", CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddDays(1) });
        await db.SaveChangesAsync();
        var result = Assert.IsType<OkObjectResult>(await Admin(db).AssignAccountRole(2, new AssignAccountRoleRequest(4), default));
        Assert.Equal("Staff", Assert.IsType<AdminAccountResponse>(result.Value).Role);
        Assert.Equal(2, (await db.Nhanviens.SingleAsync()).TaiKhoanId);
        Assert.Equal("0901234567", (await db.Nhanviens.SingleAsync()).SoDienThoai);
        Assert.NotNull((await db.Refreshtokens.SingleAsync()).RevokedAt);
        Assert.Equal(50, (await db.Khachhangs.SingleAsync()).DiemThuong);
        Assert.IsType<OkObjectResult>(await Admin(db).AssignAccountRole(2, new AssignAccountRoleRequest(5), default));
        Assert.Single(await db.Nhanviens.ToListAsync());
        Assert.Single(await db.Khachhangs.ToListAsync());
        Assert.Equal(2, await db.Auditlogs.CountAsync(x => x.ActionName == "AccountRoleChanged"));
    }

    [Theory] [InlineData(2)] [InlineData(3)] [InlineData(4)] [InlineData(5)]
    public async Task ActiveAdministratorCannotDemoteOwnAccount(int roleId)
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Admin(db).AssignAccountRole(1, new AssignAccountRoleRequest(roleId), default));
        Assert.Equal(1, (await db.Taikhoans.SingleAsync()).VaiTroId);
        Assert.Empty(await db.Auditlogs.ToListAsync());
    }

    [Fact]
    public async Task LastAdministratorCannotDisableSelfAndNonAdminCannotBypassDirectGuard()
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Admin(db).SetAccountStatus(1, false, default));
        Assert.True((await db.Taikhoans.SingleAsync()).TrangThai);
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 2, VaiTroId = 3, Email = "reception@example.com", MatKhauHash = "unused", TrangThai = true });
        await db.SaveChangesAsync();
        Assert.IsType<ForbidResult>(await Admin(db, 2, "Admin").AssignAccountRole(1, new AssignAccountRoleRequest(5), default));
        Assert.IsType<ForbidResult>(await Admin(db, 2, "Reception").CreateAccount(new CreateAccountRequest("x@example.com", "password-123", "Name", null, 5), default));
        Assert.IsType<ForbidResult>(await Admin(db, 2, "Admin").SetAccountStatus(1, false, default));
        Assert.Equal(1, (await db.Taikhoans.FindAsync(1))!.VaiTroId);
    }

    [Fact]
    public async Task AccountListIncludesCurrentRoleIdAndFullNameWithoutPassword()
    {
        await using var db = await Database();
        var list = Assert.IsType<OkObjectResult>(await Admin(db).Accounts(null, default));
        var account = Assert.Single(Assert.IsType<List<AdminAccountResponse>>(list.Value));
        Assert.Equal(1, account.RoleId); Assert.Equal("Admin", account.FullName);
        Assert.DoesNotContain("matKhauHash", JsonSerializer.Serialize(account));
    }

    [Fact]
    public async Task PermissionsExposeOnlyCallersActiveGrantedCodesAndFollowRevocation()
    {
        await using var db = await Database();
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 2, VaiTroId = 3, Email = "reception@example.com", MatKhauHash = "unused", TrangThai = true });
        db.Quyens.AddRange(new Quyen { QuyenId = 1, MaQuyen = "REPORT.READ", TenQuyen = "Reports", NhomQuyen = "REPORT", TrangThai = true },
            new Quyen { QuyenId = 2, MaQuyen = "SERVICE.WRITE", TenQuyen = "Disabled", NhomQuyen = "SERVICE", TrangThai = false },
            new Quyen { QuyenId = 3, MaQuyen = "ACCOUNT.WRITE", TenQuyen = "Admin", NhomQuyen = "ACCOUNT", TrangThai = true });
        db.VaitroQuyens.AddRange(new VaitroQuyen { VaiTroId = 3, QuyenId = 1, DuocCap = true }, new VaitroQuyen { VaiTroId = 3, QuyenId = 2, DuocCap = true }, new VaitroQuyen { VaiTroId = 1, QuyenId = 3, DuocCap = true });
        await db.SaveChangesAsync();
        var result = Assert.IsType<CurrentPermissionsResponse>(Assert.IsType<OkObjectResult>(await Auth(db, 2).CurrentPermissions(default)).Value);
        Assert.Equal("Reception", result.Role); Assert.Equal(["REPORT.READ"], result.Permissions);
        (await db.VaitroQuyens.SingleAsync(x => x.VaiTroId == 3 && x.QuyenId == 1)).DuocCap = false;
        await db.SaveChangesAsync();
        result = Assert.IsType<CurrentPermissionsResponse>(Assert.IsType<OkObjectResult>(await Auth(db, 2).CurrentPermissions(default)).Value);
        Assert.Empty(result.Permissions);
        (await db.Taikhoans.FindAsync(2))!.TrangThai = false; await db.SaveChangesAsync();
        Assert.IsType<UnauthorizedResult>(await Auth(db, 2).CurrentPermissions(default));
    }
}
