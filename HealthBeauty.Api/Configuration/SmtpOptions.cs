using System.Net.Mail;

namespace HealthBeauty.Api.Configuration;

public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";
    public bool Enabled { get; set; }
    public string Host { get; set; } = "";
    public int Port { get; set; } = 587;
    public string UserName { get; set; } = "";
    public string Password { get; set; } = "";
    public string SenderEmail { get; set; } = "";
    public string SenderName { get; set; } = "HealthBeauty";
    public bool EnableSsl { get; set; } = true;

    public bool IsConfigured => Enabled && EnableSsl && Port is > 0 and <= 65535
        && !string.IsNullOrWhiteSpace(Host) && !Host.Contains("://", StringComparison.Ordinal)
        && !Host.Any(char.IsWhiteSpace)
        && !string.IsNullOrWhiteSpace(UserName) && !string.IsNullOrWhiteSpace(Password)
        && MailAddress.TryCreate(SenderEmail, out _)
        && !string.IsNullOrWhiteSpace(SenderName) && !SenderName.Contains('\r') && !SenderName.Contains('\n');
}
