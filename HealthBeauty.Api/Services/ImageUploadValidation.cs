using Microsoft.AspNetCore.Http;

namespace HealthBeauty.Api.Services;

public static class ImageUploadValidation
{
    public const int MaximumImageBytes = 5 * 1024 * 1024;

    public sealed record Result(byte[]? Bytes, string? ContentType, int StatusCode = 200, string? Error = null);

    public static async Task<Result> ReadAsync(IFormFile? file, CancellationToken ct)
    {
        if (file is null || file.Length == 0) return new(null, null, 400, "An image file is required.");
        if (file.Length > MaximumImageBytes) return new(null, null, 413, "Image must not exceed 5 MB.");
        var type = file.ContentType.ToLowerInvariant();
        if (type is not ("image/png" or "image/jpeg" or "image/webp"))
            return new(null, null, 400, "Only PNG, JPEG and WebP images are accepted.");
        byte[] bytes;
        try
        {
            await using var source = file.OpenReadStream();
            using var output = new MemoryStream();
            var buffer = new byte[8192];
            int count;
            while ((count = await source.ReadAsync(buffer.AsMemory(0, Math.Min(buffer.Length, MaximumImageBytes + 1 - (int)output.Length)), ct)) != 0)
            {
                output.Write(buffer, 0, count);
                if (output.Length > MaximumImageBytes) return new(null, null, 413, "Image must not exceed 5 MB.");
            }
            bytes = output.ToArray();
        }
        catch (IOException) { return new(null, null, 400, "The image file could not be read."); }
        var valid = type switch
        {
            "image/png" => bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }),
            "image/jpeg" => bytes.Length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255,
            "image/webp" => bytes.Length >= 12 && bytes.AsSpan(0, 4).SequenceEqual("RIFF"u8) && bytes.AsSpan(8, 4).SequenceEqual("WEBP"u8),
            _ => false
        };
        return valid ? new(bytes, type) : new(null, null, 400, "Image content does not match its type.");
    }
}
