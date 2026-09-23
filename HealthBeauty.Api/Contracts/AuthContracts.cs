using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record RegisterRequest(
    [property: Required, EmailAddress] string Email,
    [property: Required, MinLength(8)] string Password,
    [property: Required, MaxLength(100)] string HoTen,
    [property: MaxLength(15)] string? SoDienThoai);

public sealed record LoginRequest([property: Required, EmailAddress] string Email, [property: Required] string Password);
public sealed record RefreshRequest([property: Required] string RefreshToken);
public sealed record AuthResponse(string AccessToken, string RefreshToken, DateTime AccessTokenExpiresAt, AccountResponse Account);
public sealed record AccountResponse(int Id, string Email, string? Name, string Role);
