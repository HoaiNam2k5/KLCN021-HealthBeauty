using Microsoft.Data.SqlClient;
using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/appointments")]
public sealed class AppointmentManagementController(Klcn021HealthBeautyContext db, INotificationService? notifications = null) : ControllerBase
{
    private INotificationService Notifications => notifications ?? new NotificationService(db);
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
        if (!await ServicePackageLifecycle.ValidDateAsync(db, item, request.AppointmentAt, ct)) return BadRequest("Appointment is outside package validity.");
        item.NgayGioHen = request.AppointmentAt; item.NhanVienId = request.StaffId; item.GhiChu = request.Note?.Trim();
        await NotificationEvents.AppointmentAsync(Notifications, item, "Rescheduled", ct);
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Lịch hẹn vừa được cập nhật. Vui lòng tải lại dữ liệu."); return Ok(await AppointmentViews.LoadDetailAsync(db, item.LichHenId, ct));
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
        var management = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        if (management && request.Status == "DaHuy" && string.IsNullOrWhiteSpace(request.Reason))
            return BadRequest("Vui lòng nhập lý do hủy lịch hẹn.");
        if (request.Reason?.Trim().Length > 1000) return BadRequest("Lý do hủy không được quá 1000 ký tự.");
        var previousStatus = item.TrangThai;
        var nextStatuses = item.TrangThai switch
        {
            "ChoXacNhan" => new[] { "DaXacNhan", "DaHuy" },
            "DaXacNhan" => new[] { "DaDen", "DangThucHien", "DaHuy" },
            "DaDen" => new[] { "DangThucHien", "DaHuy" },
            "DangThucHien" => new[] { "HoanThanh" },
            _ => Array.Empty<string>()
        };
        if (!nextStatuses.Contains(request.Status)) return Conflict("Invalid appointment status transition.");
        if (request.Status is "HoanThanh" or "DaHuy") await ServicePackageLifecycle.SettleAsync(db, item, request.Status == "HoanThanh", ct);
        if (request.Status == "HoanThanh" && !item.CustomerPackageId.HasValue)
        {
            var invoiceError = await AppointmentInvoicing.StageAsync(db, Notifications, item, ct);
            if (invoiceError is not null) return Conflict(invoiceError);
        }
        item.TrangThai = request.Status;
        db.Auditlogs.Add(new Auditlog
        {
            TaiKhoanId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),
            ActionName = "AppointmentStatusChanged", EntityName = "LICHHEN", EntityId = id.ToString(),
            OldValues = System.Text.Json.JsonSerializer.Serialize(new { status = previousStatus }),
            NewValues = System.Text.Json.JsonSerializer.Serialize(new { status = request.Status, reason = request.Status == "DaHuy" ? request.Reason?.Trim() : null }),
            CreatedAt = DateTime.Now
        });
        await NotificationEvents.AppointmentAsync(Notifications, item, request.Status, ct);
        try
        {
            if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Appointment or package balance changed. Please reload.");
        }
        catch (DbUpdateException error) when (error.InnerException is SqlException { Number: 2601 or 2627 })
        {
            // Concurrent completion can reach the unique invoice insert before the CAS update.
            db.ChangeTracker.Clear();
            return Conflict("The appointment already has an invoice or was completed. Please reload.");
        }
        return NoContent();
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
        if (!await ServicePackageLifecycle.ValidDateAsync(db, item, request.AppointmentAt, ct)) return BadRequest("Appointment is outside package validity.");
        item.NgayGioHen = request.AppointmentAt; item.NhanVienId = request.StaffId; item.GhiChu = request.Note?.Trim();
        await NotificationEvents.AppointmentAsync(Notifications, item, "Rescheduled", ct);
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Lịch hẹn vừa được cập nhật. Vui lòng tải lại dữ liệu."); return Ok(await AppointmentViews.LoadDetailAsync(db, item.LichHenId, ct));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Cancel(int id, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        if (customerId != item.KhachHangId && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        if (item.TrangThai is not ("ChoXacNhan" or "DaXacNhan" or "DaDen")) return Conflict("This appointment can no longer be cancelled.");
        await ServicePackageLifecycle.SettleAsync(db, item, false, ct);
        item.TrangThai = "DaHuy";
        await NotificationEvents.AppointmentAsync(Notifications, item, "DaHuy", ct);
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Lịch hẹn vừa được cập nhật. Vui lòng tải lại dữ liệu."); return NoContent();
    }

    [AllowAnonymous, HttpGet("available-slots"), HttpGet("availability")]
    public async Task<IActionResult> AvailableSlots([FromQuery] DateOnly date, [FromQuery] int? staffId,
        CancellationToken ct, [FromQuery] int? serviceId = null, [FromQuery] int durationMinutes = 30,
        [FromQuery] int? excludeAppointmentId = null)
    {
        if (date == default || date == DateOnly.MaxValue || durationMinutes <= 0 || durationMinutes > 1440) return BadRequest("A date and a duration between 1 and 1440 minutes are required.");
        if (excludeAppointmentId.HasValue)
        {
            if (excludeAppointmentId.Value <= 0) return BadRequest("Invalid appointment identifier.");
            if (User.Identity?.IsAuthenticated != true || !int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actor)) return Unauthorized();
            var appointment = await db.Lichhens.AsNoTracking().FirstOrDefaultAsync(x => x.LichHenId == excludeAppointmentId.Value, ct);
            if (appointment is null) return NotFound();
            var owns = await db.Khachhangs.AnyAsync(x => x.KhachHangId == appointment.KhachHangId && x.TaiKhoanId == actor, ct);
            var management = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
            if (!owns)
            {
                if (!management) return NotFound();
                var utcNow = DateTime.UtcNow;
                if (!await db.Taikhoans.AnyAsync(x => x.TaiKhoanId == actor && x.TrangThai && (!x.KhoaDen.HasValue || x.KhoaDen <= utcNow)
                    && db.VaitroQuyens.Any(g => g.VaiTroId == x.VaiTroId && g.DuocCap && g.Quyen.TrangThai && g.Quyen.MaQuyen == "APPOINTMENT.READ"), ct)) return Forbid();
            }
            if (appointment.TrangThai is not ("ChoXacNhan" or "DaXacNhan")) return Conflict("This appointment cannot be rescheduled.");
        }
        if (staffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == staffId.Value, ct)) return BadRequest("Staff does not exist.");
        if (serviceId.HasValue)
        {
            var service = await db.Dichvus.AsNoTracking().FirstOrDefaultAsync(x => x.DichVuId == serviceId.Value && x.TrangThai, ct);
            if (service is null) return BadRequest("Service does not exist or is inactive.");
            durationMinutes = service.ThoiLuongPhut > 0 ? service.ThoiLuongPhut : 30;
            if (durationMinutes > 1440) return BadRequest("Service duration exceeds one working day.");
        }
        var slots = await LoadAvailableSlots(date, date, staffId, durationMinutes, ct, excludeAppointmentId);
        return Ok(slots.Select(x => new { NhanVienId = x.StaffId, GioBatDau = TimeOnly.FromDateTime(x.Start), GioKetThuc = TimeOnly.FromDateTime(x.End) }));
    }

    [AllowAnonymous, HttpGet("availability/days")]
    public async Task<IActionResult> AvailableDays([FromQuery] DateOnly from, [FromQuery] DateOnly to,
        CancellationToken ct, [FromQuery] int? staffId = null, [FromQuery] int durationMinutes = 30)
    {
        if (from == default || to == default || to == DateOnly.MaxValue || to < from || to.DayNumber - from.DayNumber > 60)
            return BadRequest("Provide an ordered date range of at most 61 days.");
        if (durationMinutes <= 0 || durationMinutes > 1440)
            return BadRequest("Duration must be between 1 and 1440 minutes.");
        if (staffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == staffId.Value, ct))
            return BadRequest("Staff does not exist.");

        var slots = await LoadAvailableSlots(from, to, staffId, durationMinutes, ct);
        return Ok(slots.GroupBy(x => DateOnly.FromDateTime(x.Start)).OrderBy(x => x.Key)
            .Select(x => new { Date = x.Key, StartTimes = x.Select(s => TimeOnly.FromDateTime(s.Start)).Distinct().Order().ToArray() }));
    }

    private sealed record AvailableStaffSlot(int StaffId, DateTime Start, DateTime End);

    private async Task<List<AvailableStaffSlot>> LoadAvailableSlots(DateOnly from, DateOnly to, int? staffId, int durationMinutes, CancellationToken ct, int? excludeAppointmentId = null)
    {
        var query = db.Lichlamviecs.AsNoTracking().Where(x => x.NgayLam >= from && x.NgayLam <= to && x.TrangThai != "NghiPhep");
        if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        var shifts = await query.ToListAsync(ct);
        var staffIds = shifts.Select(x => x.NhanVienId).Distinct().ToList();
        if (shifts.Count == 0) return [];
        var dayEnd = to.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var busy = await db.Lichhens.AsNoTracking().Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu)
            .Where(x => x.TrangThai != "DaHuy" && (!excludeAppointmentId.HasValue || x.LichHenId != excludeAppointmentId.Value)
                && x.NgayGioHen < dayEnd && x.NhanVienId.HasValue && staffIds.Contains(x.NhanVienId.Value))
            .ToListAsync(ct);
        var busyByStaff = busy.ToLookup(x => x.NhanVienId!.Value);
        var slots = new List<AvailableStaffSlot>();
        var seen = new HashSet<(int, DateTime)>();
        var now = DateTime.Now;
        foreach (var shift in shifts.OrderBy(x => x.NgayLam).ThenBy(x => x.NhanVienId).ThenBy(x => x.GioBatDau))
        {
            var date = shift.NgayLam;
            var shiftEnd = date.ToDateTime(shift.GioKetThuc);
            for (var start = date.ToDateTime(shift.GioBatDau); start.AddMinutes(durationMinutes) <= shiftEnd; start = start.AddMinutes(30))
            {
                var end = start.AddMinutes(durationMinutes);
                if (start <= now || busyByStaff[shift.NhanVienId].Any(x => x.NgayGioHen < end && start < x.NgayGioHen.AddMinutes(AppointmentTiming.DurationMinutes(x)))) continue;
                if (seen.Add((shift.NhanVienId, start))) slots.Add(new AvailableStaffSlot(shift.NhanVienId, start, end));
            }
        }
        return slots;
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
            .Where(x=>(x.KhachHangId==null || x.KhachHangId==id) && x.TrangThai && !x.UsedAt.HasValue && x.HanSuDung>=now)
            .Where(x=>x.PointsCost==0 || (x.RedeemedAt.HasValue && x.KhachHangId==id))
            .Where(x=>(!x.KhuyenMai.NgayBatDauHieuLuc.HasValue || x.KhuyenMai.NgayBatDauHieuLuc<=now)
                && (!x.KhuyenMai.NgayKetThucHieuLuc.HasValue || x.KhuyenMai.NgayKetThucHieuLuc>=now)).ToListAsync(ct);
        return Ok(vouchers.Where(x=>x.GiaTriGiam>=0 && VoucherRules.ValidDiscount(x.KhuyenMai.LoaiGiam,x.KhuyenMai.MucGiam))
            .Select(x=>new {x.VoucherId,x.MaCode,x.GiaTriGiam,x.HanSuDung,x.KhuyenMai.TenKhuyenMai,x.PointsCost,x.RedeemedAt}));
    }
}

[ApiController, Authorize, Route("api/v1/reports")]
public sealed partial class ReportsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("appointments")] public async Task<IActionResult> Appointments([FromQuery] DateTime? from,[FromQuery] DateTime? to,CancellationToken ct){var q=db.Lichhens.AsNoTracking().AsQueryable();if(from.HasValue)q=q.Where(x=>x.NgayGioHen>=from);if(to.HasValue)q=q.Where(x=>x.NgayGioHen<to);return Ok(await q.GroupBy(x=>x.TrangThai).Select(g=>new{Status=g.Key,Count=g.Count()}).ToListAsync(ct));}
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("revenue")] public async Task<IActionResult> Revenue([FromQuery] DateTime? from,[FromQuery] DateTime? to,CancellationToken ct){var q=db.Hoadons.AsNoTracking().Where(x=>x.TrangThai=="DaThanhToan");if(from.HasValue)q=q.Where(x=>x.NgayLap>=from);if(to.HasValue)q=q.Where(x=>x.NgayLap<to);return Ok(new{InvoiceCount=await q.CountAsync(ct),Revenue=await q.SumAsync(x=>(decimal?)x.TongTienSauGiam,ct)??0});}
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("services")] public async Task<IActionResult> Services(CancellationToken ct)=>Ok(await db.Chitiethoadons.AsNoTracking().Where(x=>x.HoaDon.TrangThai=="DaThanhToan").GroupBy(x=>new{x.DichVuId,x.ComboId,Name=x.DichVu!=null?x.DichVu.TenDichVu:x.Combo!.TenCombo}).Select(g=>new{g.Key.DichVuId,g.Key.Name,Quantity=g.Sum(x=>x.SoLuong),Revenue=g.Sum(x=>x.SoLuong*x.DonGia)}).OrderByDescending(x=>x.Revenue).ToListAsync(ct));
    [Authorize(Roles="Admin,Manager,Reception"), HttpGet("customers")] public async Task<IActionResult> Customers(CancellationToken ct)=>Ok(await db.Khachhangs.AsNoTracking().OrderByDescending(x=>x.Hoadons.Count).Select(x=>new{ x.KhachHangId, x.HoTen, SoDiem=x.DiemThuong, AppointmentCount=x.Lichhens.Count, InvoiceCount=x.Hoadons.Count}).Take(200).ToListAsync(ct));
}
