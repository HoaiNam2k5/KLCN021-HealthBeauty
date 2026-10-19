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
public sealed class ServicePackageTests
{
    static DbContextOptions<Klcn021HealthBeautyContext> Options() => new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
    static Klcn021HealthBeautyContext Db() => new(Options());
    static ServicePackagesController Controller(Klcn021HealthBeautyContext db, string role = "Customer", int id = 1) => new(db)
    {
        ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(new[]
    {
new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, role)
}
    , "test"))
            }
        }
    }
    ;
    static JsonElement Json(object v) => JsonSerializer.SerializeToElement(v, new JsonSerializerOptions(JsonSerializerDefaults.Web));
    static async Task Seed(Klcn021HealthBeautyContext db)
    {
        db.Khachhangs.Add(new Khachhang
        {
            KhachHangId = 1,
            TaiKhoanId = 1,
            HoTen = "One"
        }
        );
        db.Dichvus.Add(new Dichvu
        {
            DichVuId = 1,
            TenDichVu = "Facial",
            TrangThai = true
        }
        );
        db.ServicePackages.Add(new ServicePackage
        {
            Id = 1,
            Name = "Ten sessions",
            Price = 100000,
            ValidityDays = 30,
            Items = [new ServicePackageItem
            {
                ServiceId = 1,
                Sessions = 10
            }
        ]
        }
        );
        await db.SaveChangesAsync();
    }
    [Fact]
    public async Task PurchaseSnapshotsAndPaymentAwardsOnce()
    {
        await using var db = Db();
        await Seed(db);
        var result = Assert.IsType<CreatedResult>(await Controller(db).Purchase(new(1), default));
        Assert.Equal("Pending", Json(result.Value!).GetProperty("status").GetString());
        var p = await db.CustomerPackages.Include(x => x.Items).SingleAsync();
        var catalog = await db.ServicePackages.SingleAsync();
        catalog.Price = 999999;
        catalog.Name = "Edited";
        await db.SaveChangesAsync();
        Assert.Equal(100000, p.Price);
        Assert.Equal("Ten sessions", p.Name);
        Assert.IsType<OkObjectResult>(await Controller(db, "Admin").Pay(p.Id, new("TienMat"), default));
        Assert.Equal(10, (await db.Khachhangs.SingleAsync()).DiemThuong);
        Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.IsType<ConflictObjectResult>(await Controller(db, "Admin").Pay(p.Id, new("TienMat"), default));
        Assert.Single(await db.Giaodichdiems.ToListAsync());
    }
    [Fact]
    public async Task CustomerCannotPurchaseOrReadForAnother()
    {
        await using var db = Db();
        await Seed(db);
        Assert.IsType<ForbidResult>(await Controller(db).Purchase(new(1, 2), default));
        await Controller(db).Purchase(new(1), default);
        Assert.IsType<ForbidResult>(await Controller(db, "Customer", 2).Detail(1, default));
        Assert.IsType<ForbidResult>(await Controller(db, "Customer", 2).CancelPurchase(1, default));
    }
    [Fact]
    public async Task PendingAndExpiredCannotReserve()
    {
        await using var db = Db();
        await Seed(db);
        await Controller(db).Purchase(new(1), default);
        var p = await db.CustomerPackages.Include(x => x.Items).SingleAsync();
        var a = new Lichhen
        {
            KhachHangId = 1,
            NgayGioHen = DateTime.Now.AddDays(1),
            TrangThai = "ChoXacNhan",
            Chitietlichhens = [new Chitietlichhen
            {
                DichVuId = 1
            }
        ]
        }
        ;
        Assert.NotNull(await ServicePackageLifecycle.ReserveAsync(db, a, p.Id, default));
        await Controller(db, "Admin").Pay(p.Id, new("TienMat"), default);
        a.NgayGioHen = p.ExpiresAt!.Value.AddSeconds(1);
        Assert.NotNull(await ServicePackageLifecycle.ReserveAsync(db, a, p.Id, default));
        Assert.Equal(0, p.Items[0].Reserved);
    }
    [Fact]
    public async Task ReservationCancelAndCompletionHaveExactBalances()
    {
        await using var db = Db();
        await Seed(db);
        await Controller(db).Purchase(new(1), default);
        await Controller(db, "Admin").Pay(1, new("TienMat"), default);
        var p = await db.CustomerPackages.Include(x => x.Items).SingleAsync();
        Lichhen Appointment() => new()
        {
            KhachHangId = 1,
            NgayGioHen = DateTime.Now.AddDays(1),
            TrangThai = "ChoXacNhan",
            Chitietlichhens = [new Chitietlichhen
            {
                DichVuId = 1
            }
        ,
                new Chitietlichhen
                {
                    DichVuId = 1
                }
        ]
        }
        ;
        var a = Appointment();
        Assert.Null(await ServicePackageLifecycle.ReserveAsync(db, a, 1, default));
        db.Lichhens.Add(a);
        await db.SaveChangesAsync();
        Assert.Equal(2, p.Items[0].Reserved);
        await ServicePackageLifecycle.SettleAsync(db, a, false, default);
        await db.SaveChangesAsync();
        Assert.Equal(0, p.Items[0].Reserved);
        Assert.Equal(0, p.Items[0].Used);
        var b = Appointment();
        Assert.Null(await ServicePackageLifecycle.ReserveAsync(db, b, 1, default));
        db.Lichhens.Add(b);
        await db.SaveChangesAsync();
        await ServicePackageLifecycle.SettleAsync(db, b, true, default);
        await db.SaveChangesAsync();
        await ServicePackageLifecycle.SettleAsync(db, b, true, default);
        await db.SaveChangesAsync();
        Assert.Equal(0, p.Items[0].Reserved);
        Assert.Equal(2, p.Items[0].Used);
        var invoice = Assert.Single(await db.Hoadons.Include(x => x.Chitiethoadons).ToListAsync());
        Assert.Equal("DaThanhToan", invoice.TrangThai);
        Assert.Equal(0, invoice.TongTienSauGiam);
        Assert.Equal(2, Assert.Single(invoice.Chitiethoadons).SoLuong);
        Assert.Single(await db.Giaodichdiems.ToListAsync());
    }
    [Fact]
    public async Task EntitlementConcurrencyPreventsOverspend()
    {
        var options = Options();
        await using (var seed = new Klcn021HealthBeautyContext(options))
        {
            await Seed(seed);
            await Controller(seed).Purchase(new(1), default);
            await Controller(seed, "Admin").Pay(1, new("TienMat"), default);
        }
        await using var one = new Klcn021HealthBeautyContext(options);
        await using var two = new Klcn021HealthBeautyContext(options);
        var a = await one.CustomerPackageItems.SingleAsync();
        var b = await two.CustomerPackageItems.SingleAsync();
        a.Reserved = 10;
        a.Version = Guid.NewGuid();
        b.Reserved = 10;
        b.Version = Guid.NewGuid();
        await one.SaveChangesAsync();
        Assert.False(await NotificationPersistence.TrySaveAsync(two, default));
        await using var check = new Klcn021HealthBeautyContext(options);
        Assert.Equal(10, (await check.CustomerPackageItems.SingleAsync()).Reserved);
    }
    [Fact]
    public async Task PaymentConcurrencyProtectsReceipt()
    {
        var options = Options();
        await using (var seed = new Klcn021HealthBeautyContext(options))
        {
            await Seed(seed);
            await Controller(seed).Purchase(new(1), default);
        }
        await using var one = new Klcn021HealthBeautyContext(options);
        await using var two = new Klcn021HealthBeautyContext(options);
        await one.CustomerPackages.LoadAsync();
        await two.CustomerPackages.LoadAsync();
        Assert.IsType<OkObjectResult>(await Controller(one, "Admin").Pay(1, new("TienMat"), default));
        Assert.IsType<ConflictObjectResult>(await Controller(two, "Admin").Pay(1, new("The"), default));
    }
    [Theory]
    [InlineData("Admin")]
    [InlineData("Manager")]
    [InlineData("Reception")]
    public void PermissionMap(string role)
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
new Claim(ClaimTypes.Role, role)
}
        , "test"));
        Assert.Equal("PAYMENT.WRITE", DatabasePermissionFilter.RequiredPermission("ServicePackages", "Pay", user));
        Assert.Equal("SERVICE.WRITE", DatabasePermissionFilter.RequiredPermission("ServicePackages", "ManagementList", user));
        Assert.Equal("CUSTOMER.READ", DatabasePermissionFilter.RequiredPermission("ServicePackages", "Detail", user));
        Assert.Equal("REPORT.READ", DatabasePermissionFilter.RequiredPermission("ServicePackages", "Sales", user));
    }
    [Fact]
    public async Task CatalogValidationAndNoInactivePublicAccess()
    {
        await using var db = Db();
        await Seed(db);
        Assert.IsType<BadRequestObjectResult>(await Controller(db, "Admin").Create(new("Invalid", 1, 30, [new(1, 2), new(1, 2)]), default));
        Assert.IsType<BadRequestObjectResult>(await Controller(db).List(default, true));
        var p = await db.ServicePackages.SingleAsync();
        p.Active = false;
        await db.SaveChangesAsync();
        Assert.Empty(Json(Assert.IsType<OkObjectResult>(await Controller(db).List(default)).Value!).EnumerateArray());
        Assert.IsType<NotFoundResult>(await Controller(db).Purchase(new(1), default));
    }
    [Fact]
    public async Task PaidPurchaseCannotCancelAndSalesSeparate()
    {
        await using var db = Db();
        await Seed(db);
        await Controller(db).Purchase(new(1), default);
        await Controller(db, "Admin").Pay(1, new("TienMat"), default);
        Assert.IsType<ConflictObjectResult>(await Controller(db).CancelPurchase(1, default));
        var report = Json(Assert.IsType<OkObjectResult>(await Controller(db, "Admin").Sales(DateTime.Today, DateTime.Today.AddDays(1), default)).Value!);
        Assert.Equal(100000, report.GetProperty("revenue").GetDecimal());
        Assert.Empty(await db.Hoadons.ToListAsync());
    }

    [Fact]
    public async Task InactiveServiceDoesNotPreventDeactivatingItsPackage()
    {
        await using var db = Db();
        await Seed(db);
        (await db.Dichvus.SingleAsync()).TrangThai = false;
        await db.SaveChangesAsync();
        var request = new ServicePackageRequest("Ten sessions", 100000, 30, [new(1, 10)], Active: false);
        Assert.IsType<OkObjectResult>(await Controller(db, "Admin").Update(1, request, default));
        Assert.False((await db.ServicePackages.SingleAsync()).Active);
        Assert.IsType<NotFoundResult>(await Controller(db).Purchase(new(1), default));
    }
}
