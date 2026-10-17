using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record ForgotPasswordRequest([param: Required, EmailAddress, MaxLength(255)] string Email);
public sealed record ForgotPasswordResponse(string Message);
public sealed record ResetPasswordRequest(
    [param: Required, EmailAddress, MaxLength(255)] string Email,
    [param: Required, RegularExpression("^[0-9]{6}$")] string Otp,
    [param: Required, MinLength(8), MaxLength(128)] string NewPassword);
public sealed record ResetPasswordResponse(string Message);
