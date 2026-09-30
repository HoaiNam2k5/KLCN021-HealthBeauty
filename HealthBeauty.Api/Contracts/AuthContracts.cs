using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record RegisterRequest(
    [param: Required, EmailAddress] string Email,
    [param: Required, MinLength(8)] string Password,
    [param: Required, MaxLength(100)] string HoTen,
    [param: MaxLength(15)] string? SoDienThoai);

public sealed record LoginRequest([param: Required, EmailAddress] string Email, [param: Required] string Password);
public sealed record RefreshRequest([param: Required] string RefreshToken);
public sealed record AuthResponse(string AccessToken, string RefreshToken, DateTime AccessTokenExpiresAt, AccountResponse Account);
public sealed record AccountResponse(int Id, string Email, string? Name, string Role);
