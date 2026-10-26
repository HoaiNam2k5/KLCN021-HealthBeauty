using System.Security.Claims;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class VoucherConsentTests
{
    [Fact]
    public async Task ActualHttpBindingAcceptsLegacyEmptyBodyAndValidatesExpectedCost()
    {
        var builder = WebApplication.CreateBuilder();
        var database = Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(database));
        builder.Services.AddAuthentication(); builder.Services.AddAuthorization();
        builder.Services.AddControllers().AddApplicationPart(typeof(VoucherRedemptionController).Assembly);
        await using var app = builder.Build();
        app.Use(async (context, next) => { context.User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, "11"), new Claim(ClaimTypes.Role, "Customer")], "Test")); await next(); });
        app.UseAuthorization(); app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 11, HoTen = "Owner", DiemThuong = 1000 });
            db.Khuyenmais.Add(new Khuyenmai { KhuyenMaiId = 1, TenKhuyenMai = "Offer", LoaiGiam = "SoTien", MucGiam = 50000 });
            foreach (var id in new[] { 1, 2, 3 }) db.Vouchers.Add(new Voucher { VoucherId = id, MaCode = "TEST" + id, KhuyenMaiId = 1, GiaTriGiam = 50000, PointsCost = 200, HanSuDung = DateTime.Now.AddDays(1), TrangThai = true });
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        try
        {
            using var client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) };
            Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/v1/customers/me/vouchers/1/redeem", new { expectedPointsCost = 100 })).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/v1/customers/me/vouchers/1/redeem", new { expectedPointsCost = 200 })).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await client.PostAsync("/api/v1/customers/me/vouchers/2/redeem", null)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/customers/me/vouchers/3/redeem", new { expectedPointsCost = 0 })).StatusCode);
            using var scope = app.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            Assert.Equal(600, (await db.Khachhangs.SingleAsync()).DiemThuong);
            Assert.Equal(2, await db.Giaodichdiems.CountAsync());
        }
        finally { await app.StopAsync(); }
    }
    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 11, HoTen = "Owner", DiemThuong = 500 });
        db.Khuyenmais.Add(new Khuyenmai { KhuyenMaiId = 1, TenKhuyenMai = "Offer", LoaiGiam = "SoTien", MucGiam = 50000 });
        db.Vouchers.Add(new Voucher { VoucherId = 1, MaCode = "TEST", KhuyenMaiId = 1, GiaTriGiam = 50000, PointsCost = 200, HanSuDung = DateTime.Now.AddDays(1), TrangThai = true });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static VoucherRedemptionController Controller(Klcn021HealthBeautyContext db, int account = 11) => new(db)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, account.ToString()), new Claim(ClaimTypes.Role, "Customer")], "Test")) } }
    };

    [Theory]
    [InlineData(100)]
    [InlineData(300)]
    public async Task ChangedCostCannotChargeDifferentAmountFromConsent(int confirmed)
    {
        await using var db = await Database();
        Assert.IsType<ConflictObjectResult>(await Controller(db).Redeem(1, default, new(confirmed)));
        Assert.Equal(500, (await db.Khachhangs.SingleAsync()).DiemThuong);
        Assert.Null((await db.Vouchers.SingleAsync()).KhachHangId);
        Assert.Empty(db.Giaodichdiems);
    }

    [Fact]
    public async Task MatchingConsentChargesOnceAndOldClientsWithoutBodyRemainCompatible()
    {
        await using var db = await Database();
        Assert.IsType<OkObjectResult>(await Controller(db).Redeem(1, default, new(200)));
        Assert.IsType<ConflictObjectResult>(await Controller(db).Redeem(1, default, new(200)));
        Assert.Equal(300, (await db.Khachhangs.SingleAsync()).DiemThuong);
        Assert.Single(db.Giaodichdiems);
        await using var legacy = await Database();
        Assert.IsType<OkObjectResult>(await Controller(legacy).Redeem(1, default));
    }

    [Fact]
    public async Task InvalidConsentMissingCustomerOrInsufficientBalanceNeverCharges()
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Controller(db).Redeem(1, default, new(0)));
        Assert.IsType<ForbidResult>(await Controller(db, 99).Redeem(1, default, new(200)));
        var customer = await db.Khachhangs.SingleAsync(); customer.DiemThuong = 100; await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>(await Controller(db).Redeem(1, default, new(200)));
        Assert.Equal(100, customer.DiemThuong);
        Assert.Empty(db.Giaodichdiems);
    }
}
