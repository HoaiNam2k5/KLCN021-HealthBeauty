using System.Security.Claims;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public sealed class AccountTokenValidation(Klcn021HealthBeautyContext db) : JwtBearerEvents
{
    public override async Task TokenValidated(TokenValidatedContext context)
    {
        var identifiers = context.Principal?.FindAll(ClaimTypes.NameIdentifier).Select(x => x.Value).Distinct().ToArray();
        if (identifiers is not { Length: 1 } || !int.TryParse(identifiers[0], out var accountId) || accountId <= 0)
        {
            context.Fail("Invalid account identity.");
            return;
        }
        var account = await db.Taikhoans.AsNoTracking().Include(x => x.VaiTro)
            .FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, context.HttpContext.RequestAborted);
        var stamps = context.Principal!.FindAll("security_stamp").Select(x => x.Value).ToArray();
        var stampMatches = string.IsNullOrEmpty(account?.SecurityStamp)
            ? stamps.Length == 0 || (stamps.Length == 1 && stamps[0] == string.Empty)
            : stamps.Length == 1 && string.Equals(stamps[0], account.SecurityStamp, StringComparison.Ordinal);
        var roles = context.Principal!.FindAll(ClaimTypes.Role).Select(x => x.Value).ToArray();
        if (!stampMatches || account is null || !account.TrangThai || account.KhoaDen > DateTime.UtcNow ||
            account.VaiTro is null || string.IsNullOrWhiteSpace(account.VaiTro.TenVaiTro) ||
            roles.Length != 1 || roles[0] != account.VaiTro.TenVaiTro)
            context.Fail("Account is unavailable or its authorization has changed.");
    }
}
