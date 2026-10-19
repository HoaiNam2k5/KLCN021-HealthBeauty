using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

namespace HealthBeauty.Api.Services;

public static class PasswordRecoveryRateLimiting
{
    public const string ForgotPolicy = "password-recovery-request";
    public const string ResetPolicy = "password-recovery-reset";

    public static IServiceCollection AddPasswordRecoveryRateLimiting(this IServiceCollection services) => services.AddRateLimiter(options =>
    {
        options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
        options.OnRejected = async (context, ct) => {
            context.HttpContext.Response.Headers.RetryAfter = "600";
            await context.HttpContext.Response.WriteAsJsonAsync(new { message = "Bạn đã thử quá nhiều lần. Vui lòng thử lại sau." }, ct);
        };
        foreach (var (name, limit) in new[] { (ForgotPolicy, 10), (ResetPolicy, 20) })
            options.AddPolicy(name, context => RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions { PermitLimit = limit, Window = TimeSpan.FromMinutes(10),
                    QueueLimit = 0, AutoReplenishment = true }));
    });
}
