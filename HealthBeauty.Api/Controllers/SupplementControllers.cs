using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/appointments")]
public sealed class AppointmentManagementController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        var item = await db.Lichhens.AsNoTracking().Include(x => x.KhachHang).Include(x => x.NhanVien).Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu).FirstOrDefaultAsync(x => x.LichHenId == id, ct);
        if (item is null) return NotFound();
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        if (!isStaff && User.IsInRole("Staff"))
        {
            var ownStaffId = await db.Nhanviens.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.NhanVienId).FirstOrDefaultAsync(ct);
            if (!ownStaffId.HasValue || item.NhanVienId != ownStaffId.Value) return Forbid();
        }
        else if (!isStaff && customerId != item.KhachHangId) return Forbid();
        return Ok(AppointmentViews.Detail(item));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, AppointmentUpdateRequest request, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        if (item.TrangThai is not ("ChoXacNhan" or "DaXacNhan")) return Conflict("Only pending or confirmed appointments can be rescheduled.");
        if (request.AppointmentAt <= DateTime.Now) return BadRequest("Thời gian hẹn phải ở tương lai.");
        if (request.StaffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId.Value, ct)) return BadRequest("Nhân viên không tồn tại.");
        var durationMinutes = await AppointmentTiming.LoadDurationMinutesAsync(db, item.LichHenId, ct);
        if (await AppointmentTiming.HasConflictAsync(db, item.KhachHangId, request.StaffId,
            request.AppointmentAt, durationMinutes, item.LichHenId, ct))
            return Conflict("Khách hàng hoặc nhân viên đã có lịch hẹn trong khoảng thời gian này.");
        if (!await AppointmentTiming.IsWithinShiftAsync(db, request.StaffId, request.AppointmentAt, durationMinutes, ct))
            return BadRequest("The entire appointment must be within the selected staff member's working shift.");
        item.NgayGioHen = request.AppointmentAt; item.NhanVienId = request.StaffId; item.GhiChu = request.Note?.Trim(); await db.SaveChangesAsync(ct); return Ok(await AppointmentViews.LoadDetailAsync(db, item.LichHenId, ct));
    }

    [HttpPatch("{id:int}/status")]
    public async Task<IActionResult> Status(int id, AppointmentStatusRequest request, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        var allowed = new[] { "ChoXacNhan", "DaXacNhan", "DaDen", "DangThucHien", "HoanThanh", "DaHuy" };
        if (!allowed.Contains(request.Status)) return BadRequest("Trạng thái lịch hẹn không hợp lệ.");
        if (!User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception"))
        {
            var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
            if (customerId != item.KhachHangId || request.Status != "DaHuy") return Forbid();
        }
        var nextStatuses = item.TrangThai switch
        {
            "ChoXacNhan" => new[] { "DaXacNhan", "DaHuy" },
            "DaXacNhan" => new[] { "DaDen", "DaHuy" },
            "DaDen" => new[] { "DangThucHien", "DaHuy" },
            "DangThucHien" => new[] { "HoanThanh" },
            _ => Array.Empty<string>()
        };
        if (!nextStatuses.Contains(request.Status)) return Conflict("Invalid appointment status transition.");
        item.TrangThai = request.Status; await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpPost("{id:int}/reschedule")]
    public async Task<IActionResult> Reschedule(int id, AppointmentUpdateRequest request, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        if (customerId != item.KhachHangId && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        if (item.TrangThai is not ("ChoXacNhan" or "DaXacNhan")) return Conflict("Only pending or confirmed appointments can be rescheduled.");
        if (request.AppointmentAt <= DateTime.Now) return BadRequest("Thời gian hẹn phải ở tương lai.");
        if (request.StaffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId.Value, ct)) return BadRequest("Nhân viên không tồn tại.");
        var durationMinutes = await AppointmentTiming.LoadDurationMinutesAsync(db, item.LichHenId, ct);
        if (await AppointmentTiming.HasConflictAsync(db, item.KhachHangId, request.StaffId,
            request.AppointmentAt, durationMinutes, item.LichHenId, ct))
            return Conflict("Khách hàng hoặc nhân viên đã có lịch hẹn trong khoảng thời gian này.");
        if (!await AppointmentTiming.IsWithinShiftAsync(db, request.StaffId, request.AppointmentAt, durationMinutes, ct))
            return BadRequest("The entire appointment must be within the selected staff member's working shift.");
        item.NgayGioHen = request.AppointmentAt; item.NhanVienId = request.StaffId; item.GhiChu = request.Note?.Trim();
        await db.SaveChangesAsync(ct); return Ok(await AppointmentViews.LoadDetailAsync(db, item.LichHenId, ct));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Cancel(int id, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        if (customerId != item.KhachHangId && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        if (item.TrangThai is not ("ChoXacNhan" or "DaXacNhan" or "DaDen")) return Conflict("This appointment can no longer be cancelled.");
        item.TrangThai = "DaHuy"; await db.SaveChangesAsync(ct); return NoContent();
    }

    [AllowAnonymous, HttpGet("available-slots"), HttpGet("availability")]
    public async Task<IActionResult> AvailableSlots([FromQuery] DateOnly date, [FromQuery] int? staffId,
        CancellationToken ct, [FromQuery] int? serviceId = null, [FromQuery] int durationMinutes = 30)
    {
        if (date == default || date == DateOnly.MaxValue || durationMinutes <= 0 || durationMinutes > 1440) return BadRequest("A date and a duration between 1 and 1440 minutes are required.");
        if (staffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == staffId.Value, ct)) return BadRequest("Staff does not exist.");
        if (serviceId.HasValue)
        {
            var service = await db.Dichvus.AsNoTracking().FirstOrDefaultAsync(x => x.DichVuId == serviceId.Value && x.TrangThai, ct);
            if (service is null) return BadRequest("Service does not exist or is inactive.");
            durationMinutes = service.ThoiLuongPhut > 0 ? service.ThoiLuongPhut : 30;
            if (durationMinutes > 1440) return BadRequest("Service duration exceeds one working day.");
        }
        var query = db.Lichlamviecs.AsNoTracking().Where(x => x.NgayLam == date && x.TrangThai != "NghiPhep");
        if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        var shifts = await query.ToListAsync(ct);
        var staffIds = shifts.Select(x => x.NhanVienId).Distinct().ToList();
        var dayEnd = date.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var busy = await db.Lichhens.AsNoTracking().Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu)
            .Where(x => x.TrangThai != "DaHuy" && x.NgayGioHen < dayEnd && x.NhanVienId.HasValue && staffIds.Contains(x.NhanVienId.Value))
            .ToListAsync(ct);
        var slots = new List<object>();
        var seen = new HashSet<(int, DateTime)>();
        var now = DateTime.Now;
        foreach (var shift in shifts.OrderBy(x => x.NhanVienId).ThenBy(x => x.GioBatDau))
        {
            var shiftEnd = date.ToDateTime(shift.GioKetThuc);
            for (var start = date.ToDateTime(shift.GioBatDau); start.AddMinutes(durationMinutes) <= shiftEnd; start = start.AddMinutes(30))
            {
                var end = start.AddMinutes(durationMinutes);
                if (start <= now || busy.Any(x => x.NhanVienId == shift.NhanVienId && x.NgayGioHen < end && start < x.NgayGioHen.AddMinutes(AppointmentTiming.DurationMinutes(x)))) continue;
                if (seen.Add((shift.NhanVienId, start))) slots.Add(new { shift.NhanVienId, GioBatDau = TimeOnly.FromDateTime(start), GioKetThuc = TimeOnly.FromDateTime(end) });
            }
        }
        return Ok(slots);
    }
}

[ApiController, Authorize(Roles = "Admin,Manager,Reception"), Route("api/v1/staff")]
public sealed class StaffManagementController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct) => (await db.Nhanviens.AsNoTracking().Include(x => x.Lichlamviecs).FirstOrDefaultAsync(x => x.NhanVienId == id, ct)) is { } x ? Ok(new { x.NhanVienId, x.TaiKhoanId, x.HoTen, x.ChucVu, x.ChuyenMon, x.SoDienThoai, x.NgayVaoLam,
        Lichlamviecs = x.Lichlamviecs.Select(s => new { s.LichLamViecId, s.NhanVienId, s.NgayLam, s.GioBatDau, s.GioKetThuc, s.TrangThai }).ToList() }) : NotFound();
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var item = await db.Nhanviens.FindAsync([id], ct); if (item is null) return NotFound();
        if (await db.Lichhens.AnyAsync(x => x.NhanVienId == id, ct)
            || await db.Lichlamviecs.AnyAsync(x => x.NhanVienId == id, ct))
            return Conflict("Staff with appointment history or work schedules cannot be deleted.");
        db.Nhanviens.Remove(item); await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpDelete("schedules/{id:int}")]
    public async Task<IActionResult> DeleteSchedule(int id, CancellationToken ct)
    {
        var item = await db.Lichlamviecs.FindAsync([id], ct); if (item is null) return NotFound();
        db.Lichlamviecs.Remove(item); await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpPut("schedules/{id:int}")]
    public async Task<IActionResult> UpdateSchedule(int id, WorkScheduleRequest request, CancellationToken ct)
    {
        var item = await db.Lichlamviecs.FindAsync([id], ct); if (item is null) return NotFound();
        if (request.StartAt >= request.EndAt) return BadRequest("Start time must be before end time.");
        if (!await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId, ct)) return BadRequest("Staff does not exist.");
        if (await db.Lichlamviecs.AnyAsync(x => x.LichLamViecId != id && x.NhanVienId == request.StaffId
            && x.NgayLam == request.WorkDate && x.GioBatDau < request.EndAt && x.GioKetThuc > request.StartAt, ct))
            return Conflict("Work schedules overlap.");
        item.NhanVienId = request.StaffId; item.NgayLam = request.WorkDate; item.GioBatDau = request.StartAt;
        item.GioKetThuc = request.EndAt; item.TrangThai = request.Status;
        await db.SaveChangesAsync(ct); return Ok(item);
    }

    [HttpGet("{id:int}/appointments")] public async Task<IActionResult> Appointments(int id, CancellationToken ct) => Ok(await db.Lichhens.AsNoTracking().Where(x => x.NhanVienId == id).OrderByDescending(x => x.NgayGioHen).Take(200).Select(x => new { x.LichHenId, x.KhachHangId, x.NgayGioHen, x.TrangThai, x.GhiChu }).ToListAsync(ct));
}

[ApiController, Authorize, Route("api/v1/customers/me/vouchers")]
public sealed class CustomerVouchersController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var accountId=int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var id=await db.Khachhangs.Where(x=>x.TaiKhoanId==accountId).Select(x=>(int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        if(id is null)return NotFound();
        var now=DateTime.Now;
        var vouchers=await db.Vouchers.AsNoTracking().Include(x=>x.KhuyenMai)
            .Where(x=>(x.KhachHangId==null || x.KhachHangId==id) && x.TrangThai && x.HanSuDung>=now)
            .Where(x=>(!x.KhuyenMai.NgayBatDauHieuLuc.HasValue || x.KhuyenMai.NgayBatDauHieuLuc<=now)
                && (!x.KhuyenMai.NgayKetThucHieuLuc.HasValue || x.KhuyenMai.NgayKetThucHieuLuc>=now)).ToListAsync(ct);
        return Ok(vouchers.Where(x=>x.GiaTriGiam>=0 && VoucherRules.ValidDiscount(x.KhuyenMai.LoaiGiam,x.KhuyenMai.MucGiam))
            .Select(x=>new {x.VoucherId,x.MaCode,x.GiaTriGiam,x.HanSuDung,x.KhuyenMai.TenKhuyenMai}));
    }
}

[ApiController, Authorize, Route("api/v1/reports")]
public sealed class ReportsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("appointments")] public async Task<IActionResult> Appointments([FromQuery] DateTime? from,[FromQuery] DateTime? to,CancellationToken ct){var q=db.Lichhens.AsNoTracking().AsQueryable();if(from.HasValue)q=q.Where(x=>x.NgayGioHen>=from);if(to.HasValue)q=q.Where(x=>x.NgayGioHen<to);return Ok(await q.GroupBy(x=>x.TrangThai).Select(g=>new{Status=g.Key,Count=g.Count()}).ToListAsync(ct));}
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("revenue")] public async Task<IActionResult> Revenue([FromQuery] DateTime? from,[FromQuery] DateTime? to,CancellationToken ct){var q=db.Hoadons.AsNoTracking().Where(x=>x.TrangThai=="DaThanhToan");if(from.HasValue)q=q.Where(x=>x.NgayLap>=from);if(to.HasValue)q=q.Where(x=>x.NgayLap<to);return Ok(new{InvoiceCount=await q.CountAsync(ct),Revenue=await q.SumAsync(x=>(decimal?)x.TongTienSauGiam,ct)??0});}
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("services")] public async Task<IActionResult> Services(CancellationToken ct)=>Ok(await db.Chitiethoadons.AsNoTracking().Where(x=>x.HoaDon.TrangThai=="DaThanhToan").GroupBy(x=>new{x.DichVuId,Name=x.DichVu!=null?x.DichVu.TenDichVu:x.Combo!.TenCombo}).Select(g=>new{g.Key.DichVuId,g.Key.Name,Quantity=g.Sum(x=>x.SoLuong),Revenue=g.Sum(x=>x.SoLuong*x.DonGia)}).OrderByDescending(x=>x.Revenue).ToListAsync(ct));
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("customers")] public async Task<IActionResult> Customers(CancellationToken ct)=>Ok(await db.Khachhangs.AsNoTracking().OrderByDescending(x=>x.Hoadons.Count).Select(x=>new{ x.KhachHangId, x.HoTen, SoDiem=x.DiemThuong, AppointmentCount=x.Lichhens.Count, InvoiceCount=x.Hoadons.Count}).Take(200).ToListAsync(ct));
}
