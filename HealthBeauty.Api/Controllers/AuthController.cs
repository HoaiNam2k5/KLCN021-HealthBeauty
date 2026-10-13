using System.Security.Claims;
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
        var now = DateTime.UtcNow;
        string? failure = account is null ? "AccountNotFound" : !account.TrangThai ? "AccountInactive" : account.KhoaDen > now ? "AccountLocked" : null;
        if (failure is null && account is not null)
        {
            if (account.KhoaDen.HasValue) { account.KhoaDen = null; account.SoLanDangNhapSai = 0; }
            if (!passwords.Verify(request.Password, account.MatKhauHash))
            {
                var limit = Math.Clamp(config.GetValue<int>("Authentication:MaxFailedAttempts", 5), 1, 20);
                var minutes = Math.Clamp(config.GetValue<int>("Authentication:LockoutMinutes", 15), 1, 1440);
                account.SoLanDangNhapSai = account.SoLanDangNhapSai >= limit ? limit : Math.Max(0, account.SoLanDangNhapSai) + 1;
                if (account.SoLanDangNhapSai >= limit) account.KhoaDen = now.AddMinutes(minutes);
                failure = "InvalidPassword";
            }
        }
        var userAgent = Request.Headers.UserAgent.ToString();
        db.Dangnhaplogs.Add(new Dangnhaplog { TaiKhoanId = account?.TaiKhoanId, Email = email.Length > 255 ? email[..255] : email,
            ThanhCong = failure is null, LyDoThatBai = failure, CreatedAt = now,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(), UserAgent = userAgent.Length > 500 ? userAgent[..500] : userAgent });
        if (failure is not null)
        {
            await db.SaveChangesAsync(cancellationToken);
            return Unauthorized("Email hoặc mật khẩu không đúng.");
        }
        account!.SoLanDangNhapSai = 0; account.KhoaDen = null; account.LanDangNhapCuoi = now;
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await IssueTokens(account, cancellationToken));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest request, CancellationToken cancellationToken)
    {
        var hash = tokens.HashRefreshToken(request.RefreshToken);
        var stored = await db.Refreshtokens.Include(x => x.TaiKhoan).ThenInclude(x => x.VaiTro).FirstOrDefaultAsync(x => x.TokenHash == hash && x.RevokedAt == null, cancellationToken);
        if (stored is null || stored.ExpiresAt <= DateTime.UtcNow || !stored.TaiKhoan.TrangThai || stored.TaiKhoan.KhoaDen > DateTime.UtcNow) return Unauthorized("Refresh token không hợp lệ hoặc đã hết hạn.");
        stored.RevokedAt = DateTime.UtcNow; stored.RevokedByIp = HttpContext.Connection.RemoteIpAddress?.ToString();
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await IssueTokens(stored.TaiKhoan, cancellationToken));
    }

    [Authorize, HttpPost("logout")]
    public async Task<IActionResult> Logout(RefreshRequest request, CancellationToken cancellationToken)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var accountId)) return Unauthorized();
        var hash = tokens.HashRefreshToken(request.RefreshToken);
        var token = await db.Refreshtokens.FirstOrDefaultAsync(x => x.TokenHash == hash && x.TaiKhoanId == accountId && x.RevokedAt == null, cancellationToken);
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
