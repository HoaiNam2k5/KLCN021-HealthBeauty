using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

namespace HealthBeauty.Api.Services;

public static class MobileAuthenticationRateLimiting
{
    public const string LoginPolicy = "mobile-auth-login";
    public const string VerifyPolicy = "mobile-auth-otp-verify";
    public const string ResendPolicy = "mobile-auth-otp-resend";
    public const string ChangePasswordPolicy = "customer-change-password";
    public const string AvatarPolicy = "customer-avatar";

    public static IServiceCollection AddMobileAuthenticationRateLimiting(this IServiceCollection services) => services.AddRateLimiter(options =>
    {
        foreach (var (name, limit) in new[] { (LoginPolicy, 30), (VerifyPolicy, 20), (ResendPolicy, 10), (ChangePasswordPolicy, 10), (AvatarPolicy, 20) })
            options.AddPolicy(name, context => RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = limit, Window = TimeSpan.FromMinutes(10), QueueLimit = 0, AutoReplenishment = true
                }));
    });
}
