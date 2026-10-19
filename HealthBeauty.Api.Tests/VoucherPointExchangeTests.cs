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

public sealed class VoucherPointExchangeTests
{
    private static async Task<Klcn021HealthBeautyContext> Db()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "First", DiemThuong = 500 },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Second", DiemThuong = 500 });
        db.Khuyenmais.Add(new Khuyenmai { KhuyenMaiId = 1, TenKhuyenMai = "Offer", LoaiGiam = "SoTien", MucGiam = 50000 });
        db.Vouchers.Add(new Voucher { VoucherId = 1, MaCode = "SECRET", KhuyenMaiId = 1, GiaTriGiam = 50000, PointsCost = 100,
            HanSuDung = DateTime.Now.AddDays(10), TrangThai = true });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static T User<T>(T controller, int id = 1) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
            new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, "Customer") }, "Test")) } }; return controller;
    }
    private static JsonElement Json(object? value) => JsonSerializer.SerializeToElement(value, new JsonSerializerOptions(JsonSerializerDefaults.Web));

    [Fact]
    public async Task OffersRedactCodesAndUnclaimedPaidVouchersCannotBeUsedOrShownInWallet()
    {
        await using var db = await Db();
        var offer = Assert.Single(Json(Assert.IsType<OkObjectResult>(await User(new VoucherRedemptionController(db)).ListOffers(default)).Value).EnumerateArray());
        Assert.Equal(100, offer.GetProperty("pointsCost").GetInt32());
        Assert.False(offer.TryGetProperty("code", out _)); Assert.False(offer.TryGetProperty("maCode", out _));
        Assert.DoesNotContain("SECRET", offer.GetRawText());
        Assert.Null(await VoucherRules.FindApplicableAsync(db, "SECRET", 1, default));
        Assert.IsType<NotFoundObjectResult>(await User(new PromotionsController(db)).ValidateVoucher("SECRET", default));
        Assert.Empty(Json(Assert.IsType<OkObjectResult>(await User(new CustomerVouchersController(db)).List(default)).Value).EnumerateArray());
    }

    [Fact]
    public async Task ExchangeChargesOnceAndLinksLedgerAndOwnerWallet()
    {
        await using var db = await Db(); var controller = User(new VoucherRedemptionController(db));
        var result = Json(Assert.IsType<OkObjectResult>(await controller.Redeem(1, default)).Value);
        Assert.Equal("SECRET", result.GetProperty("code").GetString()); Assert.Equal(100, result.GetProperty("pointsSpent").GetInt32());
        Assert.Equal(400, result.GetProperty("remainingPoints").GetInt32());
        var voucher = await db.Vouchers.SingleAsync(); Assert.Equal(1, voucher.KhachHangId); Assert.NotNull(voucher.RedeemedAt);
        var ledger = await db.Giaodichdiems.SingleAsync(); Assert.Equal(-100, ledger.SoDiem); Assert.Equal("DoiVoucher", ledger.LoaiGiaoDich); Assert.Equal(1, ledger.VoucherId); Assert.Null(ledger.HoaDonId);
        Assert.IsType<ConflictObjectResult>(await controller.Redeem(1, default));
        Assert.IsType<ConflictObjectResult>(await User(new VoucherRedemptionController(db), 2).Redeem(1, default));
        Assert.Single(await db.Giaodichdiems.ToListAsync()); Assert.Equal(400, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.NotNull(await VoucherRules.FindApplicableAsync(db, "SECRET", 1, default)); Assert.Null(await VoucherRules.FindApplicableAsync(db, "SECRET", 2, default));
        Assert.Single(Json(Assert.IsType<OkObjectResult>(await User(new CustomerVouchersController(db)).List(default)).Value).EnumerateArray());
        Assert.Empty(Json(Assert.IsType<OkObjectResult>(await User(new CustomerVouchersController(db), 2).List(default)).Value).EnumerateArray());
        Assert.Empty(Json(Assert.IsType<OkObjectResult>(await controller.ListOffers(default)).Value).EnumerateArray());
        var history = Json(Assert.IsType<OkObjectResult>(await new CustomersController(db).PointHistory(1)).Value);
        Assert.Equal(1, Assert.Single(history.GetProperty("transactions").EnumerateArray()).GetProperty("voucherId").GetInt32());
    }

    [Fact]
    public async Task InsufficientBalanceDoesNotAssignVoucherOrCreateLedger()
    {
        await using var db = await Db(); (await db.Khachhangs.FindAsync(1))!.DiemThuong = 99; await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>(await User(new VoucherRedemptionController(db)).Redeem(1, default));
        Assert.Null((await db.Vouchers.SingleAsync()).KhachHangId); Assert.Empty(await db.Giaodichdiems.ToListAsync());
    }

    [Theory]
    [InlineData("expired")]
    [InlineData("inactive")]
    [InlineData("future-promotion")]
    [InlineData("expired-promotion")]
    [InlineData("invalid-discount")]
    [InlineData("free")]
    public async Task UnavailableOffersCannotBeRedeemed(string reason)
    {
        await using var db = await Db(); var voucher = await db.Vouchers.SingleAsync(); var promotion = await db.Khuyenmais.SingleAsync();
        if (reason == "expired") voucher.HanSuDung = DateTime.Now.AddDays(-1);
        if (reason == "inactive") voucher.TrangThai = false;
        if (reason == "future-promotion") promotion.NgayBatDauHieuLuc = DateTime.Now.AddDays(1);
        if (reason == "expired-promotion") promotion.NgayKetThucHieuLuc = DateTime.Now.AddDays(-1);
        if (reason == "invalid-discount") promotion.LoaiGiam = "Unknown";
        if (reason == "free") voucher.PointsCost = 0;
        await db.SaveChangesAsync();
        Assert.Empty(Json(Assert.IsType<OkObjectResult>(await User(new VoucherRedemptionController(db)).ListOffers(default)).Value).EnumerateArray());
        Assert.IsType<NotFoundResult>(await User(new VoucherRedemptionController(db)).Redeem(1, default));
        Assert.Empty(await db.Giaodichdiems.ToListAsync()); Assert.Equal(500, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
    }

    [Fact]
    public async Task ProfileIsRequiredAndMissingVoucherReturns404()
    {
        await using var db = await Db();
        Assert.IsType<ForbidResult>(await User(new VoucherRedemptionController(db), 99).ListOffers(default));
        Assert.IsType<ForbidResult>(await User(new VoucherRedemptionController(db), 99).Redeem(1, default));
        Assert.IsType<NotFoundResult>(await User(new VoucherRedemptionController(db)).Redeem(99, default));
    }

    [Theory]
    [InlineData(-1, null)]
    [InlineData(1000001, null)]
    [InlineData(100, 1)]
    public async Task ManagementCannotCreateInvalidCostOrAssignUnredeemedPaidVoucher(int cost, int? customer)
    {
        await using var db = await Db();
        Assert.IsType<BadRequestObjectResult>(await new PromotionsController(db).CreateVoucher(new VoucherRequest("NEW", 1, customer, 50000, DateTime.Now.AddDays(5), cost), default));
        Assert.Single(await db.Vouchers.ToListAsync());
    }

    [Fact]
    public async Task ConfigurableCostReturnedAndClaimedCostOwnershipCannotBeRewritten()
    {
        await using var db = await Db(); var admin = new PromotionsController(db);
        Assert.IsType<OkObjectResult>(await admin.UpdateVoucher(1, new VoucherRequest("SECRET", 1, null, 50000, DateTime.Now.AddDays(10), 250), default));
        await User(new VoucherRedemptionController(db)).Redeem(1, default);
        Assert.IsType<ConflictObjectResult>(await admin.UpdateVoucher(1, new VoucherRequest("SECRET", 1, 2, 50000, DateTime.Now.AddDays(10), 250), default));
        Assert.IsType<ConflictObjectResult>(await admin.UpdateVoucher(1, new VoucherRequest("SECRET", 1, 1, 50000, DateTime.Now.AddDays(10), 0), default));
        Assert.IsType<OkObjectResult>(await admin.UpdateVoucher(1, new VoucherRequest("SECRET", 1, 1, 50000, DateTime.Now.AddDays(10), 250), default));
        Assert.Equal(250, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
    }

    [Fact]
    public async Task ApplyingRedeemedVoucherDiscountsInvoiceWithoutChargingExchangeCostAgain()
    {
        await using var db = await Db();
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Service", Gia = 100000, ThoiLuongPhut = 30, TrangThai = true });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NgayGioHen = DateTime.Now.AddDays(-1), TrangThai = "HoanThanh",
            Chitietlichhens = new List<Chitietlichhen> { new() { ChiTietLichHenId = 1, DichVuId = 1, GiaDuKien = 100000 } } });
        await db.SaveChangesAsync(); var invoices = User(new InvoicesController(db));
        Assert.IsType<BadRequestObjectResult>(await invoices.Create(new CreateInvoiceRequest(1, new List<InvoiceLineRequest> { new(1, null, 1) }, "SECRET"), default));
        await User(new VoucherRedemptionController(db)).Redeem(1, default);
        Assert.IsType<CreatedAtActionResult>(await invoices.Create(new CreateInvoiceRequest(1, new List<InvoiceLineRequest> { new(1, null, 1) }, "SECRET"), default));
        Assert.Equal(50000, (await db.Hoadons.SingleAsync()).TongTienSauGiam);
        Assert.Equal(400, (await db.Khachhangs.FindAsync(1))!.DiemThuong); Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.False((await db.Vouchers.SingleAsync()).TrangThai);
        Assert.NotNull((await db.Vouchers.SingleAsync()).UsedAt);
        Assert.IsType<ConflictObjectResult>(await new PromotionsController(db).VoucherStatus(1, true, default));
        Assert.False((await db.Vouchers.SingleAsync()).TrangThai);
        db.Lichhens.Add(new Lichhen { LichHenId = 2, KhachHangId = 1, NgayGioHen = DateTime.Now.AddDays(-1), TrangThai = "HoanThanh",
            Chitietlichhens = new List<Chitietlichhen> { new() { ChiTietLichHenId = 2, DichVuId = 1, GiaDuKien = 100000 } } });
        await db.SaveChangesAsync();
        Assert.IsType<BadRequestObjectResult>(await invoices.Create(new CreateInvoiceRequest(2, new List<InvoiceLineRequest> { new(1, null, 1) }, "SECRET"), default));
        Assert.Single(await db.Hoadons.ToListAsync()); Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.Null(await VoucherRules.FindApplicableAsync(db, "SECRET", 1, default));
    }
}
