using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;
namespace HealthBeauty.Api.Tests;
public sealed class FinanceFollowupTests
{
    private static async Task<Klcn021HealthBeautyContext> Db(decimal price=100m)
    {
        var db=new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.Add(new Khachhang{KhachHangId=1,TaiKhoanId=1,HoTen="Customer",DiemThuong=500});
        db.Dichvus.Add(new Dichvu{DichVuId=1,TenDichVu="Service",Gia=price,ThoiLuongPhut=30,TrangThai=true});
        db.Lichhens.Add(new Lichhen{LichHenId=1,KhachHangId=1,NgayGioHen=DateTime.Today.AddDays(-1),TrangThai="HoanThanh",Chitietlichhens=[new Chitietlichhen{ChiTietLichHenId=1,DichVuId=1,GiaDuKien=price}]});
        db.Khuyenmais.Add(new Khuyenmai{KhuyenMaiId=1,TenKhuyenMai="Offer",LoaiGiam="SoTien",MucGiam=50m});
        db.Vouchers.Add(new Voucher{VoucherId=1,MaCode="OFFER",KhuyenMaiId=1,GiaTriGiam=50m,HanSuDung=DateTime.Now.AddDays(10),TrangThai=true});
        await db.SaveChangesAsync();db.ChangeTracker.Clear();return db;
    }
    private static T User<T>(T c,string role="Customer") where T:ControllerBase
    {
        c.ControllerContext=new ControllerContext{HttpContext=new DefaultHttpContext{User=new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier,"1"),new Claim(ClaimTypes.Role,role)],"Test"))}};return c;
    }
    [Theory][InlineData(100,400,0)][InlineData(100.5,400,0.5)]
    public async Task RedeemDeductsOnlyWholePointsAppliedAndLinksInvoice(decimal price,int balance,decimal total)
    {
        await using var db=await Db(price);
        Assert.IsType<CreatedAtActionResult>(await User(new InvoicesController(db)).Create(new CreateInvoiceRequest(1,[new(1,null,1)],null,200),default));
        Assert.Equal(balance,(await db.Khachhangs.SingleAsync()).DiemThuong);
        var invoice=await db.Hoadons.SingleAsync();Assert.Equal(total,invoice.TongTienSauGiam);
        var ledger=await db.Giaodichdiems.SingleAsync();Assert.Equal(-100,ledger.SoDiem);Assert.Equal(invoice.HoaDonId,ledger.HoaDonId);
    }
    [Fact] public async Task ZeroInvoiceCanBeSettledOnceWithoutZeroPaymentRecord()
    {
        await using var db=await Db();
        var controller=User(new InvoicesController(db));
        await controller.Create(new CreateInvoiceRequest(1,[new(1,null,1)],null,100),default);
        var invoice=await db.Hoadons.SingleAsync();
        var result=Assert.IsType<OkObjectResult>(await User(controller,"Reception").Pay(invoice.HoaDonId,new PaymentRequest("TienMat"),default));
        Assert.False(JsonSerializer.SerializeToElement(result.Value).GetProperty("PaymentRequired").GetBoolean());
        Assert.Equal("DaThanhToan",invoice.TrangThai);Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.IsType<ConflictObjectResult>(await controller.Pay(invoice.HoaDonId,new PaymentRequest("TienMat"),default));
        Assert.Single(await db.Giaodichdiems.ToListAsync());
    }
    [Fact] public async Task VoucherCodeNormalizationMatchesValidationAndInvoice()
    {
        await using var db=await Db();
        Assert.IsType<OkObjectResult>(await User(new PromotionsController(db)).ValidateVoucher(" offer ",default));
        Assert.IsType<CreatedAtActionResult>(await User(new InvoicesController(db)).Create(new CreateInvoiceRequest(1,[new(1,null,1)]," offer "),default));
        Assert.Equal(50m,(await db.Hoadons.SingleAsync()).TongTienSauGiam);
    }
    [Theory][InlineData("Bogus",5)][InlineData("PhanTram",101)][InlineData("SoTien",-1)]
    public async Task PromotionRejectsUnsupportedOrOutOfRangeDiscount(string type,decimal discount)
    {
        await using var db=await Db();
        Assert.IsType<BadRequestObjectResult>(await new PromotionsController(db).Create(new PromotionRequest("Invalid",type,discount,null,null,null),default));
        Assert.IsType<BadRequestObjectResult>(await new PromotionsController(db).Update(1,new PromotionRequest("Invalid",type,discount,null,null,null),default));
        Assert.Equal(1,await db.Khuyenmais.CountAsync());
    }
    [Theory][InlineData(999,null,10)][InlineData(1,999,10)][InlineData(1,null,-1)]
    public async Task VoucherUpdateValidatesForeignKeysAndExpiry(int promotionId,int? customerId,int days)
    {
        await using var db=await Db();
        Assert.IsType<BadRequestObjectResult>(await new PromotionsController(db).UpdateVoucher(1,new VoucherRequest("CHANGED",promotionId,customerId,50,DateTime.Now.AddDays(days)),default));
        Assert.Equal("OFFER",(await db.Vouchers.SingleAsync()).MaCode);
    }
    [Fact] public async Task VoucherUpdateRejectsDuplicateNormalizedCode()
    {
        await using var db=await Db();
        db.Vouchers.Add(new Voucher{VoucherId=2,MaCode="OTHER",KhuyenMaiId=1,GiaTriGiam=10,HanSuDung=DateTime.Now.AddDays(5),TrangThai=true});await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await new PromotionsController(db).UpdateVoucher(1,new VoucherRequest(" other ",1,null,50,DateTime.Now.AddDays(5)),default));
        Assert.Equal("OFFER",(await db.Vouchers.FindAsync(1))!.MaCode);
    }
    [Fact] public async Task CannotDeletePromotionReferencedByInactiveVoucher()
    {
        await using var db=await Db();(await db.Vouchers.SingleAsync()).TrangThai=false;await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await new PromotionsController(db).Delete(1,default));
        Assert.Single(await db.Khuyenmais.ToListAsync());
    }
    [Fact] public async Task FailedInvoiceDoesNotConsumeVoucherOrPoints()
    {
        await using var db=await Db();
        Assert.IsType<BadRequestObjectResult>(await User(new InvoicesController(db)).Create(new CreateInvoiceRequest(1,[new(1,null,1)],"OFFER",600),default));
        db.ChangeTracker.Clear();Assert.True((await db.Vouchers.SingleAsync()).TrangThai);Assert.Equal(500,(await db.Khachhangs.SingleAsync()).DiemThuong);Assert.Empty(await db.Hoadons.ToListAsync());
    }
    [Fact] public async Task LegacyWhitespacePercentageUsesPercentageCalculation()
    {
        await using var db=await Db(200m);var promotion=await db.Khuyenmais.SingleAsync();promotion.LoaiGiam=" PhanTram ";promotion.MucGiam=10;await db.SaveChangesAsync();
        Assert.IsType<CreatedAtActionResult>(await User(new InvoicesController(db)).Create(new CreateInvoiceRequest(1,[new(1,null,1)],"OFFER"),default));
        Assert.Equal(180m,(await db.Hoadons.SingleAsync()).TongTienSauGiam);
    }
    [Fact] public async Task CustomerVoucherListHidesNotYetEffectiveAndInvalidPromotions()
    {
        await using var db=await Db();var promotion=await db.Khuyenmais.SingleAsync();promotion.NgayBatDauHieuLuc=DateTime.Now.AddDays(2);await db.SaveChangesAsync();
        var c=User(new CustomerVouchersController(db));var result=Assert.IsType<OkObjectResult>(await c.List(default));Assert.Empty((System.Collections.IEnumerable)result.Value!);
        promotion.NgayBatDauHieuLuc=null;promotion.LoaiGiam="BadType";await db.SaveChangesAsync();result=Assert.IsType<OkObjectResult>(await c.List(default));Assert.Empty((System.Collections.IEnumerable)result.Value!);
    }
    [Fact] public async Task PendingModerationIsSeparateFromPublicVisibleReviews()
    {
        await using var db=await Db();db.Hoadons.Add(new Hoadon{HoaDonId=1,LichHenId=1,KhachHangId=1,TrangThai="DaThanhToan"});db.Danhgia.Add(new Danhgium{DanhGiaId=1,HoaDonId=1,SoSao=5,TrangThai="ChoDuyet"});await db.SaveChangesAsync();
        var controller=User(new ReviewsController(db),"Admin");
        var publicReviews = JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await controller.List(null,default)).Value);
        Assert.Equal(0, publicReviews.GetProperty("totalReviews").GetInt32());
        Assert.Empty(publicReviews.GetProperty("items").EnumerateArray());
        Assert.Single((System.Collections.IEnumerable)Assert.IsType<OkObjectResult>(await controller.Pending(default)).Value!);
    }

}
