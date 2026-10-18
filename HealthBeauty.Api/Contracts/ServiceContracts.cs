using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record ServiceResponse(int Id, int CategoryId, string Name, decimal Price, int DurationMinutes, string? Description, string? ImageUrl = null);
public sealed record ServiceCategoryResponse(int Id, string Name, string? Description);
public sealed record CreateServiceRequest([param: Required] int CategoryId, [param: Required, MaxLength(150)] string Name, [param: Range(0, 1000000000)] decimal Price, [param: Range(1, 1440)] int DurationMinutes, string? Description, string? ImageUrl = null);
public sealed record CreateCategoryRequest([param: Required, MaxLength(100)] string Name, string? Description);

internal static class CatalogImageUrl
{
    public static bool IsValid(string? value) => string.IsNullOrWhiteSpace(value)
        ? value is null || (value.Length <= 2048 && !value.Any(char.IsControl))
        : value.Length <= 2048 && !value.Any(char.IsControl)
          && Uri.TryCreate(value, UriKind.Absolute, out var uri)
          && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
          && !string.IsNullOrEmpty(uri.Host) && string.IsNullOrEmpty(uri.UserInfo);

    public static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
