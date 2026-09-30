using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record ServiceResponse(int Id, int CategoryId, string Name, decimal Price, int DurationMinutes, string? Description);
public sealed record ServiceCategoryResponse(int Id, string Name, string? Description);
public sealed record CreateServiceRequest([param: Required] int CategoryId, [param: Required, MaxLength(150)] string Name, [param: Range(0, 1000000000)] decimal Price, [param: Range(1, 1440)] int DurationMinutes, string? Description);
public sealed record CreateCategoryRequest([param: Required, MaxLength(100)] string Name, string? Description);
