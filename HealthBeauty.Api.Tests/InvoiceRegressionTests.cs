using System.Reflection;
using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class InvoiceRegressionTests
{
    private static async Task<Klcn021HealthBeautyContext> Database(string status = "HoanThanh", params (int Service, int? Combo)[] booked)
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Customer", DiemThuong = 50 });
        db.Dichvus.AddRange(new Dichvu { DichVuId = 1, TenDichVu = "Service One", Gia = 100000m, ThoiLuongPhut = 60, TrangThai = true },
            new Dichvu { DichVuId = 2, TenDichVu = "Cheaper Service", Gia = 10000m, ThoiLuongPhut = 30, TrangThai = true });
        db.Combodichvus.Add(new Combodichvu { ComboId = 1, TenCombo = "Complete Combo", GiaCombo = 80000m, TrangThai = true,
            Chitietcombos = [new Chitietcombo { DichVuId = 1, SoLuong = 1 }, new Chitietcombo { DichVuId = 2, SoLuong = 2 }] });
        if (booked.Length == 0) booked = [(1, null)];
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NgayGioHen = DateTime.Today.AddDays(-1), TrangThai = status,
            Chitietlichhens = booked.Select((x, i) => new Chitietlichhen { ChiTietLichHenId = i + 1, DichVuId = x.Service, ComboId = x.Combo, GiaDuKien = 100000m }).ToList() });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        return db;
    }

    private static InvoicesController Controller(Klcn021HealthBeautyContext db, string role = "Customer") => new(db)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, role == "Customer" ? "1" : "99"), new Claim(ClaimTypes.Role, role)], "Test")) } }
    };

    [Theory]
    [InlineData("ChoXacNhan")]
    [InlineData("DaXacNhan")]
    [InlineData("DangThucHien")]
    [InlineData("DaHuy")]
    public async Task OnlyCompletedAppointmentCanBeInvoiced(string status)
    {
        await using var db = await Database(status);
        var result = await Controller(db).Create(new CreateInvoiceRequest(1, [new(1, null, 1)], null), default);
        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Empty(await db.Hoadons.ToListAsync());
    }

    [Theory]
    [InlineData(2, 1)] // Cheaper, unbooked service.
    [InlineData(1, 2)] // Wrong quantity.
    public async Task RejectsChangedBookedServiceOrQuantity(int serviceId, int quantity)
    {
        await using var db = await Database();
        Assert.IsType<BadRequestObjectResult>(await Controller(db).Create(new CreateInvoiceRequest(1, [new(serviceId, null, quantity)], null), default));
        Assert.Empty(await db.Hoadons.ToListAsync());
    }

    [Fact]
    public async Task AcceptsExactRepeatedServicesAndCustomerCanReadInvoice()
    {
        await using var db = await Database("HoanThanh", (1, null), (1, null));
        Assert.IsType<CreatedAtActionResult>(await Controller(db).Create(new CreateInvoiceRequest(1, [new(1, null, 2)], null), default));
        Assert.Equal(200000m, (await db.Hoadons.SingleAsync()).TongTienSauGiam);
        var list = Assert.IsType<OkObjectResult>(await Controller(db).List(default));
        Assert.Single(Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(list.Value));
    }

    [Fact]
    public async Task RejectsOmittedBookedService()
    {
        await using var db = await Database("HoanThanh", (1, null), (2, null));
        Assert.IsType<BadRequestObjectResult>(await Controller(db).Create(new CreateInvoiceRequest(1, [new(1, null, 1)], null), default));
        Assert.Empty(await db.Hoadons.ToListAsync());
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task RejectsIncompleteOrUnknownBookedCombo(bool unknown)
    {
        await using var db = await Database("HoanThanh", (1, unknown ? 999 : 1));
        Assert.IsType<BadRequestObjectResult>(await Controller(db).Create(new CreateInvoiceRequest(1, [new(null, unknown ? 999 : 1, 1)], null), default));
        Assert.Empty(await db.Hoadons.ToListAsync());
    }

    [Theory]
    [InlineData(1, false)]
    [InlineData(2, true)]
    public async Task CompleteComboCopiesMustMatchInvoiceQuantity(int quantity, bool accepted)
    {
        await using var db = await Database("HoanThanh", (1, 1), (2, 1), (2, 1), (1, 1), (2, 1), (2, 1));
        var result = await Controller(db).Create(new CreateInvoiceRequest(1, [new(null, 1, quantity)], null), default);
        if (accepted)
        {
            Assert.IsType<CreatedAtActionResult>(result);
            Assert.Equal(160000m, (await db.Hoadons.SingleAsync()).TongTienSauGiam);
        }
        else Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task CustomerCannotSelfConfirmPaymentOrEarnPoints()
    {
        await using var db = await Database();
        db.Hoadons.Add(new Hoadon { HoaDonId = 1, LichHenId = 1, KhachHangId = 1, TrangThai = "ChuaThanhToan", TongTienSauGiam = 100000m });
        await db.SaveChangesAsync();
        Assert.IsType<ForbidResult>(await Controller(db).Pay(1, new PaymentRequest("TienMat"), default));
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.SingleAsync()).TrangThai);
        Assert.Equal(50, (await db.Khachhangs.SingleAsync()).DiemThuong);
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.Empty(await db.Giaodichdiems.ToListAsync());
        var roles = typeof(InvoicesController).GetMethod(nameof(InvoicesController.Pay))!.GetCustomAttribute<AuthorizeAttribute>()!.Roles;
        Assert.Equal("Admin,Manager,Reception", roles);
    }

    [Theory]
    [InlineData("Admin")]
    [InlineData("Manager")]
    [InlineData("Reception")]
    public async Task StaffWithCustomerProfileCanInvoiceListAndPayOtherCustomer(string role)
    {
        await using var db = await Database();
        db.Khachhangs.Add(new Khachhang { KhachHangId = 2, TaiKhoanId = 99, HoTen = "Staff Customer Profile" });
        db.Lichhens.Add(new Lichhen { LichHenId = 2, KhachHangId = 2, TrangThai = "HoanThanh", NgayGioHen = DateTime.Today.AddDays(-1),
            Chitietlichhens = [new Chitietlichhen { ChiTietLichHenId = 2, DichVuId = 2 }] });
        db.Hoadons.Add(new Hoadon { HoaDonId = 2, LichHenId = 2, KhachHangId = 2, TrangThai = "ChuaThanhToan", TongTienSauGiam = 10000m });
        await db.SaveChangesAsync();
        Assert.IsType<CreatedAtActionResult>(await Controller(db, role).Create(new CreateInvoiceRequest(1, [new(1, null, 1)], null), default));
        var invoice = await db.Hoadons.SingleAsync(x => x.KhachHangId == 1);
        var list = Assert.IsType<OkObjectResult>(await Controller(db, role).List(default));
        Assert.Equal(2, Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(list.Value).Count());
        Assert.IsType<OkObjectResult>(await Controller(db, role).Pay(invoice.HoaDonId, new PaymentRequest("TienMat"), default));
        Assert.Equal("DaThanhToan", invoice.TrangThai);
        Assert.Equal(60, (await db.Khachhangs.SingleAsync(x => x.KhachHangId == 1)).DiemThuong);
        Assert.Equal(0, (await db.Khachhangs.SingleAsync(x => x.KhachHangId == 2)).DiemThuong);
    }

    [Fact]
    public async Task CustomerCannotInvoiceReadOrPayOtherCustomersInvoice()
    {
        await using var db = await Database();
        db.Khachhangs.Add(new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Other Customer" });
        db.Lichhens.Add(new Lichhen { LichHenId = 2, KhachHangId = 2, TrangThai = "HoanThanh", NgayGioHen = DateTime.Today.AddDays(-1),
            Chitietlichhens = [new Chitietlichhen { ChiTietLichHenId = 2, DichVuId = 1 }] });
        db.Hoadons.Add(new Hoadon { HoaDonId = 2, LichHenId = 2, KhachHangId = 2, TrangThai = "ChuaThanhToan", TongTienSauGiam = 100000m });
        await db.SaveChangesAsync();
        Assert.IsType<ForbidResult>(await Controller(db).Create(new CreateInvoiceRequest(2, [new(1, null, 1)], null), default));
        var list = Assert.IsType<OkObjectResult>(await Controller(db).List(default));
        Assert.Empty(Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(list.Value));
        Assert.IsType<ForbidResult>(await Controller(db).Pay(2, new PaymentRequest("TienMat"), default));
        Assert.Empty(await db.Thanhtoans.ToListAsync());
    }

    [Theory]
    [InlineData("Admin")]
    [InlineData("Manager")]
    [InlineData("Reception")]
    public async Task AuthorizedStaffCanConfirmPaymentOnce(string role)
    {
        await using var db = await Database();
        db.Hoadons.Add(new Hoadon { HoaDonId = 1, LichHenId = 1, KhachHangId = 1, TrangThai = "ChuaThanhToan", TongTienSauGiam = 100000m });
        await db.SaveChangesAsync();
        Assert.IsType<OkObjectResult>(await Controller(db, role).Pay(1, new PaymentRequest("TienMat"), default));
        Assert.Equal("DaThanhToan", (await db.Hoadons.SingleAsync()).TrangThai);
        Assert.Equal(60, (await db.Khachhangs.SingleAsync()).DiemThuong);
        Assert.Single(await db.Thanhtoans.ToListAsync());
        Assert.IsType<ConflictObjectResult>(await Controller(db, role).Pay(1, new PaymentRequest("TienMat"), default));
        Assert.Single(await db.Giaodichdiems.ToListAsync());
    }
    [Theory]
    [InlineData("ChoXacNhan")]
    [InlineData("HoanThanh")]
    public async Task ComboCompositionCannotChangeBeforeBookedAppointmentIsInvoiced(string status)
    {
        await using var db = await Database(status, (1,1),(2,1),(2,1));
        var request = new ComboRequest("Changed",80000m,null,null,[new(1,1),new(2,1)]);
        Assert.IsType<ConflictObjectResult>(await new CombosController(db).Update(1,request,default));
        db.ChangeTracker.Clear();
        Assert.Equal(2,await db.Chitietcombos.Where(x=>x.ComboId==1 && x.DichVuId==2).Select(x=>x.SoLuong).SingleAsync());
        if(status=="HoanThanh") Assert.IsType<CreatedAtActionResult>(await Controller(db).Create(new CreateInvoiceRequest(1,[new(null,1,1)],null),default));
    }
    [Fact]
    public async Task CancelledAppointmentDoesNotPreventComboCompositionChange()
    {
        await using var db=await Database("DaHuy",(1,1),(2,1),(2,1));
        var request=new ComboRequest("Changed",80000m,null,null,[new(1,1),new(2,1)]);
        Assert.IsType<OkObjectResult>(await new CombosController(db).Update(1,request,default));
    }

}
