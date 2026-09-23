using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using HealthBeauty.Api.Models;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/customers")]
public sealed class CustomersController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet("me")]
    public async Task<ActionResult<CustomerResponse>> Me(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var item = await db.Khachhangs.AsNoTracking().Where(x => x.TaiKhoanId == accountId)
            .Select(x => new CustomerResponse(x.KhachHangId, x.HoTen, x.SoDienThoai, x.GioiTinh, x.DiemThuong)).FirstOrDefaultAsync(ct);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpPut("me")]
    public async Task<ActionResult<CustomerResponse>> UpdateMe(UpdateCustomerRequest request, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null) return NotFound();
        customer.HoTen = request.FullName.Trim(); customer.SoDienThoai = request.Phone?.Trim(); customer.GioiTinh = request.Gender?.Trim();
        await db.SaveChangesAsync(ct);
        return Ok(new CustomerResponse(customer.KhachHangId, customer.HoTen, customer.SoDienThoai, customer.GioiTinh, customer.DiemThuong));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet]
    public async Task<IActionResult> List([FromQuery] string? keyword, CancellationToken ct)
    {
        var query = db.Khachhangs.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.HoTen.Contains(keyword) || (x.SoDienThoai != null && x.SoDienThoai.Contains(keyword)));
        return Ok(await query.OrderBy(x => x.HoTen).Take(200).Select(x => new CustomerResponse(x.KhachHangId, x.HoTen, x.SoDienThoai, x.GioiTinh, x.DiemThuong)).ToListAsync(ct));
    }

    [HttpGet("me/points")]
    public async Task<IActionResult> Points(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customer = await db.Khachhangs.AsNoTracking().FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null) return NotFound();
        var ledger = await db.Giaodichdiems.AsNoTracking().Where(x => x.KhachHangId == customer.KhachHangId).OrderByDescending(x => x.NgayGiaoDich)
            .Select(x => new { x.GiaoDichId, x.SoDiem, x.LoaiGiaoDich, x.NgayGiaoDich, x.GhiChu, x.HoaDonId }).Take(100).ToListAsync(ct);
        return Ok(new { customer.DiemThuong, Transactions = ledger });
    }
}

[ApiController, Authorize(Roles = "Admin,Manager"), Route("api/v1/staff")]
public sealed class StaffController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await db.Nhanviens.AsNoTracking().OrderBy(x => x.HoTen).Select(x => new { x.NhanVienId, x.HoTen, x.ChucVu, x.ChuyenMon, x.SoDienThoai, x.NgayVaoLam }).ToListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create(StaffRequest request, CancellationToken ct)
    {
        var item = new Nhanvien { HoTen = request.FullName.Trim(), ChucVu = request.Position?.Trim(), ChuyenMon = request.Specialty?.Trim(), SoDienThoai = request.Phone?.Trim(), NgayVaoLam = request.HireDate };
        db.Nhanviens.Add(item); await db.SaveChangesAsync(ct); return Created($"api/v1/staff/{item.NhanVienId}", item);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, StaffRequest request, CancellationToken ct)
    {
        var item = await db.Nhanviens.FindAsync([id], ct); if (item is null) return NotFound();
        item.HoTen = request.FullName.Trim(); item.ChucVu = request.Position?.Trim(); item.ChuyenMon = request.Specialty?.Trim(); item.SoDienThoai = request.Phone?.Trim(); item.NgayVaoLam = request.HireDate;
        await db.SaveChangesAsync(ct); return Ok(item);
    }

    [HttpGet("schedules")]
    public async Task<IActionResult> Schedules([FromQuery] int? staffId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken ct)
    {
        var query = db.Lichlamviecs.AsNoTracking().Include(x => x.NhanVien).AsQueryable();
        if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        if (from.HasValue) query = query.Where(x => x.NgayLam >= from.Value);
        if (to.HasValue) query = query.Where(x => x.NgayLam <= to.Value);
        return Ok(await query.OrderBy(x => x.NgayLam).ThenBy(x => x.GioBatDau).Select(x => new { x.LichLamViecId, x.NhanVienId, StaffName = x.NhanVien.HoTen, x.NgayLam, x.GioBatDau, x.GioKetThuc, x.TrangThai }).Take(500).ToListAsync(ct));
    }

    [HttpPost("schedules")]
    public async Task<IActionResult> CreateSchedule(WorkScheduleRequest request, CancellationToken ct)
    {
        if (request.StartAt >= request.EndAt) return BadRequest("Giờ bắt đầu phải trước giờ kết thúc.");
        if (!await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId, ct)) return BadRequest("Nhân viên không tồn tại.");
        var overlap = await db.Lichlamviecs.AnyAsync(x => x.NhanVienId == request.StaffId && x.NgayLam == request.WorkDate && x.GioBatDau < request.EndAt && x.GioKetThuc > request.StartAt, ct);
        if (overlap) return Conflict("Ca làm bị trùng thời gian.");
        var item = new Lichlamviec { NhanVienId = request.StaffId, NgayLam = request.WorkDate, GioBatDau = request.StartAt, GioKetThuc = request.EndAt, TrangThai = request.Status ?? "HoatDong" };
        db.Lichlamviecs.Add(item); await db.SaveChangesAsync(ct); return CreatedAtAction(nameof(Schedules), new { staffId = item.NhanVienId }, item);
    }
}
