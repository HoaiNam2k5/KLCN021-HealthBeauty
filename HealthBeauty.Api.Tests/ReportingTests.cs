using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;
public sealed class ReportingTests
{
    private static JsonElement Json(IActionResult result) => JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(result).Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
    private static async Task<Klcn021HealthBeautyContext> Seed()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var customer = new Khachhang { KhachHangId = 1, HoTen = "Alice", CreatedAt = new(2026, 1, 1) };
        db.Khachhangs.AddRange(customer, new Khachhang { KhachHangId = 2, HoTen = "Legacy" });
        var category = new Loaidichvu { LoaiDichVuId = 1, TenLoai = "Care" };
        var service = new Dichvu { DichVuId = 1, LoaiDichVu = category, TenDichVu = "Same", Gia = 100 };
        var combo = new Combodichvu { ComboId = 1, TenCombo = "Same" };
        var combo2 = new Combodichvu { ComboId = 2, TenCombo = "Same" };
        db.Dichvus.Add(service); db.Combodichvus.AddRange(combo, combo2);
        for (int i = 1; i <= 3; i++)
        {
            var appointment = new Lichhen { LichHenId = i, KhachHang = customer, NgayGioHen = new(2026, 1, i), TrangThai = i == 3 ? "DaHuy" : "HoanThanh" };
            db.Hoadons.Add(new Hoadon { HoaDonId = i, LichHen = appointment, KhachHang = customer, NgayLap = new(2026, 1, i), TrangThai = i == 3 ? "ChuaThanhToan" : "DaThanhToan", TongTienTruocGiam = 300, TongTienSauGiam = 250,
                Chitiethoadons = [new Chitiethoadon { DichVu = service, SoLuong = 1, DonGia = 100 }, new Chitiethoadon { Combo = i == 2 ? combo2 : combo, SoLuong = 1, DonGia = 200 }] });
        }
        await db.SaveChangesAsync(); return db;
    }
    [Theory]
    [InlineData("2026-01-04", "week", "2025-12-29")]
    [InlineData("2026-01-05", "week", "2026-01-05")]
    [InlineData("2025-12-31", "quarter", "2025-10-01")]
    [InlineData("2026-01-01", "quarter", "2026-01-01")]
    [InlineData("2026-07-04", "year", "2026-01-01")]
    public void PeriodBoundaries(string input, string group, string expected) => Assert.Equal(DateTime.Parse(expected), ReportsController.ReportPeriod(DateTime.Parse(input), group));
    [Fact] public async Task AppointmentsExclusiveEndAndStatus()
    {
        await using var db = await Seed(); var api = new ReportsController(db);
        var json = Json(await api.AppointmentSummary(new() { From = new(2026, 1, 1), To = new(2026, 1, 3), GroupBy = "status" }, default));
        Assert.Equal(2, json.GetProperty("totalCount").GetInt32()); Assert.Single(json.GetProperty("items").EnumerateArray());
    }
    [Fact] public async Task OrderSummaryCountsUnpaidButRevenueOnlyPaid()
    {
        await using var db = await Seed(); var json = Json(await new ReportsController(db).OrderSummary(new(), default));
        Assert.Equal(3, json.GetProperty("totalCount").GetInt32()); Assert.Equal(500, json.GetProperty("paidRevenue").GetDecimal());
        Assert.Equal(1, json.GetProperty("items")[0].GetProperty("unpaidInvoiceCount").GetInt32());
    }
    [Fact] public async Task OrdersPaginationSummaryDoesNotDependOnPage()
    {
        await using var db = await Seed(); var json = Json(await new ReportsController(db).Orders(new() { Page = 2, PageSize = 1, Search = "Alice" }, default));
        Assert.Equal(3, json.GetProperty("totalCount").GetInt32()); Assert.Equal(500, json.GetProperty("paidRevenue").GetDecimal());
        Assert.Equal(2, json.GetProperty("items")[0].GetProperty("id").GetInt32());
    }
    [Fact] public async Task BreakdownStaffDoesNotMultiplyInvoiceTotal()
    {
        await using var db = await Seed(); var json = Json(await new ReportsController(db).OrderBreakdown(new() { GroupBy = "staff" }, default));
        Assert.Equal(500, json.GetProperty("items")[0].GetProperty("paidRevenue").GetDecimal());
        Assert.Equal(3, json.GetProperty("items")[0].GetProperty("invoiceCount").GetInt32());
    }
    [Fact] public async Task CategorySeparatesComboGrossWithoutFakeAllocation()
    {
        await using var db = await Seed(); var json = Json(await new ReportsController(db).OrderBreakdown(new() { GroupBy = "category" }, default));
        var items = json.GetProperty("items").EnumerateArray().ToArray(); Assert.Equal(2, items.Length);
        Assert.Equal(900, items.Sum(x => x.GetProperty("grossAmount").GetDecimal()));
        Assert.Contains(items, x => x.GetProperty("kind").GetString() == "comboUnallocated");
    }
    [Fact] public async Task SameNamedCombosRemainDistinct()
    {
        await using var db = await Seed(); var json = Json(await new ReportsController(db).OrderBreakdown(new() { GroupBy = "combo" }, default));
        Assert.Equal(2, json.GetProperty("items").GetArrayLength());
        var legacy = Json(await new ReportsController(db).Services(default)); Assert.Equal(3, legacy.GetArrayLength());
    }
    [Fact] public async Task NewCustomersDisclosesUnknownLegacyAndExclusiveEnd()
    {
        await using var db = await Seed(); var json = Json(await new ReportsController(db).NewCustomers(new() { To = new(2026, 1, 1) }, default));
        Assert.Equal(0, json.GetProperty("totalCount").GetInt32()); Assert.Equal(1, json.GetProperty("unknownHistoricalCount").GetInt32());
    }
    [Fact] public async Task RejectInvalidFiltersAndExportReport()
    {
        await using var db = await Seed(); var api = new ReportsController(db);
        Assert.IsType<BadRequestObjectResult>(await api.Orders(new() { Page = int.MaxValue }, default));
        Assert.IsType<BadRequestObjectResult>(await api.OrderSummary(new() { GroupBy = "status" }, default));
        Assert.IsType<BadRequestObjectResult>(await api.AppointmentSummary(new() { Status = "invalid" }, default));
        Assert.IsType<BadRequestObjectResult>(await api.NewCustomers(new() { From = DateTime.Today, To = DateTime.Today }, default));
        Assert.IsType<BadRequestObjectResult>(await api.Export("invalid", new(), default));
    }
    [Theory] [InlineData("appointments", "month")] [InlineData("orders", "quarter")] [InlineData("breakdown", "staff")] [InlineData("breakdown", "category")] [InlineData("new-customers", "month")]
    public async Task ExportsValidXlsx(string report, string group)
    {
        await using var db = await Seed(); var result = Assert.IsType<FileContentResult>(await new ReportsController(db).Export(report, new() { GroupBy = group }, default));
        Assert.Equal("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", result.ContentType);
        using var zip = new System.IO.Compression.ZipArchive(new MemoryStream(result.FileContents)); Assert.NotNull(zip.GetEntry("xl/worksheets/sheet1.xml"));
    }
}
