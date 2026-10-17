using Microsoft.AspNetCore.Cors.Infrastructure;

namespace HealthBeauty.Api.Services;

public static class DevelopmentClientCors
{
    public const string PolicyName = "DevelopmentClients";

    public static void Configure(CorsPolicyBuilder policy) => policy
        .WithOrigins("http://localhost:5173", "http://127.0.0.1:5173",
            "http://localhost:5174", "http://127.0.0.1:5174")
        .AllowAnyHeader()
        .AllowAnyMethod();
}
