using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
namespace HealthBeauty.Api.Controllers;

public sealed partial class AdministrationController
{
    [HttpPost("accounts")]
    public async Task<IActionResult> CreateAccount(CreateAccountRequest request, CancellationToken ct)
    {
        var actor = await AdminActor(ct); if (actor is null) return Forbid();
        var email = request.Email?.Trim().ToLowerInvariant() ?? "";
        var name = request.FullName?.Trim() ?? "";
        var phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim();
        if (email.Length == 0 || email.Length > 255 || !new EmailAddressAttribute().IsValid(email)
            || string.IsNullOrEmpty(request.Password) || request.Password.Length < 8 || request.Password.Length > 128
            || name.Length == 0 || name.Length > 100 || phone?.Length > 15 || !new PhoneAttribute().IsValid(phone))
            return BadRequest("Email, password, full name or phone is invalid.");
        var role = await db.Vaitros.FirstOrDefaultAsync(x => x.VaiTroId == request.RoleId, ct);
        if (role is null || !SupportedRole(role.TenVaiTro)) return BadRequest("Role does not exist or is unsupported.");
        if (request.StaffId.HasValue && (request.StaffId <= 0 || role.TenVaiTro != "Staff"))
            return BadRequest("Chỉ vai trò Staff mới được chọn hồ sơ nhân viên có sẵn.");
        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct) : null;
        if (await db.Taikhoans.AnyAsync(x => x.Email.ToLower() == email, ct)) return Conflict("Email already exists.");
        Nhanvien? existingStaff = null;
        if (request.StaffId.HasValue)
        {
            existingStaff = await db.Nhanviens.FirstOrDefaultAsync(x => x.NhanVienId == request.StaffId, ct);
            if (existingStaff is null) return BadRequest("Nhân viên không tồn tại.");
            if (existingStaff.TaiKhoanId.HasValue) return Conflict("Nhân viên đã liên kết với tài khoản khác.");
        }
        var account = new Taikhoan { Email = email, TenTaiKhoan = name, MatKhauHash = passwords.Hash(request.Password),
            VaiTroId = role.VaiTroId, VaiTro = role, TrangThai = true, NgayTao = DateTime.UtcNow };
        db.Taikhoans.Add(account);
        if (existingStaff is null) EnsureProfile(account, role.TenVaiTro, name, phone);
        else { account.Nhanvien = existingStaff; existingStaff.TaiKhoan = account; }
        try
        {
            await db.SaveChangesAsync(ct);
            AddAccountAudit(actor.Value, "AccountCreated", account.TaiKhoanId, null, JsonSerializer.Serialize(new { account.Email, FullName = name, RoleId = role.VaiTroId, StaffId = account.Nhanvien?.NhanVienId }));
            await db.SaveChangesAsync(ct);
            if (transaction is not null) await transaction.CommitAsync(ct);
        }
        catch (DbUpdateException exception) when (exception.InnerException is SqlException { Number: 2601 or 2627 })
        {
            return Conflict("Email already exists.");
        }
        return Created("/api/v1/admin/accounts?keyword=" + Uri.EscapeDataString(email), MapAccount(account));
    }

    [HttpPatch("accounts/{accountId:int}/role")]
    public async Task<IActionResult> AssignAccountRole(int accountId, AssignAccountRoleRequest request, CancellationToken ct)
    {
        var actor = await AdminActor(ct); if (actor is null) return Forbid();
        var role = await db.Vaitros.FirstOrDefaultAsync(x => x.VaiTroId == request.RoleId, ct);
        if (role is null || !SupportedRole(role.TenVaiTro)) return BadRequest("Role does not exist or is unsupported.");
        if (request.StaffId.HasValue && (request.StaffId <= 0 || role.TenVaiTro != "Staff"))
            return BadRequest("Chỉ vai trò Staff mới được chọn hồ sơ nhân viên có sẵn.");
        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct) : null;
        var account = await db.Taikhoans.Include(x => x.VaiTro).Include(x => x.Khachhang).Include(x => x.Nhanvien).FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (account is null) return NotFound();
        if (accountId == actor && role.TenVaiTro != "Admin") return BadRequest("You cannot remove your own administrator role.");
        if (account.TrangThai && account.VaiTro.TenVaiTro == "Admin" && role.TenVaiTro != "Admin"
            && !await db.Taikhoans.AnyAsync(x => x.TaiKhoanId != accountId && x.TrangThai && x.VaiTro.TenVaiTro == "Admin", ct))
            return Conflict("At least one active administrator is required.");
        var previousStaffId = account.Nhanvien?.NhanVienId;
        var staffChanged = request.StaffId.HasValue && request.StaffId != previousStaffId;
        if (account.VaiTroId == request.RoleId && !staffChanged) return Ok(MapAccount(account));
        Nhanvien? targetStaff = null;
        if (staffChanged)
        {
            targetStaff = await db.Nhanviens.FirstOrDefaultAsync(x => x.NhanVienId == request.StaffId, ct);
            if (targetStaff is null) return BadRequest("Nhân viên không tồn tại.");
            if (targetStaff.TaiKhoanId.HasValue && targetStaff.TaiKhoanId != accountId)
                return Conflict("Nhân viên đã liên kết với tài khoản khác.");
            if (previousStaffId.HasValue && (await db.Lichhens.AnyAsync(x => x.NhanVienId == previousStaffId, ct)
                || await db.Lichlamviecs.AnyAsync(x => x.NhanVienId == previousStaffId, ct)))
                return Conflict("Hồ sơ hiện tại đã có lịch hẹn hoặc ca làm, không thể đổi liên kết nhân viên.");
        }
        var previousRole = account.VaiTroId;
        var name = account.TenTaiKhoan ?? account.Khachhang?.HoTen ?? account.Nhanvien?.HoTen ?? account.Email[..Math.Min(100, account.Email.Length)];
        var phone = account.Khachhang?.SoDienThoai ?? account.Nhanvien?.SoDienThoai;
        if (targetStaff is not null)
        {
            if (account.Nhanvien is { } previousStaff)
            {
                // Release the filtered unique account link before assigning the existing profile.
                previousStaff.TaiKhoanId = null; previousStaff.TaiKhoan = null; account.Nhanvien = null;
                await db.SaveChangesAsync(ct);
            }
            targetStaff.TaiKhoanId = accountId; targetStaff.TaiKhoan = account; account.Nhanvien = targetStaff;
        }
        else EnsureProfile(account, role.TenVaiTro, name, phone);
        account.VaiTroId = role.VaiTroId; account.VaiTro = role;
        await RevokeRefreshTokens(accountId, ct);
        if (previousRole != role.VaiTroId)
            AddAccountAudit(actor.Value, "AccountRoleChanged", accountId, previousRole.ToString(), role.VaiTroId.ToString());
        if (staffChanged)
            AddAccountAudit(actor.Value, "AccountStaffLinked", accountId, previousStaffId?.ToString(), targetStaff!.NhanVienId.ToString());
        await db.SaveChangesAsync(ct);
        if (transaction is not null) await transaction.CommitAsync(ct);
        return Ok(MapAccount(account));
    }

    private static bool SupportedRole(string name) => name is "Admin" or "Manager" or "Reception" or "Staff" or "Customer";
    private async Task<int?> AdminActor(CancellationToken ct)
    {
        if (!User.IsInRole("Admin") || !int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) return null;
        var now = DateTime.UtcNow;
        return await db.Taikhoans.AnyAsync(x => x.TaiKhoanId == id && x.TrangThai && (!x.KhoaDen.HasValue || x.KhoaDen <= now) && x.VaiTro.TenVaiTro == "Admin", ct) ? id : null;
    }

    private void EnsureProfile(Taikhoan account, string role, string fullName, string? phone)
    {
        if (role == "Customer" && account.Khachhang is null)
        {
            var customer = new Khachhang { CreatedAt = DateTime.Now, TaiKhoan = account, HoTen = fullName, SoDienThoai = phone, DiemThuong = 0 };
            account.Khachhang = customer; db.Khachhangs.Add(customer);
        }
        else if (role != "Customer" && account.Nhanvien is null)
        {
            var staff = new Nhanvien { TaiKhoan = account, HoTen = fullName, SoDienThoai = phone, ChucVu = role, NgayVaoLam = DateOnly.FromDateTime(DateTime.Today) };
            account.Nhanvien = staff; db.Nhanviens.Add(staff);
        }
    }

    private async Task RevokeRefreshTokens(int accountId, CancellationToken ct)
    {
        var tokens = await db.Refreshtokens.Where(x => x.TaiKhoanId == accountId && x.RevokedAt == null).ToListAsync(ct);
        foreach (var token in tokens) { token.RevokedAt = DateTime.UtcNow; token.RevokedByIp = HttpContext.Connection.RemoteIpAddress?.ToString(); }
    }

    private void AddAccountAudit(int actor, string action, int id, string? oldValues, string newValues)
    {
        var userAgent = Request.Headers.UserAgent.ToString();
        db.Auditlogs.Add(new Auditlog { TaiKhoanId = actor, ActionName = action, EntityName = "TAIKHOAN", EntityId = id.ToString(), OldValues = oldValues, NewValues = newValues,
            CreatedAt = DateTime.UtcNow, IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(), UserAgent = userAgent[..Math.Min(500, userAgent.Length)] });
    }

    private static AdminAccountResponse MapAccount(Taikhoan account) => new(account.TaiKhoanId, account.Email, account.TenTaiKhoan,
        account.TenTaiKhoan ?? account.Khachhang?.HoTen ?? account.Nhanvien?.HoTen ?? account.Email,
        account.VaiTroId, account.VaiTro.TenVaiTro, account.TrangThai, account.KhoaDen, account.NgayTao, account.LanDangNhapCuoi);
}
