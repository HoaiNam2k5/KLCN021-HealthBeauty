using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/media"), Authorize(Roles = "Admin,Manager,Reception")]
public sealed class MediaController(ICloudinaryImageStorage storage) : ControllerBase
{
    public const int MaximumImageBytes = 5 * 1024 * 1024;

    [HttpPost("images"), Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 6 * 1024 * 1024, MemoryBufferThreshold = 6 * 1024 * 1024)]
    public async Task<ActionResult<UploadImageResponse>> Upload([FromForm] UploadImageRequest request, CancellationToken ct)
    {
        if (request.File is null || request.File.Length == 0) return BadRequest("An image file is required.");
        if (request.File.Length > MaximumImageBytes) return StatusCode(StatusCodes.Status413PayloadTooLarge, "Image must not exceed 5 MB.");
        var contentType = request.File.ContentType.ToLowerInvariant();
        if (contentType is not ("image/png" or "image/jpeg" or "image/webp"))
            return BadRequest("Only PNG, JPEG and WebP images are accepted.");
        byte[] bytes;
        try
        {
            await using var source = request.File.OpenReadStream();
            using var output = new MemoryStream();
            var buffer = new byte[8192];
            int count;
            while ((count = await source.ReadAsync(buffer.AsMemory(0, Math.Min(buffer.Length, MaximumImageBytes + 1 - (int)output.Length)), ct)) != 0)
            {
                output.Write(buffer, 0, count);
                if (output.Length > MaximumImageBytes)
                    return StatusCode(StatusCodes.Status413PayloadTooLarge, "Image must not exceed 5 MB.");
            }
            bytes = output.ToArray();
        }
        catch (IOException) { return BadRequest("The image file could not be read."); }
        if (!HasImageSignature(bytes, contentType)) return BadRequest("Image content does not match its type.");
        if (!storage.IsConfigured) return StatusCode(StatusCodes.Status503ServiceUnavailable, "Image upload is not configured.");
        try { return StatusCode(StatusCodes.Status201Created, await storage.UploadAsync(bytes, contentType, ct)); }
        catch (TimeoutException) { return StatusCode(StatusCodes.Status504GatewayTimeout, "Image storage timed out. Please retry."); }
        catch (ImageStorageException) { return StatusCode(StatusCodes.Status502BadGateway, "Image storage is unavailable. Please retry."); }
    }

    private static bool HasImageSignature(byte[] bytes, string type) => type switch
    {
        "image/png" => bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }),
        "image/jpeg" => bytes.Length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255,
        "image/webp" => bytes.Length >= 12 && bytes.AsSpan(0, 4).SequenceEqual("RIFF"u8) && bytes.AsSpan(8, 4).SequenceEqual("WEBP"u8),
        _ => false
    };
}
