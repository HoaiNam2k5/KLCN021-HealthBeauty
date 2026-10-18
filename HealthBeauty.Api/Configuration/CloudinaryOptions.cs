using System.Text.RegularExpressions;

namespace HealthBeauty.Api.Configuration;

public sealed class CloudinaryOptions
{
    public const string SectionName = "Cloudinary";
    public bool Enabled { get; set; }
    public string CloudName { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public string ApiSecret { get; set; } = "";
    public string Folder { get; set; } = "healthbeauty/catalog";

    public bool IsConfigured => Enabled && !string.IsNullOrWhiteSpace(CloudName) && Regex.IsMatch(CloudName, @"\A[A-Za-z0-9_-]{1,100}\z")
        && !string.IsNullOrWhiteSpace(ApiKey) && !ApiKey.Any(char.IsControl)
        && !string.IsNullOrWhiteSpace(ApiSecret) && !ApiSecret.Any(char.IsControl)
        && !string.IsNullOrWhiteSpace(Folder) && Regex.IsMatch(Folder, @"\A[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*\z") && Folder.Length <= 150;
}
