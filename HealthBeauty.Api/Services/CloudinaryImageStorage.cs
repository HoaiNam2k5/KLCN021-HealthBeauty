using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Contracts;
using Microsoft.Extensions.Options;

namespace HealthBeauty.Api.Services;

public interface ICloudinaryImageStorage
{
    bool IsConfigured { get; }
    Task<UploadImageResponse> UploadAsync(byte[] image, string contentType, CancellationToken ct);
}

public sealed class ImageStorageException : Exception
{
    public ImageStorageException() : base("Image storage provider failed.") { }
}

public sealed class CloudinaryImageStorage(HttpClient client, IOptions<CloudinaryOptions> options, TimeProvider clock)
    : ICloudinaryImageStorage
{
    public bool IsConfigured => options.Value.IsConfigured;

    public async Task<UploadImageResponse> UploadAsync(byte[] image, string contentType, CancellationToken ct)
    {
        if (!IsConfigured) throw new InvalidOperationException("Image storage is not configured.");
        var config = options.Value;
        var parameters = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["folder"] = config.Folder,
            ["overwrite"] = "false",
            ["public_id"] = Guid.NewGuid().ToString("N"),
            ["timestamp"] = clock.GetUtcNow().ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)
        };
        // Cloudinary authenticates sorted upload parameters plus the secret, excluding file/api_key.
        var toSign = string.Join("&", parameters.Select(x => $"{x.Key}={x.Value}")) + config.ApiSecret;
        var signature = Convert.ToHexString(SHA1.HashData(Encoding.UTF8.GetBytes(toSign))).ToLowerInvariant();
        using var form = new MultipartFormDataContent();
        foreach (var parameter in parameters) form.Add(new StringContent(parameter.Value), parameter.Key);
        form.Add(new StringContent(config.ApiKey), "api_key");
        form.Add(new StringContent(signature), "signature");
        var file = new ByteArrayContent(image);
        file.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        var extension = contentType == "image/png" ? "png" : contentType == "image/webp" ? "webp" : "jpg";
        form.Add(file, "file", $"image.{extension}");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(30));
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post,
                $"https://api.cloudinary.com/v1_1/{config.CloudName}/image/upload") { Content = form };
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            if (!response.IsSuccessStatusCode) throw new ImageStorageException();
            await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
            using var output = new MemoryStream();
            var buffer = new byte[4096];
            int count;
            while ((count = await stream.ReadAsync(buffer, timeout.Token)) != 0)
            {
                if (output.Length + count > 65536) throw new ImageStorageException();
                output.Write(buffer, 0, count);
            }
            using var json = JsonDocument.Parse(output.ToArray());
            var root = json.RootElement;
            if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty("secure_url", out var urlProperty) || urlProperty.ValueKind != JsonValueKind.String
                || !root.TryGetProperty("public_id", out var idProperty) || idProperty.ValueKind != JsonValueKind.String)
                throw new ImageStorageException();
            var url = urlProperty.GetString();
            var id = idProperty.GetString();
            if (url is null || url.Length > 2048 || url.Any(char.IsControl)
                || !Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps
                || uri.Host != "res.cloudinary.com" || !string.IsNullOrEmpty(uri.UserInfo)
                || string.IsNullOrWhiteSpace(id) || id.Length > 255 || id.Any(char.IsControl))
                throw new ImageStorageException();
            return new UploadImageResponse(url, id);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        { throw new TimeoutException("Image storage timed out."); }
        catch (HttpRequestException) { throw new ImageStorageException(); }
        catch (IOException) { throw new ImageStorageException(); }
        catch (JsonException) { throw new ImageStorageException(); }
    }
}

public static class CloudinaryImageRegistration
{
    public static IServiceCollection AddCloudinaryImages(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<CloudinaryOptions>(configuration.GetSection(CloudinaryOptions.SectionName));
        services.AddHttpClient<ICloudinaryImageStorage, CloudinaryImageStorage>(client => client.Timeout = TimeSpan.FromSeconds(30))
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        return services;
    }
}
