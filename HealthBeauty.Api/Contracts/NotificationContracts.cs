using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record DeviceTokenRequest(
    [param: Required, MaxLength(500)] string Token,
    [param: Required, RegularExpression("^(android|ios|web)$")] string DeviceType);
public sealed record NotificationResponse(int Id, string Title, string Body, string Type, string? Data, bool IsRead, DateTime CreatedAt);
