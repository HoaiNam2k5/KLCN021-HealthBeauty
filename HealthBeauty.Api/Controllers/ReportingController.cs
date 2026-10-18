using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace HealthBeauty.Api.Controllers;

public sealed class ReportFilter
{
    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
    public string GroupBy { get; set; } = "month";
    public string? Status { get; set; }
    public int? StaffId { get; set; }
    public int? ServiceId { get; set; }
    public int? ComboId { get; set; }
    public int? CategoryId { get; set; }
    public string? Search { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public sealed partial class ReportsController
{
    private const int SourceLimit = 100000;
    private static readonly string[] AppointmentStatuses = ["ChoXacNhan", "DaXacNhan", "DaDen", "DangThucHien", "HoanThanh", "DaHuy"];
    private static readonly string[] InvoiceStatuses = ["ChuaThanhToan", "DaThanhToan"];
    private string? Validate(ReportFilter f, params string[] groups)
    {
        if (f.From.HasValue && f.To.HasValue && (f.From >= f.To || (f.To.Value - f.From.Value).TotalDays > 3660)) return "from must be before exclusive to.";
        if (groups.Length > 0 && !groups.Contains(f.GroupBy)) return "Invalid groupBy.";
        if (f.Page < 1 || f.Page > 1000000 || f.PageSize < 1 || f.PageSize > 100) return "page >= 1; pageSize 1..100.";
        if (f.Search?.Length > 200 || new[] { f.StaffId, f.ServiceId, f.ComboId, f.CategoryId }.Any(x => x <= 0)) return "Invalid filter.";
        return null;
    }
    public static DateTime ReportPeriod(DateTime date, string group) => group switch
    {
        "day" => date.Date,
        "week" => date.Date.AddDays(-((int)date.DayOfWeek + 6) % 7),
        "month" => new(date.Year, date.Month, 1),
        "quarter" => new(date.Year, ((date.Month - 1) / 3) * 3 + 1, 1),
        "year" => new(date.Year, 1, 1),
        _ => throw new ArgumentException("Invalid period")
    };
    private IQueryable<Lichhen> AppointmentQuery(ReportFilter f)
    {
        var q = db.Lichhens.AsNoTracking();
        if (f.From.HasValue) q = q.Where(x => x.NgayGioHen >= f.From.Value);
        if (f.To.HasValue) q = q.Where(x => x.NgayGioHen < f.To.Value);
        if (f.Status != null) q = q.Where(x => x.TrangThai == f.Status);
        if (f.StaffId.HasValue) q = q.Where(x => x.NhanVienId == f.StaffId);
        if (f.ServiceId.HasValue) q = q.Where(x => x.Chitietlichhens.Any(l => l.DichVuId == f.ServiceId));
        if (f.ComboId.HasValue) q = q.Where(x => x.Chitietlichhens.Any(l => l.ComboId == f.ComboId));
        if (f.CategoryId.HasValue) q = q.Where(x => x.Chitietlichhens.Any(l => l.DichVu != null && l.DichVu.LoaiDichVuId == f.CategoryId));
        if (!string.IsNullOrWhiteSpace(f.Search)) q = q.Where(x => x.KhachHang.HoTen.Contains(f.Search) || (x.KhachHang.SoDienThoai != null && x.KhachHang.SoDienThoai.Contains(f.Search)));
        return q;
    }
    private IQueryable<Hoadon> OrderQuery(ReportFilter f)
    {
        var q = db.Hoadons.AsNoTracking();
        if (f.From.HasValue) q = q.Where(x => x.NgayLap >= f.From.Value);
        if (f.To.HasValue) q = q.Where(x => x.NgayLap < f.To.Value);
        if (f.Status != null) q = q.Where(x => x.TrangThai == f.Status);
        if (f.StaffId.HasValue) q = q.Where(x => x.LichHen.NhanVienId == f.StaffId);
        if (f.ServiceId.HasValue) q = q.Where(x => x.Chitiethoadons.Any(l => l.DichVuId == f.ServiceId));
        if (f.ComboId.HasValue) q = q.Where(x => x.Chitiethoadons.Any(l => l.ComboId == f.ComboId));
        if (f.CategoryId.HasValue) q = q.Where(x => x.Chitiethoadons.Any(l => l.DichVu != null && l.DichVu.LoaiDichVuId == f.CategoryId));
        if (!string.IsNullOrWhiteSpace(f.Search)) q = q.Where(x => x.KhachHang.HoTen.Contains(f.Search) || (x.KhachHang.SoDienThoai != null && x.KhachHang.SoDienThoai.Contains(f.Search)));
        return q;
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("appointment-summary")]
    public async Task<IActionResult> AppointmentSummary([FromQuery] ReportFilter f, CancellationToken ct)
    {
        if (Validate(f, "day", "week", "month", "status") is { } error) return BadRequest(error);
        if (f.Status != null && !AppointmentStatuses.Contains(f.Status)) return BadRequest("Invalid appointment status.");
        var rows = await AppointmentQuery(f).Select(x => new { x.NgayGioHen, x.TrangThai }).Take(SourceLimit + 1).ToListAsync(ct);
        if (rows.Count > SourceLimit) return BadRequest("Too many appointments; narrow the date range.");
        return Ok(new { TotalCount = rows.Count, Items = rows.GroupBy(x => new { PeriodStart = f.GroupBy == "status" ? (DateTime?)null : ReportPeriod(x.NgayGioHen, f.GroupBy), Status = x.TrangThai })
            .Select(g => new { g.Key.PeriodStart, g.Key.Status, Count = g.Count() }).OrderBy(x => x.PeriodStart).ThenBy(x => x.Status).ToList() });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("orders")]
    public async Task<IActionResult> Orders([FromQuery] ReportFilter f, CancellationToken ct)
    {
        if (Validate(f) is { } error) return BadRequest(error);
        if (f.Status != null && !InvoiceStatuses.Contains(f.Status)) return BadRequest("Invalid invoice status.");
        var q = OrderQuery(f);
        return Ok(new { TotalCount = await q.CountAsync(ct), PaidRevenue = await q.Where(x => x.TrangThai == "DaThanhToan").SumAsync(x => (decimal?)x.TongTienSauGiam, ct) ?? 0,
            f.Page, f.PageSize, Items = await q.OrderByDescending(x => x.NgayLap).ThenByDescending(x => x.HoaDonId).Skip((f.Page - 1) * f.PageSize).Take(f.PageSize)
            .Select(x => new { Id = x.HoaDonId, AppointmentId = x.LichHenId, CustomerId = x.KhachHangId, CustomerName = x.KhachHang.HoTen, StaffId = x.LichHen.NhanVienId,
                CreatedAt = x.NgayLap, Status = x.TrangThai, GrossAmount = x.TongTienTruocGiam, NetAmount = x.TongTienSauGiam }).ToListAsync(ct) });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("order-summary")]
    public async Task<IActionResult> OrderSummary([FromQuery] ReportFilter f, CancellationToken ct)
    {
        if (Validate(f, "day", "week", "month", "quarter", "year") is { } error) return BadRequest(error);
        if (f.Status != null && !InvoiceStatuses.Contains(f.Status)) return BadRequest("Invalid invoice status.");
        var rows = await OrderQuery(f).Select(x => new { x.NgayLap, x.TrangThai, x.TongTienSauGiam }).Take(SourceLimit + 1).ToListAsync(ct);
        if (rows.Count > SourceLimit) return BadRequest("Too many invoices; narrow the date range.");
        return Ok(new { TotalCount = rows.Count, PaidRevenue = rows.Where(x => x.TrangThai == "DaThanhToan").Sum(x => x.TongTienSauGiam),
            Items = rows.GroupBy(x => ReportPeriod(x.NgayLap, f.GroupBy)).OrderBy(g => g.Key).Select(g => new { PeriodStart = g.Key, InvoiceCount = g.Count(),
                PaidInvoiceCount = g.Count(x => x.TrangThai == "DaThanhToan"), UnpaidInvoiceCount = g.Count(x => x.TrangThai != "DaThanhToan"), PaidRevenue = g.Where(x => x.TrangThai == "DaThanhToan").Sum(x => x.TongTienSauGiam) }).ToList() });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("order-breakdown")]
    public async Task<IActionResult> OrderBreakdown([FromQuery] ReportFilter f, CancellationToken ct)
    {
        if (Validate(f, "service", "combo", "staff", "category") is { } error) return BadRequest(error);
        if (f.Status != null && !InvoiceStatuses.Contains(f.Status)) return BadRequest("Invalid invoice status.");
        var orders = OrderQuery(f);
        var count = await orders.CountAsync(ct);
        var paid = await orders.Where(x => x.TrangThai == "DaThanhToan").SumAsync(x => (decimal?)x.TongTienSauGiam, ct) ?? 0;
        if (f.GroupBy == "staff")
        {
            var items = await orders.GroupBy(x => new { Id = x.LichHen.NhanVienId, Name = x.LichHen.NhanVien != null ? x.LichHen.NhanVien.HoTen : "Unassigned" })
                .Select(g => new { g.Key.Id, g.Key.Name, InvoiceCount = g.Count(), PaidRevenue = g.Where(x => x.TrangThai == "DaThanhToan").Sum(x => (decimal?)x.TongTienSauGiam) ?? 0 }).ToListAsync(ct);
            return Ok(new { TotalCount = count, PaidRevenue = paid, Metric = "invoiceNet", Items = items });
        }
        var lines = db.Chitiethoadons.AsNoTracking().Where(x => orders.Select(o => o.HoaDonId).Contains(x.HoaDonId));
        // Direct category/service filters intentionally exclude combo components: no invented allocation.
        if (f.ServiceId.HasValue) lines = lines.Where(x => x.DichVuId == f.ServiceId);
        if (f.ComboId.HasValue) lines = lines.Where(x => x.ComboId == f.ComboId);
        if (f.CategoryId.HasValue) lines = lines.Where(x => x.DichVu != null && x.DichVu.LoaiDichVuId == f.CategoryId);
        if (f.GroupBy == "service") lines = lines.Where(x => x.DichVuId != null);
        if (f.GroupBy == "combo") lines = lines.Where(x => x.ComboId != null);
        var data = await lines.Select(x => new { x.HoaDonId, x.DichVuId, x.ComboId, ServiceName = x.DichVu != null ? x.DichVu.TenDichVu : null,
            ComboName = x.Combo != null ? x.Combo.TenCombo : null, CategoryId = x.DichVu != null ? (int?)x.DichVu.LoaiDichVuId : null,
            CategoryName = x.DichVu != null ? x.DichVu.LoaiDichVu.TenLoai : null, x.SoLuong, x.DonGia }).Take(SourceLimit + 1).ToListAsync(ct);
        if (data.Count > SourceLimit) return BadRequest("Too many invoice lines; narrow the date range.");
        var result = data.GroupBy(x => new { Id = f.GroupBy == "category" ? x.CategoryId : f.GroupBy == "service" ? x.DichVuId : x.ComboId,
            Kind = f.GroupBy == "category" && x.ComboId.HasValue ? "comboUnallocated" : f.GroupBy,
            Name = f.GroupBy == "category" ? (x.CategoryName ?? "Combo (unallocated)") : f.GroupBy == "service" ? x.ServiceName : x.ComboName })
            .Select(g => new { g.Key.Id, g.Key.Kind, g.Key.Name, InvoiceCount = g.Select(x => x.HoaDonId).Distinct().Count(), Quantity = g.Sum(x => x.SoLuong), GrossAmount = g.Sum(x => x.SoLuong * x.DonGia) }).OrderByDescending(x => x.GrossAmount).ToList();
        return Ok(new { TotalCount = count, PaidRevenue = paid, Metric = "lineGrossBeforeDiscount", Items = result });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("new-customers")]
    public async Task<IActionResult> NewCustomers([FromQuery] ReportFilter f, CancellationToken ct)
    {
        if (Validate(f, "day", "week", "month", "quarter", "year") is { } error) return BadRequest(error);
        if (f.Status != null || f.StaffId.HasValue || f.ServiceId.HasValue || f.ComboId.HasValue || f.CategoryId.HasValue) return BadRequest("New customers accepts only from, to, groupBy and search filters.");
        var all = db.Khachhangs.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(f.Search)) all = all.Where(x => x.HoTen.Contains(f.Search) || (x.SoDienThoai != null && x.SoDienThoai.Contains(f.Search)));
        var unknown = await all.CountAsync(x => x.CreatedAt == null, ct);
        var q = all.Where(x => x.CreatedAt.HasValue);
        if (f.From.HasValue) q = q.Where(x => x.CreatedAt >= f.From.Value);
        if (f.To.HasValue) q = q.Where(x => x.CreatedAt < f.To.Value);
        var dates = await q.Select(x => x.CreatedAt!.Value).Take(SourceLimit + 1).ToListAsync(ct);
        if (dates.Count > SourceLimit) return BadRequest("Too many customers; narrow the date range.");
        return Ok(new { TotalCount = dates.Count, UnknownHistoricalCount = unknown, Items = dates.GroupBy(x => ReportPeriod(x, f.GroupBy)).OrderBy(g => g.Key).Select(g => new { PeriodStart = g.Key, Count = g.Count() }).ToList() });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("export")]
    public async Task<IActionResult> Export([FromQuery] string report, [FromQuery] ReportFilter f, CancellationToken ct)
    {
        IActionResult source = report switch
        {
            "appointments" => await AppointmentSummary(f, ct), "orders" => await OrderSummary(f, ct),
            "breakdown" => await OrderBreakdown(f, ct), "new-customers" => await NewCustomers(f, ct),
            _ => BadRequest("report: appointments, orders, breakdown, new-customers.")
        };
        if (source is not OkObjectResult ok) return source;
        var json = JsonSerializer.SerializeToElement(ok.Value);
        var items = json.GetProperty("Items").EnumerateArray().ToList();
        if (items.Count > 10000) return BadRequest("Export exceeds 10000 rows; narrow filters.");
        string[] headers = report switch { "appointments" => ["PeriodStart", "Status", "Count"], "orders" => ["PeriodStart", "InvoiceCount", "PaidInvoiceCount", "UnpaidInvoiceCount", "PaidRevenue"],
            "new-customers" => ["PeriodStart", "Count"], _ => f.GroupBy == "staff" ? ["Id", "Name", "InvoiceCount", "PaidRevenue"] : ["Id", "Kind", "Name", "InvoiceCount", "Quantity", "GrossAmount"] };
        object? Value(JsonElement row, string key) { var v = row.GetProperty(key); return v.ValueKind switch { JsonValueKind.Number => v.GetDecimal(), JsonValueKind.Null => null, _ => v.GetString() }; }
        var rows = items.Select(row => (IReadOnlyList<object?>)headers.Select(h => Value(row, h)).ToArray()).ToList();
        // Metadata prevents excluded historical customers or gross/net distinctions disappearing in exports.
        void Metadata(string key, object? value) { var row = new object?[headers.Length]; row[0] = key; row[1] = value; rows.Add(row); }
        Metadata("Report", report);
        Metadata("Filters", JsonSerializer.Serialize(f));
        foreach (var prop in json.EnumerateObject().Where(p => p.Name != "Items")) Metadata(prop.Name, prop.Value.ToString());
        if (rows.Count > 10000) return BadRequest("Export exceeds 10000 rows including metadata; narrow filters.");
        return File(ReportingWorkbook.Create("Report", headers, rows), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"healthbeauty-{report}.xlsx");
    }
}
