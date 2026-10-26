using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AppointmentActionTests
{
    private static Klcn021HealthBeautyContext Db() => new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static AppointmentManagementController Controller(Klcn021HealthBeautyContext db, string role = "Reception") => new(db)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, "11"), new Claim(ClaimTypes.Role, role)], "Test")) } }
    };
    private static async Task Seed(Klcn021HealthBeautyContext db, string status)
    {
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, HoTen = "Customer", TaiKhoanId = 11 });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, TrangThai = status, NgayGioHen = DateTime.Today });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
    }

    [Theory]
    [InlineData("DaXacNhan")]
    [InlineData("DaDen")]
    public async Task ReceptionStartsWithOrWithoutOptionalArrival(string status)
    {
        await using var db = Db(); await Seed(db, status);
        Assert.IsType<NoContentResult>(await Controller(db).Status(1, new("DangThucHien"), default));
        Assert.Equal("DangThucHien", (await db.Lichhens.SingleAsync()).TrangThai);
        Assert.Empty(db.Hoadons);
        var audit = await db.Auditlogs.SingleAsync();
        Assert.Equal(11, audit.TaiKhoanId);
        Assert.Equal("AppointmentStatusChanged", audit.ActionName);
        Assert.Equal(status, JsonDocument.Parse(audit.OldValues!).RootElement.GetProperty("status").GetString());
        Assert.NotEqual(default, audit.CreatedAt);
    }

    [Theory]
    [InlineData("ChoXacNhan", "HoanThanh")]
    [InlineData("DaXacNhan", "HoanThanh")]
    [InlineData("DangThucHien", "DaHuy")]
    [InlineData("HoanThanh", "DaXacNhan")]
    public async Task InvalidShortcutsAndTerminalReversalsRemainBlocked(string status, string next)
    {
        await using var db = Db(); await Seed(db, status);
        Assert.IsType<ConflictObjectResult>(await Controller(db).Status(1, new(next, "reason"), default));
        Assert.Empty(db.Auditlogs); Assert.Empty(db.Hoadons);
        Assert.Equal(status, (await db.Lichhens.SingleAsync()).TrangThai);
    }

    [Fact]
    public async Task ClerkCancellationNeedsReasonAndPersistsItAtomically()
    {
        await using var db = Db(); await Seed(db, "DaXacNhan");
        Assert.IsType<BadRequestObjectResult>(await Controller(db).Status(1, new("DaHuy", "  "), default));
        Assert.Empty(db.Auditlogs);
        Assert.IsType<NoContentResult>(await Controller(db).Status(1, new("DaHuy", "  Customer unavailable  "), default));
        var audit = await db.Auditlogs.SingleAsync();
        Assert.Equal("Customer unavailable", JsonDocument.Parse(audit.NewValues!).RootElement.GetProperty("reason").GetString());
        Assert.Equal("DaHuy", (await db.Lichhens.SingleAsync()).TrangThai);
    }

    [Theory]
    [InlineData("Staff")]
    [InlineData("Customer")]
    public async Task ActionButtonsDoNotExpandTechnicianOrCustomerPermissions(string role)
    {
        await using var db = Db(); await Seed(db, "DaXacNhan");
        Assert.IsType<ForbidResult>(await Controller(db, role).Status(1, new("DangThucHien"), default));
        Assert.Empty(db.Auditlogs);
    }
}
