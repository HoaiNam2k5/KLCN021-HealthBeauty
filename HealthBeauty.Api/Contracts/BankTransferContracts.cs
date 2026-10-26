using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record BankTransferResponse(int InvoiceId, decimal Amount, string Status,
    string BankName, string BankCode, string AccountNumber, string AccountName,
    string TransferContent, string QrImageUrl);

public sealed record PackageBankTransferResponse(int PurchaseId, decimal Amount, string Status,
    string BankName, string BankCode, string AccountNumber, string AccountName,
    string TransferContent, string QrImageUrl);

// SePay bank-transaction webhook, not the separate payment-gateway/IPN API.
public sealed record SePayWebhookRequest(
    [param: Range(1, long.MaxValue)] long Id,
    [param: Required, StringLength(100)] string Gateway,
    [param: Required, StringLength(19)] string AccountNumber,
    [param: Required, StringLength(5)] string TransferType,
    decimal TransferAmount,
    [param: StringLength(100)] string? Code,
    [param: StringLength(2000)] string? Content,
    [param: StringLength(100)] string? ReferenceCode,
    [param: Required, StringLength(30)] string TransactionDate);
