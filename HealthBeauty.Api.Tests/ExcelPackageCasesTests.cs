using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using HealthBeauty.Api.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Text.Json;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ExcelPackageCasesTests
{
    [Fact]
    public async Task PKG06_OwnerDetailReportsUsedReservedRemainingAndAvailable()
    {
        await using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Test" });
        db.CustomerPackages.Add(new CustomerPackage { Id = 1, CustomerId = 1, Status = "Paid", ExpiresAt = DateTime.Now.AddDays(30), Items = [
            new CustomerPackageItem { Id = 1, ServiceId = 1, ServiceName = "Facial", Granted = 5, Used = 2, Reserved = 1 }
        ] });
        await db.SaveChangesAsync();
        var controller = new ServicePackagesController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "1"), new Claim(ClaimTypes.Role, "Customer")], "test"))
        } } };

        var result = Assert.IsType<OkObjectResult>(await controller.Detail(1, default));
        var response = JsonSerializer.SerializeToElement(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        var package = response.GetProperty("package");
        var item = package.GetProperty("items")[0];
        Assert.Equal("Paid", package.GetProperty("status").GetString());
        Assert.Equal(5, item.GetProperty("granted").GetInt32());
        Assert.Equal(2, item.GetProperty("used").GetInt32());
        Assert.Equal(1, item.GetProperty("reserved").GetInt32());
        Assert.Equal(3, item.GetProperty("remaining").GetInt32());
        Assert.Equal(2, item.GetProperty("available").GetInt32());
    }
    [Theory]
    [InlineData(3, 0)]
    [InlineData(2, 1)]
    public async Task PKG05_ExhaustedOrFullyReservedSessionsCannotBeBooked(int used, int reserved)
    {
        await using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var package = new CustomerPackage { Id = 1, CustomerId = 1, Status = "Paid", ExpiresAt = DateTime.Now.AddDays(30), Items = [
            new CustomerPackageItem { Id = 1, ServiceId = 1, Granted = 3, Used = used, Reserved = reserved },
            new CustomerPackageItem { Id = 2, ServiceId = 2, Granted = 2 }
        ] };
        db.CustomerPackages.Add(package);
        await db.SaveChangesAsync();
        var appointment = new Lichhen { KhachHangId = 1, NgayGioHen = DateTime.Now.AddDays(1), Chitietlichhens = [
            new Chitietlichhen { DichVuId = 2 }, new Chitietlichhen { DichVuId = 1 }
        ] };

        var error = await ServicePackageLifecycle.ReserveAsync(db, appointment, 1, default);

        Assert.NotNull(error);
        Assert.Null(appointment.CustomerPackageId);
        Assert.Equal(reserved, package.Items[0].Reserved);
        Assert.Equal(0, package.Items[1].Reserved);
        Assert.Empty(db.PackageUsages);
    }
}
