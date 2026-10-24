using System.Security.Cryptography;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

public sealed partial class AuthController
{
    private bool RequiresLoginOtp(Taikhoan account) =>
        config.GetValue<bool>("Authentication:TwoFactor:Enabled") && account.VaiTro.TenVaiTro == "Customer";

    private async Task<ActionResult<AuthResponse>> BeginLoginOtp(Taikhoan account, CancellationToken ct)
    {
        var service = HttpContext.RequestServices.GetService<LoginTwoFactorService>();
        if (service is null || !await service.StartAsync(account.TaiKhoanId, ct))
            return StatusCode(503, new { message = "Chưa thể gửi mã đăng nhập. Vui lòng thử lại sau hoặc liên hệ quản trị viên." });
        return Ok(new TwoFactorRequiredResponse(true, account.Email,
            "Vui lòng nhập mã xác nhận đăng nhập đã gửi đến email của bạn."));
    }

    [HttpPost("verify-2fa"), EnableRateLimiting(MobileAuthenticationRateLimiting.VerifyPolicy)]
    public async Task<ActionResult<AuthResponse>> VerifyTwoFactor(VerifyTwoFactorRequest request,
        [FromServices] LoginTwoFactorService service, CancellationToken ct)
    {
        var account = await service.VerifyAsync(request.Email, request.Otp, ct);
        if (account is null) return BadRequest(new { message = "Mã xác nhận không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại nếu đã thử quá nhiều lần." });
        var userAgent = Request.Headers.UserAgent.ToString();
        db.Dangnhaplogs.Add(new Dangnhaplog { TaiKhoanId = account.TaiKhoanId, Email = account.Email,
            ThanhCong = true, CreatedAt = DateTime.UtcNow, IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
            UserAgent = userAgent[..Math.Min(userAgent.Length, 500)] });
        return Ok(await IssueTokens(account, ct));
    }

    [HttpPost("resend-2fa"), EnableRateLimiting(MobileAuthenticationRateLimiting.ResendPolicy)]
    public async Task<IActionResult> ResendTwoFactor(ResendTwoFactorRequest request,
        [FromServices] LoginTwoFactorService service, CancellationToken ct)
    {
        // A generic response avoids turning this endpoint into an account/challenge lookup.
        await service.ResendAsync(request.Email, ct);
        return Ok(new { message = "Nếu phiên xác thực còn hợp lệ, mã sẽ được gửi lại. Vui lòng đợi ít nhất 60 giây giữa các lần gửi." });
    }

    [HttpPost("google"), EnableRateLimiting(MobileAuthenticationRateLimiting.LoginPolicy)]
    public async Task<ActionResult<AuthResponse>> Google(GoogleLoginRequest request,
        [FromServices] IGoogleIdentityVerifier verifier, CancellationToken ct)
    {
        if (!verifier.IsConfigured) return StatusCode(503, new { message = "Đăng nhập Google chưa được cấu hình." });
        VerifiedGoogleIdentity? identity;
        try { identity = await verifier.VerifyAsync(request.IdToken, ct); }
        catch (HttpRequestException) { return StatusCode(503, new { message = "Chưa thể xác minh với Google. Vui lòng thử lại." }); }
        if (identity is null) return Unauthorized(new { message = "Thông tin đăng nhập Google không hợp lệ hoặc đã hết hạn." });

        var now = DateTime.UtcNow;
        var link = await db.Externallogins.Include(x => x.TaiKhoan).ThenInclude(x => x.VaiTro)
            .FirstOrDefaultAsync(x => x.Provider == "Google" && x.ProviderUserId == identity.Subject, ct);
        var account = link?.TaiKhoan;
        if (account is null)
        {
            account = await db.Taikhoans.Include(x => x.VaiTro)
                .FirstOrDefaultAsync(x => x.Email.ToLower() == identity.Email, ct);
            if (account is not null && !AuthoritativeGoogleEmail(identity))
                return Conflict(new { message = "Tài khoản email này đã tồn tại. Vui lòng đăng nhập bằng mật khẩu để xác minh tài khoản hiện có." });
        }
        if (account is not null && (!account.TrangThai || account.KhoaDen > now))
            return Unauthorized(new { message = "Tài khoản không hoạt động hoặc đang tạm khóa." });
        if (account is not null && account.VaiTro.TenVaiTro != "Customer")
            return StatusCode(403, new { message = "Đăng nhập Google trên ứng dụng chỉ dành cho khách hàng." });

        await using var transaction = db.Database.IsRelational() ? await db.Database.BeginTransactionAsync(ct) : null;
        try
        {
            if (account is null)
            {
                var role = await db.Vaitros.SingleOrDefaultAsync(x => x.TenVaiTro == "Customer", ct);
                if (role is null) return StatusCode(503, new { message = "Vai trò khách hàng chưa được cấu hình." });
                var name = string.IsNullOrWhiteSpace(identity.Name) ? identity.Email : identity.Name.Trim();
                account = new Taikhoan
                {
                    Email = identity.Email, TenTaiKhoan = name[..Math.Min(name.Length, 100)], VaiTro = role,
                    TrangThai = true, NgayTao = now, SecurityStamp = Guid.NewGuid().ToString("N"),
                    MatKhauHash = passwords.Hash(Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)))
                };
                account.Khachhang = new Khachhang { HoTen = account.TenTaiKhoan, CreatedAt = DateTime.Now, DiemThuong = 0 };
                db.Taikhoans.Add(account);
            }
            else if (!await db.Khachhangs.AnyAsync(x => x.TaiKhoanId == account.TaiKhoanId, ct))
            {
                db.Khachhangs.Add(new Khachhang { TaiKhoanId = account.TaiKhoanId,
                    HoTen = account.TenTaiKhoan ?? account.Email, CreatedAt = DateTime.Now, DiemThuong = 0 });
            }
            if (link is null) db.Externallogins.Add(new Externallogin
            {
                TaiKhoan = account, Provider = "Google", ProviderUserId = identity.Subject,
                Email = identity.Email, CreatedAt = now
            });
            account.LanDangNhapCuoi = now;
            account.SoLanDangNhapSai = 0;
            account.KhoaDen = null;
            var userAgent = Request.Headers.UserAgent.ToString();
            db.Dangnhaplogs.Add(new Dangnhaplog
            {
                TaiKhoan = account, Email = account.Email, ThanhCong = true, CreatedAt = now,
                IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                UserAgent = userAgent[..Math.Min(userAgent.Length, 500)]
            });
            await db.SaveChangesAsync(ct);
            if (transaction is not null) await transaction.CommitAsync(ct);
        }
        catch (DbUpdateException exception) when (exception.InnerException is SqlException { Number: 2601 or 2627 })
        {
            if (transaction is not null) await transaction.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            return Conflict(new { message = "Tài khoản vừa được cập nhật. Vui lòng thử đăng nhập Google lại." });
        }
        if (transaction is not null) await transaction.DisposeAsync();
        return Ok(await IssueTokens(account, ct));
    }

    private static bool AuthoritativeGoogleEmail(VerifiedGoogleIdentity identity) => identity.EmailVerified
        && (identity.Email.EndsWith("@gmail.com", StringComparison.OrdinalIgnoreCase)
            || !string.IsNullOrWhiteSpace(identity.HostedDomain));
}
