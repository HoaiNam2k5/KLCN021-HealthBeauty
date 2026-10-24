using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record RegisterRequest(
    [param: Required, EmailAddress] string Email,
    [param: Required, MinLength(8)] string Password,
    [param: Required, MaxLength(100)] string HoTen,
    [param: MaxLength(15)] string? SoDienThoai);

public sealed record LoginRequest([param: Required, EmailAddress] string Email, [param: Required] string Password);
public sealed record RefreshRequest([param: Required] string RefreshToken, [param: MaxLength(4096)] string? DeviceToken = null);
public sealed record GoogleLoginRequest(
    [param: Required, MaxLength(16384)] string IdToken,
    [param: MaxLength(255)] string? Email = null,
    [param: MaxLength(255)] string? GoogleId = null,
    [param: MaxLength(100)] string? FullName = null,
    [param: MaxLength(2048)] string? PhotoUrl = null);
public sealed record VerifyTwoFactorRequest(
    [param: Required, EmailAddress, MaxLength(255)] string Email,
    [param: Required, RegularExpression("^[0-9]{6}$")] string Otp);
public sealed record ResendTwoFactorRequest([param: Required, EmailAddress, MaxLength(255)] string Email);
public sealed record TwoFactorRequiredResponse(bool RequiresTwoFactor, string Email, string Message);
public sealed record AuthResponse(string AccessToken, string RefreshToken, DateTime AccessTokenExpiresAt, AccountResponse Account);
public sealed record AccountResponse(int Id, string Email, string? Name, string Role);
