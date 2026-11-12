using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ServiceCatalogStatisticsTests
{
    [Theory]
    [InlineData("ReviewStatistics", "AVG(")]
    [InlineData("BookingStatistics", "COUNT(")]
    public void AggregateQueriesTranslateToSqlServerWithoutOpeningAConnection(string builder, string aggregate)
    {
        // Compile the exact production query shape using SQL Server's provider,
        // not the InMemory translator. ToQueryString performs no database I/O.
        using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseSqlServer("Server=unused;Database=TranslationOnly;Integrated Security=true;TrustServerCertificate=true").Options);
        var controller = new ServicesController(db);
        var method = typeof(ServicesController).GetMethod(builder,
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!;
        var query = Assert.IsAssignableFrom<IQueryable>(method.Invoke(controller, [new[] { 1, 2 }]));
        var sql = query.ToQueryString();
        Assert.Contains("UNION", sql);
        Assert.DoesNotContain("UNION ALL", sql);
        Assert.Contains("GROUP BY", sql);
        Assert.Contains(aggregate, sql);
    }

    private static Klcn021HealthBeautyContext Db() => new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static async Task Seed(Klcn021HealthBeautyContext db)
    {
        db.Loaidichvus.Add(new Loaidichvu { LoaiDichVuId = 1, TenLoai = "Care", TrangThai = true });
        db.Dichvus.AddRange(
            new Dichvu { DichVuId = 1, LoaiDichVuId = 1, TenDichVu = "First", TrangThai = true },
            new Dichvu { DichVuId = 2, LoaiDichVuId = 1, TenDichVu = "Second", TrangThai = true },
            new Dichvu { DichVuId = 3, LoaiDichVuId = 1, TenDichVu = "Inactive", TrangThai = false },
            new Dichvu { DichVuId = 4, LoaiDichVuId = 1, TenDichVu = "Unused", TrangThai = true });
        db.Combodichvus.Add(new Combodichvu { ComboId = 10, TenCombo = "Both", TrangThai = true });
        db.Chitietcombos.AddRange(
            new Chitietcombo { ComboChiTietId = 1, ComboId = 10, DichVuId = 1, SoLuong = 2 },
            new Chitietcombo { ComboChiTietId = 2, ComboId = 10, DichVuId = 2, SoLuong = 1 });
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, HoTen = "Customer" });
        for (var id = 1; id <= 5; id++)
        {
            db.Lichhens.Add(new Lichhen { LichHenId = id, KhachHangId = 1,
                NgayGioHen = new DateTime(2026, 10, 20).AddDays(id), TrangThai = id == 3 ? "DaHuy" : "HoanThanh" });
            db.Hoadons.Add(new Hoadon { HoaDonId = id, LichHenId = id, KhachHangId = 1,
                NgayLap = new DateTime(2026, 10, 20).AddDays(id), TrangThai = "DaThanhToan" });
        }
        db.Chitietlichhens.AddRange(
            new Chitietlichhen { ChiTietLichHenId = 1, LichHenId = 1, DichVuId = 1 },
            new Chitietlichhen { ChiTietLichHenId = 2, LichHenId = 1, DichVuId = 2, ComboId = 10 },
            new Chitietlichhen { ChiTietLichHenId = 3, LichHenId = 2, DichVuId = 2 },
            new Chitietlichhen { ChiTietLichHenId = 4, LichHenId = 3, DichVuId = 1 },
            new Chitietlichhen { ChiTietLichHenId = 5, LichHenId = 4, DichVuId = 1 },
            new Chitietlichhen { ChiTietLichHenId = 6, LichHenId = 5, DichVuId = 1 });
        db.Chitiethoadons.AddRange(
            new Chitiethoadon { HoaDonChiTietId = 1, HoaDonId = 1, DichVuId = 1, SoLuong = 3 },
            new Chitiethoadon { HoaDonChiTietId = 2, HoaDonId = 1, ComboId = 10, SoLuong = 2 },
            new Chitiethoadon { HoaDonChiTietId = 3, HoaDonId = 1, DichVuId = 1, SoLuong = 1 },
            new Chitiethoadon { HoaDonChiTietId = 4, HoaDonId = 2, DichVuId = 2, SoLuong = 1 },
            new Chitiethoadon { HoaDonChiTietId = 5, HoaDonId = 3, DichVuId = 1, SoLuong = 1 },
            new Chitiethoadon { HoaDonChiTietId = 6, HoaDonId = 4, DichVuId = 1, SoLuong = 1 },
            new Chitiethoadon { HoaDonChiTietId = 7, HoaDonId = 5, DichVuId = 1, SoLuong = 1 });
        db.Danhgia.AddRange(
            new Danhgium { DanhGiaId = 1, HoaDonId = 1, SoSao = 5, TrangThai = "HienThi" },
            new Danhgium { DanhGiaId = 2, HoaDonId = 2, SoSao = 4, TrangThai = "HienThi" },
            new Danhgium { DanhGiaId = 3, HoaDonId = 3, SoSao = 1, TrangThai = "DaAn" },
            new Danhgium { DanhGiaId = 4, HoaDonId = 4, SoSao = 1, TrangThai = "HienThi", IsDeleted = true },
            new Danhgium { DanhGiaId = 5, HoaDonId = 5, SoSao = 1, TrangThai = "ChoDuyet" });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
    }

    private static async Task<ServiceResponse[]> List(Klcn021HealthBeautyContext db, string? keyword = null) =>
        Assert.IsAssignableFrom<IEnumerable<ServiceResponse>>(
            Assert.IsType<OkObjectResult>((await new ServicesController(db).Services(null, keyword, default)).Result).Value).ToArray();

    [Fact]
    public async Task CatalogContainsVisibleDistinctReviewStatisticsAndNonCancelledBookingCounts()
    {
        await using var db = Db();
        await Seed(db);
        var catalog = await List(db);
        Assert.DoesNotContain(catalog, service => service.Id == 3);
        var first = catalog.Single(service => service.Id == 1);
        var json = JsonSerializer.SerializeToElement(first, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.Equal(1, json.GetProperty("totalReviews").GetInt32());
        Assert.Equal(5d, json.GetProperty("averageRating").GetDouble());
        Assert.Equal(3, json.GetProperty("bookedCount").GetInt32());
        var second = JsonSerializer.SerializeToElement(catalog.Single(service => service.Id == 2), new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.Equal(2, second.GetProperty("totalReviews").GetInt32());
        Assert.Equal(4.5d, second.GetProperty("averageRating").GetDouble());
        Assert.Equal(2, second.GetProperty("bookedCount").GetInt32());
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(4)]
    public async Task DetailAndFilteredCatalogMatchPublicReviewEndpoint(int serviceId)
    {
        await using var db = Db();
        await Seed(db);
        var listItem = (await List(db)).Single(service => service.Id == serviceId);
        var detail = Assert.IsType<ServiceResponse>(Assert.IsType<OkObjectResult>(
            (await new ServicesController(db).GetService(serviceId, default)).Result).Value);
        Assert.Equal(listItem, detail);
        Assert.Equal(detail, Assert.Single(await List(db, detail.Name)));
        var reviewValue = Assert.IsType<OkObjectResult>(await new ReviewsController(db).List(serviceId, default)).Value;
        var reviews = JsonSerializer.SerializeToElement(reviewValue);
        var service = JsonSerializer.SerializeToElement(detail, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.Equal(reviews.GetProperty("totalReviews").GetInt32(), service.GetProperty("totalReviews").GetInt32());
        Assert.Equal(reviews.GetProperty("averageRating").GetDouble(), service.GetProperty("averageRating").GetDouble());
    }

    [Fact]
    public async Task InactiveServiceStillReturnsNotFoundAndEmptyFilterHasNoRows()
    {
        await using var db = Db();
        await Seed(db);
        Assert.IsType<NotFoundResult>((await new ServicesController(db).GetService(3, default)).Result);
        Assert.Empty(await List(db, "no-match"));
    }
}
