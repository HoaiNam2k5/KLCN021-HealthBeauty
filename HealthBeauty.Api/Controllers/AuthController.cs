using System.Security.Claims;
using System.Text;
using System.Security.Cryptography;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/auth")]
public sealed class AuthController(Klcn021HealthBeautyContext db, IPasswordService passwords, ITokenService tokens, IConfiguration config) : ControllerBase
{
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        if (await db.Taikhoans.AnyAsync(x => x.Email == email, cancellationToken)) return Conflict("Email đã tồn tại.");
        var role = await db.Vaitros.FirstOrDefaultAsync(x => x.TenVaiTro == "Customer", cancellationToken);
        if (role is null) { role = new Vaitro { TenVaiTro = "Customer", MoTa = "Khách hàng" }; db.Vaitros.Add(role); await db.SaveChangesAsync(cancellationToken); }
        var account = new Taikhoan { Email = email, TenTaiKhoan = request.HoTen.Trim(), MatKhauHash = passwords.Hash(request.Password), VaiTroId = role.VaiTroId, TrangThai = true, NgayTao = DateTime.UtcNow };
        db.Taikhoans.Add(account); await db.SaveChangesAsync(cancellationToken);
        db.Khachhangs.Add(new Khachhang { TaiKhoanId = account.TaiKhoanId, HoTen = request.HoTen.Trim(), SoDienThoai = request.SoDienThoai, DiemThuong = 0 });
        await db.SaveChangesAsync(cancellationToken);
        account.VaiTro = role;
        return Ok(await IssueTokens(account, cancellationToken));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var account = await db.Taikhoans.Include(x => x.VaiTro).FirstOrDefaultAsync(x => x.Email == email, cancellationToken);
        if (account is null || !account.TrangThai || (account.KhoaDen is not null && account.KhoaDen > DateTime.UtcNow) || !passwords.Verify(request.Password, account.MatKhauHash))
            return Unauthorized("Email hoặc mật khẩu không đúng.");
        account.SoLanDangNhapSai = 0; account.LanDangNhapCuoi = DateTime.UtcNow;
        db.Dangnhaplogs.Add(new Dangnhaplog { TaiKhoanId = account.TaiKhoanId, Email = email, ThanhCong = true, IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() });
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await IssueTokens(account, cancellationToken));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest request, CancellationToken cancellationToken)
    {
        var hash = tokens.HashRefreshToken(request.RefreshToken);
        var stored = await db.Refreshtokens.Include(x => x.TaiKhoan).ThenInclude(x => x.VaiTro).FirstOrDefaultAsync(x => x.TokenHash == hash && x.RevokedAt == null, cancellationToken);
        if (stored is null || stored.ExpiresAt <= DateTime.UtcNow || !stored.TaiKhoan.TrangThai) return Unauthorized("Refresh token không hợp lệ hoặc đã hết hạn.");
        stored.RevokedAt = DateTime.UtcNow; stored.RevokedByIp = HttpContext.Connection.RemoteIpAddress?.ToString();
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await IssueTokens(stored.TaiKhoan, cancellationToken));
    }

    [Authorize, HttpPost("logout")]
    public async Task<IActionResult> Logout(RefreshRequest request, CancellationToken cancellationToken)
    {
        var hash = tokens.HashRefreshToken(request.RefreshToken);
        var token = await db.Refreshtokens.FirstOrDefaultAsync(x => x.TokenHash == hash && x.RevokedAt == null, cancellationToken);
        if (token is not null) { token.RevokedAt = DateTime.UtcNow; token.RevokedByIp = HttpContext.Connection.RemoteIpAddress?.ToString(); await db.SaveChangesAsync(cancellationToken); }
        return NoContent();
    }

    private async Task<AuthResponse> IssueTokens(Taikhoan account, CancellationToken cancellationToken)
    {
        var access = tokens.CreateAccessToken(account); var refresh = tokens.CreateRefreshToken();
        var days = config.GetSection("Jwt").GetValue<int>("RefreshTokenDays", 14);
        db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = account.TaiKhoanId, TokenHash = tokens.HashRefreshToken(refresh), CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddDays(days), CreatedByIp = HttpContext.Connection.RemoteIpAddress?.ToString() });
        await db.SaveChangesAsync(cancellationToken);
        return new AuthResponse(access.Token, refresh, access.ExpiresAt, new AccountResponse(account.TaiKhoanId, account.Email, account.TenTaiKhoan, account.VaiTro?.TenVaiTro ?? "Customer"));
    }
}
