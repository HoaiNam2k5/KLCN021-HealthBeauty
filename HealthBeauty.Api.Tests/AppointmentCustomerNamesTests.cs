using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AppointmentCustomerNamesTests
{
    [Theory]
    [InlineData("Staff", 11, 1)]
    [InlineData("Customer", 21, 1)]
    [InlineData("Reception", 99, 2)]
    public async Task ScopedListIncludesNamesWithoutRequiringCustomerDirectory(string role, int account, int count)
    {
        await using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 21, HoTen = "Customer One" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 22, HoTen = "Customer Two" });
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 1, TaiKhoanId = 11, HoTen = "Staff One" },
            new Nhanvien { NhanVienId = 2, TaiKhoanId = 12, HoTen = "Staff Two" });
        db.Lichhens.AddRange(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 1, TrangThai = "ChoXacNhan", NgayGioHen = DateTime.Today },
            new Lichhen { LichHenId = 2, KhachHangId = 2, NhanVienId = 2, TrangThai = "ChoXacNhan", NgayGioHen = DateTime.Today.AddDays(-1) });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var controller = new AppointmentsController(db) { ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([
                new Claim(ClaimTypes.NameIdentifier, account.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) }
        } };
        var result = Assert.IsType<OkObjectResult>(await controller.GetMine(null, null, null, null, null));
        var items = JsonSerializer.SerializeToElement(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web)).GetProperty("items");
        Assert.Equal(count, items.GetArrayLength());
        Assert.Equal("Customer One", items[0].GetProperty("customerName").GetString());
        Assert.Equal("Staff One", items[0].GetProperty("staffName").GetString());
    }
}
