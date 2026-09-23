using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record ServiceResponse(int Id, int CategoryId, string Name, decimal Price, int DurationMinutes, string? Description);
public sealed record ServiceCategoryResponse(int Id, string Name, string? Description);
public sealed record CreateServiceRequest([property: Required] int CategoryId, [property: Required, MaxLength(150)] string Name, [property: Range(0, 1000000000)] decimal Price, [property: Range(1, 1440)] int DurationMinutes, string? Description);
public sealed record CreateCategoryRequest([property: Required, MaxLength(100)] string Name, string? Description);
