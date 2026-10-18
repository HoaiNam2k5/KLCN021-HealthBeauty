using System.Security.Claims;
using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Text.Json;
using HealthBeauty.Api.Services;
using Microsoft.Data.SqlClient;
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
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Customer profile or reward balance changed. Please reload.");
        return Ok(new CustomerResponse(customer.KhachHangId, customer.HoTen, customer.SoDienThoai, customer.GioiTinh, customer.DiemThuong));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet]
    public async Task<IActionResult> List([FromQuery] string? keyword, CancellationToken ct)
    {
        var query = db.Khachhangs.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.HoTen.Contains(keyword) || (x.SoDienThoai != null && x.SoDienThoai.Contains(keyword)));
        return Ok(await query.OrderBy(x => x.HoTen).Take(200).Select(x => new CustomerResponse(x.KhachHangId, x.HoTen, x.SoDienThoai, x.GioiTinh, x.DiemThuong)).ToListAsync(ct));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("{id:int}")]
    public async Task<ActionResult<CustomerResponse>> Update(int id, UpdateCustomerRequest request, CancellationToken ct)
    {
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.KhachHangId == id, ct);
        if (customer is null) return NotFound();
        customer.HoTen = request.FullName.Trim(); customer.SoDienThoai = request.Phone?.Trim(); customer.GioiTinh = request.Gender?.Trim();
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Customer profile or reward balance changed. Please reload.");
        return Ok(new CustomerResponse(customer.KhachHangId, customer.HoTen, customer.SoDienThoai, customer.GioiTinh, customer.DiemThuong));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("{id:int}/points")]
    public async Task<IActionResult> PointHistory(int id, int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (page < 1 || pageSize < 1 || pageSize > 100 || (long)(page - 1) * pageSize > int.MaxValue)
            return BadRequest("Invalid page; pageSize must be between 1 and 100.");
        var customer = await db.Khachhangs.AsNoTracking().FirstOrDefaultAsync(x => x.KhachHangId == id, ct);
        if (customer is null) return NotFound();
        var query = db.Giaodichdiems.AsNoTracking().Where(x => x.KhachHangId == id);
        var totalCount = await query.CountAsync(ct);
        var transactions = await query.OrderByDescending(x => x.NgayGiaoDich).ThenByDescending(x => x.GiaoDichId)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(x => new { x.GiaoDichId, x.SoDiem, x.LoaiGiaoDich, x.NgayGiaoDich, x.GhiChu, x.HoaDonId, x.VoucherId }).ToListAsync(ct);
        return Ok(new { CustomerId = id, customer.DiemThuong, Transactions = transactions, TotalCount = totalCount, Page = page, PageSize = pageSize });
    }

    [HttpGet("me/points")]
    public async Task<IActionResult> Points(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customer = await db.Khachhangs.AsNoTracking().FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null) return NotFound();
        var ledger = await db.Giaodichdiems.AsNoTracking().Where(x => x.KhachHangId == customer.KhachHangId).OrderByDescending(x => x.NgayGiaoDich)
            .Select(x => new { x.GiaoDichId, x.SoDiem, x.LoaiGiaoDich, x.NgayGiaoDich, x.GhiChu, x.HoaDonId, x.VoucherId }).Take(100).ToListAsync(ct);
        return Ok(new { customer.DiemThuong, Transactions = ledger });
    }
}

[ApiController, Authorize, Route("api/v1/staff")]
public sealed class StaffController(Klcn021HealthBeautyContext db, IPasswordService passwords) : ControllerBase
{
    [Authorize(Roles = "Admin,Manager,Reception,Customer"), HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var management = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        return Ok(await db.Nhanviens.AsNoTracking().OrderBy(x => x.HoTen).Select(x => new {
            x.NhanVienId, x.HoTen, x.ChucVu, x.ChuyenMon, x.SoDienThoai, x.NgayVaoLam,
            TaiKhoanId = management ? x.TaiKhoanId : null
        }).ToListAsync(ct));
    }

    [Authorize(Roles = "Staff"), HttpGet("me/appointments")]
    public async Task<IActionResult> MyAppointments(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var ownStaffId = await db.Nhanviens.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.NhanVienId).FirstOrDefaultAsync(ct);
        if (!ownStaffId.HasValue) return Forbid();
        return Ok(await db.Lichhens.AsNoTracking().Where(x => x.NhanVienId == ownStaffId.Value)
            .OrderByDescending(x => x.NgayGioHen).Take(200)
            .Select(x => new { x.LichHenId, x.KhachHangId, x.NhanVienId, x.NgayGioHen, x.TrangThai, x.GhiChu }).ToListAsync(ct));
    }

    [Authorize(Roles = "Staff"), HttpGet("me/schedules")]
    public async Task<IActionResult> MySchedules([FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var ownStaffId = await db.Nhanviens.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.NhanVienId).FirstOrDefaultAsync(ct);
        if (!ownStaffId.HasValue) return Forbid();
        var query = db.Lichlamviecs.AsNoTracking().Where(x => x.NhanVienId == ownStaffId.Value);
        if (from.HasValue) query = query.Where(x => x.NgayLam >= from.Value);
        if (to.HasValue) query = query.Where(x => x.NgayLam <= to.Value);
        return Ok(await query.OrderBy(x => x.NgayLam).ThenBy(x => x.GioBatDau).Take(500)
            .Select(x => new { x.LichLamViecId, x.NhanVienId, x.NgayLam, x.GioBatDau, x.GioKetThuc, x.TrangThai }).ToListAsync(ct));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost]
    public async Task<IActionResult> Create(CreateStaffRequest request, CancellationToken ct)
    {
        if (!User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        var email = request.Email?.Trim().ToLowerInvariant() ?? "";
        var name = request.FullName?.Trim() ?? "";
        var phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim();
        if (email.Length == 0 || email.Length > 255 || !new EmailAddressAttribute().IsValid(email)
            || string.IsNullOrEmpty(request.Password) || request.Password.Length < 8 || request.Password.Length > 128
            || name.Length == 0 || name.Length > 100 || request.Position?.Trim().Length > 50
            || request.Specialty?.Trim().Length > 255 || phone?.Length > 15 || !new PhoneAttribute().IsValid(phone))
            return BadRequest("Email, password or employee information is invalid.");
        var role = await db.Vaitros.SingleOrDefaultAsync(x => x.TenVaiTro == "Staff", ct);
        if (role is null) return BadRequest("Staff role has not been configured.");
        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct) : null;
        if (await db.Taikhoans.AnyAsync(x => x.Email.ToLower() == email, ct)) return Conflict("Email already exists.");
        var account = new Taikhoan { Email = email, TenTaiKhoan = name, MatKhauHash = passwords.Hash(request.Password),
            VaiTro = role, VaiTroId = role.VaiTroId, TrangThai = true, NgayTao = DateTime.UtcNow };
        var item = new Nhanvien { TaiKhoan = account, HoTen = name, ChucVu = request.Position?.Trim(),
            ChuyenMon = request.Specialty?.Trim(), SoDienThoai = phone, NgayVaoLam = request.HireDate };
        db.Nhanviens.Add(item);
        try
        {
            await db.SaveChangesAsync(ct);
            var userAgent = Request.Headers.UserAgent.ToString();
            db.Auditlogs.Add(new Auditlog { TaiKhoanId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),
                ActionName = "StaffAccountCreated", EntityName = "NHANVIEN", EntityId = item.NhanVienId.ToString(),
                NewValues = JsonSerializer.Serialize(new { item.NhanVienId, account.TaiKhoanId, account.Email }),
                CreatedAt = DateTime.UtcNow, IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                UserAgent = userAgent[..Math.Min(500, userAgent.Length)] });
            await db.SaveChangesAsync(ct);
            if (transaction is not null) await transaction.CommitAsync(ct);
        }
        catch (DbUpdateException exception) when (exception.InnerException is SqlException { Number: 2601 or 2627 })
        {
            return Conflict("Email already exists.");
        }
        return Created($"/api/v1/staff/{item.NhanVienId}", new {
            item.NhanVienId, item.TaiKhoanId, item.HoTen, item.ChucVu, item.ChuyenMon, item.SoDienThoai, item.NgayVaoLam
        });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, StaffRequest request, CancellationToken ct)
    {
        var item = await db.Nhanviens.FindAsync([id], ct); if (item is null) return NotFound();
        item.HoTen = request.FullName.Trim(); item.ChucVu = request.Position?.Trim(); item.ChuyenMon = request.Specialty?.Trim(); item.SoDienThoai = request.Phone?.Trim(); item.NgayVaoLam = request.HireDate;
        await db.SaveChangesAsync(ct); return Ok(item);
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("schedules")]
    public async Task<IActionResult> Schedules([FromQuery] int? staffId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken ct)
    {
        var query = db.Lichlamviecs.AsNoTracking().Include(x => x.NhanVien).AsQueryable();
        if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        if (from.HasValue) query = query.Where(x => x.NgayLam >= from.Value);
        if (to.HasValue) query = query.Where(x => x.NgayLam <= to.Value);
        return Ok(await query.OrderBy(x => x.NgayLam).ThenBy(x => x.GioBatDau).Select(x => new { x.LichLamViecId, x.NhanVienId, StaffName = x.NhanVien.HoTen, x.NgayLam, x.GioBatDau, x.GioKetThuc, x.TrangThai }).Take(500).ToListAsync(ct));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost("schedules")]
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
