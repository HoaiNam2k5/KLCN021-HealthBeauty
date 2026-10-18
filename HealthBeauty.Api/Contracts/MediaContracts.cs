using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed class UploadImageRequest
{
    [Required]
    public IFormFile? File { get; set; }
}

public sealed record UploadImageResponse(string ImageUrl, string PublicId);
