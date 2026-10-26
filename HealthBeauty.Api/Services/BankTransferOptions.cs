using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace HealthBeauty.Api.Services;

public sealed class BankTransferOptions
{
    public const string Section = "Payments:SePay";
    public bool Enabled { get; set; }
    public string BankName { get; set; } = "";
    public string BankCode { get; set; } = "";
    public string AccountNumber { get; set; } = "";
    public string AccountName { get; set; } = "";
    public string WebhookApiKey { get; set; } = "";

    // BankName must equal the gateway name SePay sends, e.g. Vietcombank.
    // BankCode is the bank identifier accepted by SePay's QR image service.
    public bool IsReady => Enabled && Regex.IsMatch(BankName, @"^[A-Za-z0-9 ]{2,100}$")
        && Regex.IsMatch(BankCode, @"^[A-Za-z0-9]{2,30}$")
        && Regex.IsMatch(AccountNumber, @"^[A-Za-z0-9]{1,19}$")
        && !string.IsNullOrWhiteSpace(AccountName) && AccountName.Length <= 100
        && WebhookApiKey.Length >= 32 && WebhookApiKey.Length <= 256
        && !WebhookApiKey.Any(char.IsWhiteSpace);

    public bool Authorizes(string? header)
    {
        const string prefix = "Apikey ";
        if (!IsReady || header is null || !header.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return false;
        var received = header[prefix.Length..];
        if (received.Length > 256) return false;
        return CryptographicOperations.FixedTimeEquals(SHA256.HashData(Encoding.UTF8.GetBytes(received)),
            SHA256.HashData(Encoding.UTF8.GetBytes(WebhookApiKey)));
    }

    public static string Reference(int invoiceId) => "HB" + invoiceId.ToString(CultureInfo.InvariantCulture);
    public static string PackageReference(int purchaseId) => "HP" + purchaseId.ToString(CultureInfo.InvariantCulture);

    public string QrImage(int invoiceId, decimal amount) => QrImage(Reference(invoiceId), amount);
    public string PackageQrImage(int purchaseId, decimal amount) => QrImage(PackageReference(purchaseId), amount);
    private string QrImage(string reference, decimal amount) =>
        "https://vietqr.app/img?acc=" + Uri.EscapeDataString(AccountNumber)
        + "&bank=" + Uri.EscapeDataString(BankCode)
        + "&amount=" + amount.ToString("0", CultureInfo.InvariantCulture)
        + "&des=" + Uri.EscapeDataString(reference) + "&template=compact";
}
