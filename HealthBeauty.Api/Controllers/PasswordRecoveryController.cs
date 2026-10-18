using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace HealthBeauty.Api.Controllers;

[ApiController, AllowAnonymous, Route("api/v1/auth")]
public sealed class PasswordRecoveryController(PasswordRecoveryService recovery) : ControllerBase
{
    public const string ForgotMessage = "Nếu email thuộc tài khoản đang hoạt động, mã xác nhận sẽ được gửi đến email đó. Vui lòng kiểm tra hộp thư và thư rác.";

    [HttpPost("forgot-password"), EnableRateLimiting(PasswordRecoveryRateLimiting.ForgotPolicy)]
    public async Task<ActionResult<ForgotPasswordResponse>> ForgotPassword(ForgotPasswordRequest request, CancellationToken ct)
    {
        await recovery.RequestAsync(request.Email, ct);
        return Ok(new ForgotPasswordResponse(ForgotMessage));
    }

    [HttpPost("reset-password"), EnableRateLimiting(PasswordRecoveryRateLimiting.ResetPolicy)]
    public async Task<ActionResult<ResetPasswordResponse>> ResetPassword(ResetPasswordRequest request, CancellationToken ct)
    {
        if (!await recovery.ResetAsync(request.Email, request.Otp, request.NewPassword, HttpContext.Connection.RemoteIpAddress?.ToString(), ct))
            return BadRequest(new ResetPasswordResponse("Mã xác nhận không hợp lệ hoặc đã hết hạn."));
        return Ok(new ResetPasswordResponse("Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới."));
    }
}
