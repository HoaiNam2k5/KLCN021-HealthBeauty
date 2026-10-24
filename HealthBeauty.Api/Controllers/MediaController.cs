using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/media"), Authorize(Roles = "Admin,Manager,Reception")]
public sealed class MediaController(ICloudinaryImageStorage storage) : ControllerBase
{
    public const int MaximumImageBytes = ImageUploadValidation.MaximumImageBytes;

    [HttpPost("images"), Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 6 * 1024 * 1024, MemoryBufferThreshold = 6 * 1024 * 1024)]
    public async Task<ActionResult<UploadImageResponse>> Upload([FromForm] UploadImageRequest request, CancellationToken ct)
    {
        var image = await ImageUploadValidation.ReadAsync(request.File, ct);
        if (image.Error is not null) return image.StatusCode == 400 ? BadRequest(image.Error) : StatusCode(image.StatusCode, image.Error);
        if (!storage.IsConfigured) return StatusCode(StatusCodes.Status503ServiceUnavailable, "Image upload is not configured.");
        try { return StatusCode(StatusCodes.Status201Created, await storage.UploadAsync(image.Bytes!, image.ContentType!, ct)); }
        catch (TimeoutException) { return StatusCode(StatusCodes.Status504GatewayTimeout, "Image storage timed out. Please retry."); }
        catch (ImageStorageException) { return StatusCode(StatusCodes.Status502BadGateway, "Image storage is unavailable. Please retry."); }
    }

}
