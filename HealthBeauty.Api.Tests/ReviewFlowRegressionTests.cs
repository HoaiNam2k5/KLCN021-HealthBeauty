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

public sealed class ReviewFlowRegressionTests
{
    private static async Task<Klcn021HealthBeautyContext> Database(string appointmentStatus = "HoanThanh", string invoiceStatus = "DaThanhToan")
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Customer One" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Customer Two" });
        db.Dichvus.AddRange(new Dichvu { DichVuId = 1, TenDichVu = "Direct service" }, new Dichvu { DichVuId = 2, TenDichVu = "Combo service" });
        db.Combodichvus.Add(new Combodichvu { ComboId = 1, TenCombo = "Combo", Chitietcombos = [new Chitietcombo { DichVuId = 2, SoLuong = 1 }] });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NgayGioHen = DateTime.Today, TrangThai = appointmentStatus });
        db.Hoadons.Add(new Hoadon { HoaDonId = 1, LichHenId = 1, KhachHangId = 1, NgayLap = DateTime.Today, TrangThai = invoiceStatus,
            Chitiethoadons = [new Chitiethoadon { DichVuId = 1, SoLuong = 1 }, new Chitiethoadon { ComboId = 1, SoLuong = 1 }] });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }

    private static T AsUser<T>(T controller, int accountId = 1) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, "Customer")], "Test")) } };
        return controller;
    }

    private static JsonElement Json(object? value) => JsonSerializer.SerializeToElement(value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
    private static async Task<JsonElement> Mine(Klcn021HealthBeautyContext db) => Json(Assert.IsType<OkObjectResult>(
        await AsUser(new AppointmentsController(db)).GetMine(null, null, null, null, null)).Value).GetProperty("items")[0];

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    public async Task PublicReviewsIncludeCustomerAndFilterDirectServicesAndCombos(int serviceId)
    {
        await using var db = await Database();
        db.Hoadons.Add(new Hoadon { HoaDonId = 2, LichHenId = 1, KhachHangId = 1, TrangThai = "DaThanhToan",
            Chitiethoadons = [new Chitiethoadon { DichVuId = 1, SoLuong = 1 }, new Chitiethoadon { ComboId = 1, SoLuong = 1 }] });
        db.Danhgia.AddRange(new Danhgium { HoaDonId = 1, SoSao = 4, TrangThai = "HienThi" },
            new Danhgium { HoaDonId = 2, SoSao = 1, TrangThai = "An" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var json = Json(Assert.IsType<OkObjectResult>(await new ReviewsController(db).List(serviceId, default)).Value);
        Assert.Equal(1, json.GetProperty("totalReviews").GetInt32());
        Assert.Equal(4, json.GetProperty("averageRating").GetDouble());
        var review = Assert.Single(json.GetProperty("items").EnumerateArray());
        Assert.Equal("Customer One", review.GetProperty("tenKhachHang").GetString());
        var empty = Json(Assert.IsType<OkObjectResult>(await new ReviewsController(db).List(999, default)).Value);
        Assert.Equal(0, empty.GetProperty("totalReviews").GetInt32()); Assert.Equal(0, empty.GetProperty("averageRating").GetDouble());
    }

    [Fact]
    public async Task StatisticsIncludeAllVisibleReviewsBeforeLimitingItems()
    {
        await using var db = await Database();
        for (var i = 1; i <= 250; i++)
        {
            db.Hoadons.Add(new Hoadon { HoaDonId = i + 1, LichHenId = 1, KhachHangId = 1, TrangThai = "DaThanhToan" });
            db.Danhgia.Add(new Danhgium { HoaDonId = i + 1, SoSao = (byte)(i <= 50 ? 1 : 5), TrangThai = "HienThi", NgayDanhGia = DateTime.Today.AddMinutes(i) });
        }
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var json = Json(Assert.IsType<OkObjectResult>(await new ReviewsController(db).List(null, default)).Value);
        Assert.Equal(250, json.GetProperty("totalReviews").GetInt32());
        Assert.Equal(4.2, json.GetProperty("averageRating").GetDouble());
        Assert.Equal(200, json.GetProperty("items").GetArrayLength());
        Assert.Equal(251, json.GetProperty("items")[0].GetProperty("hoaDonId").GetInt32());
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PaidInvoiceReviewIsVisibleImmediatelyAndCannotBeSubmittedTwice(bool viaAppointment)
    {
        await using var db = await Database(); var controller = AsUser(new ReviewsController(db));
        var result = viaAppointment ? await controller.CreateForAppointment(1, new ReviewRequest(5, "  Great  "), default)
            : await controller.Create(1, new ReviewRequest(5, "  Great  "), default);
        Assert.IsType<CreatedResult>(result);
        var stored = await db.Danhgia.SingleAsync(); Assert.Equal("HienThi", stored.TrangThai); Assert.Equal("Great", stored.BinhLuan);
        db.ChangeTracker.Clear();
        var publicJson = Json(Assert.IsType<OkObjectResult>(await controller.List(1, default)).Value);
        Assert.Equal(1, publicJson.GetProperty("totalReviews").GetInt32());
        Assert.IsType<ConflictObjectResult>(await controller.Create(1, new ReviewRequest(4, null), default));
        Assert.IsType<ConflictObjectResult>(await controller.CreateForAppointment(1, new ReviewRequest(4, null), default));
        Assert.Single(await db.Danhgia.ToListAsync());
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task AnotherCustomerCannotReviewInvoiceOrAppointment(bool viaAppointment)
    {
        await using var db = await Database(); var controller = AsUser(new ReviewsController(db), 2);
        var result = viaAppointment ? await controller.CreateForAppointment(1, new ReviewRequest(5, null), default)
            : await controller.Create(1, new ReviewRequest(5, null), default);
        Assert.IsAssignableFrom<StatusCodeResult>(result); Assert.Equal(404, ((StatusCodeResult)result).StatusCode);
        Assert.Empty(await db.Danhgia.ToListAsync());
    }

    [Theory]
    [InlineData("ChuaThanhToan")]
    [InlineData("DaHuy")]
    public async Task UnpaidInvoiceCannotBeReviewed(string status)
    {
        await using var db = await Database(invoiceStatus: status); var controller = AsUser(new ReviewsController(db));
        Assert.IsType<BadRequestObjectResult>(await controller.Create(1, new ReviewRequest(5, null), default));
        Assert.IsType<BadRequestObjectResult>(await controller.CreateForAppointment(1, new ReviewRequest(5, null), default));
        Assert.Empty(await db.Danhgia.ToListAsync());
    }

    [Theory]
    [InlineData("ChoXacNhan")]
    [InlineData("DangThucHien")]
    [InlineData("DaHuy")]
    public async Task AppointmentReviewRequiresCompletedAppointment(string status)
    {
        await using var db = await Database(appointmentStatus: status);
        Assert.IsType<BadRequestObjectResult>(await AsUser(new ReviewsController(db)).CreateForAppointment(1, new ReviewRequest(5, null), default));
        Assert.Empty(await db.Danhgia.ToListAsync());
    }

    [Fact]
    public async Task AppointmentMetadataRetainsHiddenReviewAndMissingInvoiceDefaults()
    {
        await using var db = await Database();
        db.Danhgia.Add(new Danhgium { HoaDonId = 1, SoSao = 3, TrangThai = "An" }); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var item = await Mine(db); Assert.Equal(1, item.GetProperty("invoiceId").GetInt32());
        Assert.Equal("DaThanhToan", item.GetProperty("invoiceStatus").GetString());
        Assert.True(item.GetProperty("hasReviewed").GetBoolean()); Assert.Equal(3, item.GetProperty("reviewStars").GetInt32());
        db.Danhgia.RemoveRange(db.Danhgia); db.Hoadons.RemoveRange(db.Hoadons); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        item = await Mine(db); Assert.Equal(JsonValueKind.Null, item.GetProperty("invoiceId").ValueKind);
        Assert.Equal(JsonValueKind.Null, item.GetProperty("invoiceStatus").ValueKind); Assert.False(item.GetProperty("hasReviewed").GetBoolean());
        Assert.Equal(JsonValueKind.Null, item.GetProperty("reviewStars").ValueKind);
    }

    [Fact]
    public async Task LatestInvoiceUsesIdTieBreakerAndDoesNotFallBackToOlderPaidInvoice()
    {
        await using var db = await Database();
        db.Hoadons.Add(new Hoadon { HoaDonId = 2, LichHenId = 1, KhachHangId = 1, NgayLap = DateTime.Today, TrangThai = "ChuaThanhToan" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var item = await Mine(db); Assert.Equal(2, item.GetProperty("invoiceId").GetInt32());
        Assert.Equal("ChuaThanhToan", item.GetProperty("invoiceStatus").GetString()); Assert.False(item.GetProperty("hasReviewed").GetBoolean());
        Assert.IsType<BadRequestObjectResult>(await AsUser(new ReviewsController(db)).CreateForAppointment(1, new ReviewRequest(5, null), default));
        Assert.Empty(await db.Danhgia.ToListAsync());
    }
}
