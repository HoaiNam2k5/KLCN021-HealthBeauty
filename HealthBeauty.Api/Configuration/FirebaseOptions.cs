namespace HealthBeauty.Api.Configuration;

public sealed class FirebaseOptions
{
    public const string SectionName = "Firebase";
    public bool Enabled { get; set; }
    public string CredentialsPath { get; set; } = "";
    public string? CredentialFile { get; set; }
    public string? ProjectId { get; set; }
}
