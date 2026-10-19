using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class LoyaltyConsistencyTests
{
    private static Klcn021HealthBeautyContext Database() => new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static JsonElement Json(object? value) => JsonSerializer.SerializeToElement(value, new JsonSerializerOptions(JsonSerializerDefaults.Web));

    [Fact]
    public void BalanceAndVoucherAreConcurrencyProtectedAndAppointmentInvoiceIsUnique()
    {
        using var db = Database();
        foreach (var type in new[] { typeof(Khachhang), typeof(Voucher) })
        {
            var property = db.Model.FindEntityType(type)!.FindProperty("RowVersion")!;
            Assert.True(property.IsConcurrencyToken);
            Assert.Equal(Microsoft.EntityFrameworkCore.Metadata.ValueGenerated.OnAddOrUpdate, property.ValueGenerated);
        }
        Assert.Contains(db.Model.FindEntityType(typeof(Hoadon))!.GetIndexes(), i => i.IsUnique && i.Properties.Select(p => p.Name).SequenceEqual(new[] { "LichHenId" }));
        Assert.False(Json(new Khachhang()).TryGetProperty("rowVersion", out _));
        Assert.False(Json(new Voucher()).TryGetProperty("rowVersion", out _));
    }

    [Theory]
    [InlineData("Admin")]
    [InlineData("Manager")]
    [InlineData("Reception")]
    public void StaffLedgerRequiresCustomerReadGrant(string role)
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.Role, role) }, "Test"));
        Assert.Equal("CUSTOMER.READ", DatabasePermissionFilter.RequiredPermission("Customers", "PointHistory", user));
        var authorization = Assert.Single(typeof(CustomersController).GetMethod("PointHistory")!.GetCustomAttributes(typeof(AuthorizeAttribute), false).Cast<AuthorizeAttribute>());
        Assert.Equal("Admin,Manager,Reception", authorization.Roles);
    }

    [Fact]
    public async Task LedgerPaginatesStablyAndNeverReturnsOtherCustomerTransactions()
    {
        await using var db = Database();
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, HoTen = "First", DiemThuong = 30 }, new Khachhang { KhachHangId = 2, HoTen = "Other", DiemThuong = 999 });
        var time = new DateTime(2026, 10, 18);
        db.Giaodichdiems.AddRange(Enumerable.Range(1, 4).Select(id => new Giaodichdiem { GiaoDichId = id, KhachHangId = id == 4 ? 2 : 1, SoDiem = 10, NgayGiaoDich = time, LoaiGiaoDich = "TichLuy" }));
        await db.SaveChangesAsync();
        var controller = new CustomersController(db);
        var result = Json(Assert.IsType<OkObjectResult>(await controller.PointHistory(1, 1, 2)).Value);
        Assert.Equal(30, result.GetProperty("diemThuong").GetInt32());
        Assert.Equal(3, result.GetProperty("totalCount").GetInt32());
        Assert.Equal(new[] { 3, 2 }, result.GetProperty("transactions").EnumerateArray().Select(t => t.GetProperty("giaoDichId").GetInt32()));
        var next = Json(Assert.IsType<OkObjectResult>(await controller.PointHistory(1, 2, 2)).Value);
        Assert.Equal(1, Assert.Single(next.GetProperty("transactions").EnumerateArray()).GetProperty("giaoDichId").GetInt32());
        Assert.IsType<NotFoundResult>(await controller.PointHistory(99));
    }

    [Theory]
    [InlineData(0, 20)]
    [InlineData(1, 0)]
    [InlineData(1, 101)]
    [InlineData(int.MaxValue, 100)]
    public async Task LedgerRejectsInvalidAndOverflowingPagination(int page, int size)
    {
        await using var db = Database();
        Assert.IsType<BadRequestObjectResult>(await new CustomersController(db).PointHistory(1, page, size));
    }
}
