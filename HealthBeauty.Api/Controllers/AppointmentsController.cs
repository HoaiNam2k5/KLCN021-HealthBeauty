using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/appointments")]
public sealed class AppointmentsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMine([FromQuery] DateTime? from, [FromQuery] DateTime? to, [FromQuery] string? status, [FromQuery] int? staffId, [FromQuery] string? keyword, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default)
    {
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 100);
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(cancellationToken);
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        if (customerId is null && !isStaff) return Ok(Array.Empty<AppointmentResponse>());
        var query = db.Lichhens.AsNoTracking().Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu).Include(x => x.KhachHang).AsQueryable();
        if (customerId is not null) query = query.Where(x => x.KhachHangId == customerId.Value);
        if (from.HasValue) query = query.Where(x => x.NgayGioHen >= from.Value);
        if (to.HasValue) query = query.Where(x => x.NgayGioHen < to.Value);
        if (!string.IsNullOrWhiteSpace(status)) query = query.Where(x => x.TrangThai == status);
        if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.KhachHang.HoTen.Contains(keyword) || (x.KhachHang.SoDienThoai != null && x.KhachHang.SoDienThoai.Contains(keyword)));
        var totalCount = await query.CountAsync(cancellationToken);
        var list = await query.OrderByDescending(x => x.NgayGioHen).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return Ok(new { items = list.Select(Map), totalCount, page, pageSize });
    }

    [HttpPost]
    public async Task<ActionResult<AppointmentResponse>> Create(CreateAppointmentRequest request, CancellationToken cancellationToken)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var ownCustomerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(cancellationToken);
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        if (isStaff && request.CustomerId is null) return BadRequest("CustomerId is required for staff-created appointments.");
        var customerId = request.CustomerId ?? ownCustomerId;
        if (customerId is null) return BadRequest("Customer profile is required.");
        if (!isStaff && request.CustomerId.HasValue && request.CustomerId != ownCustomerId) return Forbid();
        if (!await db.Khachhangs.AnyAsync(x => x.KhachHangId == customerId.Value, cancellationToken)) return BadRequest("Customer does not exist.");
        if (request.StaffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId.Value, cancellationToken)) return BadRequest("Staff does not exist.");
        if (request.AppointmentAt <= DateTime.Now) return BadRequest("Appointment time must be in the future.");
        var serviceIds = request.Items.Select(x => x.ServiceId).Distinct().ToList();
        var services = await db.Dichvus.Where(x => serviceIds.Contains(x.DichVuId) && x.TrangThai).ToDictionaryAsync(x => x.DichVuId, cancellationToken);
        if (services.Count != serviceIds.Count) return BadRequest("One or more services are invalid.");
        var conflict = await db.Lichhens.AnyAsync(x => x.KhachHangId == customerId && x.NgayGioHen == request.AppointmentAt && x.TrangThai != "DaHuy", cancellationToken)
            || (request.StaffId.HasValue && await db.Lichhens.AnyAsync(x => x.NhanVienId == request.StaffId && x.NgayGioHen == request.AppointmentAt && x.TrangThai != "DaHuy", cancellationToken));
        if (conflict) return Conflict("Customer or staff already has an appointment at this time.");
        var appointment = new Lichhen { KhachHangId = customerId.Value, NhanVienId = request.StaffId, NgayGioHen = request.AppointmentAt, TrangThai = "ChoXacNhan", GhiChu = request.Note?.Trim() };
        foreach (var item in request.Items) appointment.Chitietlichhens.Add(new Chitietlichhen { DichVuId = item.ServiceId, ComboId = item.ComboId, GiaDuKien = item.ExpectedPrice > 0 ? item.ExpectedPrice : services[item.ServiceId].Gia, ThoiLuongThucTe = services[item.ServiceId].ThoiLuongPhut });
        db.Lichhens.Add(appointment); await db.SaveChangesAsync(cancellationToken);
        await db.Entry(appointment).Collection(x => x.Chitietlichhens).Query().Include(x => x.DichVu).LoadAsync(cancellationToken);
        return CreatedAtAction(nameof(GetMine), new { id = appointment.LichHenId }, Map(appointment));
    }

    private static AppointmentResponse Map(Lichhen item) => new(item.LichHenId, item.KhachHangId, item.NhanVienId, item.NgayGioHen, item.TrangThai, item.GhiChu, item.Chitietlichhens.Select(x => new AppointmentItemResponse(x.ChiTietLichHenId, x.DichVuId, x.DichVu.TenDichVu, x.ComboId, x.GiaDuKien)).ToList());
}