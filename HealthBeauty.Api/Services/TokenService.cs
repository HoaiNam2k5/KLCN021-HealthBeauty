using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using HealthBeauty.Api.Models;
using Microsoft.IdentityModel.Tokens;

namespace HealthBeauty.Api.Services;

public interface ITokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(Taikhoan account);
    string CreateRefreshToken();
    string HashRefreshToken(string token);
}

public sealed class TokenService(IConfiguration configuration) : ITokenService
{
    public (string Token, DateTime ExpiresAt) CreateAccessToken(Taikhoan account)
    {
        var section = configuration.GetSection("Jwt");
        var expires = DateTime.UtcNow.AddMinutes(section.GetValue<int>("AccessTokenMinutes", 30));
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, account.TaiKhoanId.ToString()),
            new Claim(ClaimTypes.NameIdentifier, account.TaiKhoanId.ToString()),
            new Claim(ClaimTypes.Email, account.Email),
            new Claim(ClaimTypes.Role, account.VaiTro?.TenVaiTro ?? "Customer")
        };
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(section["Key"]!));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(section["Issuer"], section["Audience"], claims, expires: expires, signingCredentials: credentials);
        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }

    public string CreateRefreshToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
    public string HashRefreshToken(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
