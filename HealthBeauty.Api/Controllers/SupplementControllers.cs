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
        if (customerId.HasValue && item.KhachHangId != customerId.Value) return Forbid();
        if (!customerId.HasValue && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        return Ok(item);
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, AppointmentUpdateRequest request, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        if (request.AppointmentAt <= DateTime.Now) return BadRequest("Thời gian hẹn phải ở tương lai.");
        if (request.StaffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId.Value, ct)) return BadRequest("Nhân viên không tồn tại.");
        item.NgayGioHen = request.AppointmentAt; item.NhanVienId = request.StaffId; item.GhiChu = request.Note?.Trim(); await db.SaveChangesAsync(ct); return Ok(item);
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
        item.TrangThai = request.Status; await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpPost("{id:int}/reschedule")]
    public async Task<IActionResult> Reschedule(int id, AppointmentUpdateRequest request, CancellationToken ct) => await Update(id, request, ct);

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Cancel(int id, CancellationToken ct)
    {
        var item = await db.Lichhens.FindAsync([id], ct); if (item is null) return NotFound();
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        if (customerId != item.KhachHangId && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        item.TrangThai = "DaHuy"; await db.SaveChangesAsync(ct); return NoContent();
    }

    [AllowAnonymous, HttpGet("available-slots")]
    public async Task<IActionResult> AvailableSlots([FromQuery] DateOnly date, [FromQuery] int? staffId, CancellationToken ct)
    {
        var query = db.Lichlamviecs.AsNoTracking().Where(x => x.NgayLam == date && x.TrangThai != "NghiPhep"); if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        var shifts = await query.Select(x => new { x.NhanVienId, x.GioBatDau, x.GioKetThuc }).ToListAsync(ct); var busy = await db.Lichhens.AsNoTracking().Where(x => x.NgayGioHen.Date == date.ToDateTime(TimeOnly.MinValue).Date && x.TrangThai != "DaHuy" && (!staffId.HasValue || x.NhanVienId == staffId.Value)).Select(x => new { x.NhanVienId, x.NgayGioHen }).ToListAsync(ct);
        return Ok(shifts.Where(s => !busy.Any(b => b.NhanVienId == s.NhanVienId && b.NgayGioHen.TimeOfDay >= s.GioBatDau.ToTimeSpan() && b.NgayGioHen.TimeOfDay < s.GioKetThuc.ToTimeSpan())).Select(s => new { s.NhanVienId, s.GioBatDau, s.GioKetThuc }));
    }
}

[ApiController, Authorize(Roles = "Admin,Manager,Reception"), Route("api/v1/staff")]
public sealed class StaffManagementController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct) => (await db.Nhanviens.AsNoTracking().Include(x => x.Lichlamviecs).FirstOrDefaultAsync(x => x.NhanVienId == id, ct)) is { } x ? Ok(x) : NotFound();
    [HttpDelete("{id:int}")] public async Task<IActionResult> Delete(int id, CancellationToken ct) { var x = await db.Nhanviens.FindAsync([id], ct); if (x is null) return NotFound(); if (await db.Lichhens.AnyAsync(a => a.NhanVienId == id && a.TrangThai != "DaHuy", ct)) return Conflict("Nhân viên đang có lịch hẹn."); db.Nhanviens.Remove(x); await db.SaveChangesAsync(ct); return NoContent(); }
    [HttpDelete("schedules/{id:int}")] public async Task<IActionResult> DeleteSchedule(int id, CancellationToken ct) { var x = await db.Lichlamviecs.FindAsync([id], ct); if (x is null) return NotFound(); db.Lichlamviecs.Remove(x); await db.SaveChangesAsync(ct); return NoContent(); }
    [HttpPut("schedules/{id:int}")] public async Task<IActionResult> UpdateSchedule(int id, WorkScheduleRequest request, CancellationToken ct) { var x = await db.Lichlamviecs.FindAsync([id], ct); if (x is null) return NotFound(); if (request.StartAt >= request.EndAt) return BadRequest("Giờ làm không hợp lệ."); x.NhanVienId=request.StaffId; x.NgayLam=request.WorkDate; x.GioBatDau=request.StartAt; x.GioKetThuc=request.EndAt; x.TrangThai=request.Status; await db.SaveChangesAsync(ct); return Ok(x); }
    [HttpGet("{id:int}/appointments")] public async Task<IActionResult> Appointments(int id, CancellationToken ct) => Ok(await db.Lichhens.AsNoTracking().Where(x => x.NhanVienId == id).OrderByDescending(x => x.NgayGioHen).Take(200).Select(x => new { x.LichHenId, x.KhachHangId, x.NgayGioHen, x.TrangThai, x.GhiChu }).ToListAsync(ct));
}

[ApiController, Authorize, Route("api/v1/customers/me/vouchers")]
public sealed class CustomerVouchersController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet] public async Task<IActionResult> List(CancellationToken ct) { var accountId=int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!); var id=await db.Khachhangs.Where(x=>x.TaiKhoanId==accountId).Select(x=>(int?)x.KhachHangId).FirstOrDefaultAsync(ct); if(id is null)return NotFound(); return Ok(await db.Vouchers.AsNoTracking().Where(x=>x.KhachHangId==null||x.KhachHangId==id).Where(x=>x.TrangThai&&x.HanSuDung>=DateTime.Now).Include(x=>x.KhuyenMai).Select(x=>new{x.VoucherId,x.MaCode,x.GiaTriGiam,x.HanSuDung,x.KhuyenMai.TenKhuyenMai}).ToListAsync(ct)); }
}

[ApiController, Authorize, Route("api/v1/reports")]
public sealed class ReportsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [Authorize(Roles="Admin,Manager"), HttpGet("appointments")] public async Task<IActionResult> Appointments([FromQuery] DateTime? from,[FromQuery] DateTime? to,CancellationToken ct){var q=db.Lichhens.AsNoTracking().AsQueryable();if(from.HasValue)q=q.Where(x=>x.NgayGioHen>=from);if(to.HasValue)q=q.Where(x=>x.NgayGioHen<to);return Ok(await q.GroupBy(x=>x.TrangThai).Select(g=>new{Status=g.Key,Count=g.Count()}).ToListAsync(ct));}
    [Authorize(Roles="Admin,Manager"), HttpGet("revenue")] public async Task<IActionResult> Revenue([FromQuery] DateTime? from,[FromQuery] DateTime? to,CancellationToken ct){var q=db.Hoadons.AsNoTracking().Where(x=>x.TrangThai=="DaThanhToan");if(from.HasValue)q=q.Where(x=>x.NgayLap>=from);if(to.HasValue)q=q.Where(x=>x.NgayLap<to);return Ok(new{InvoiceCount=await q.CountAsync(ct),Revenue=await q.SumAsync(x=>(decimal?)x.TongTienSauGiam,ct)??0});}
    [Authorize(Roles="Admin,Manager"), HttpGet("services")] public async Task<IActionResult> Services(CancellationToken ct)=>Ok(await db.Chitiethoadons.AsNoTracking().Where(x=>x.HoaDon.TrangThai=="DaThanhToan").GroupBy(x=>new{x.DichVuId,Name=x.DichVu!=null?x.DichVu.TenDichVu:x.Combo!.TenCombo}).Select(g=>new{g.Key.DichVuId,g.Key.Name,Quantity=g.Sum(x=>x.SoLuong),Revenue=g.Sum(x=>x.SoLuong*x.DonGia)}).OrderByDescending(x=>x.Revenue).ToListAsync(ct));
    [Authorize(Roles="Admin,Manager"), HttpGet("customers")] public async Task<IActionResult> Customers(CancellationToken ct)=>Ok(await db.Khachhangs.AsNoTracking().OrderByDescending(x=>x.Hoadons.Count).Select(x=>new{ x.KhachHangId, x.HoTen, SoDiem=x.DiemThuong, AppointmentCount=x.Lichhens.Count, InvoiceCount=x.Hoadons.Count}).Take(200).ToListAsync(ct));
}
