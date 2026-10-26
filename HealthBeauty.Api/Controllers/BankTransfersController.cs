using System.Globalization;
using System.Security.Claims;
using System.Text.RegularExpressions;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/payments")]
public sealed class BankTransfersController(Klcn021HealthBeautyContext db,
    IOptions<BankTransferOptions> options, INotificationService notifications) : ControllerBase
{
    private const string Unavailable = "Thanh toán chuyển khoản đang được cấu hình. Vui lòng liên hệ lễ tân để thanh toán.";

    [Authorize, HttpPost("/api/v1/invoices/{id:int}/bank-transfer")]
    public async Task<IActionResult> Instructions(int id, CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var accountId)) return Unauthorized();
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        var query = db.Hoadons.AsNoTracking().Where(x => x.HoaDonId == id);
        if (!isStaff) query = query.Where(x => db.Khachhangs.Any(c => c.KhachHangId == x.KhachHangId && c.TaiKhoanId == accountId));
        var invoice = await query.FirstOrDefaultAsync(ct);
        if (invoice is null) return NotFound();
        if (invoice.TrangThai != "ChuaThanhToan" || invoice.TongTienSauGiam <= 0
            || decimal.Truncate(invoice.TongTienSauGiam) != invoice.TongTienSauGiam)
            return Conflict("Hóa đơn này không cần hoặc không thể thanh toán chuyển khoản.");
        var config = options.Value;
        if (!config.IsReady) return StatusCode(503, Unavailable);
        return Ok(new BankTransferResponse(invoice.HoaDonId, invoice.TongTienSauGiam, invoice.TrangThai,
            config.BankName, config.BankCode, config.AccountNumber, config.AccountName,
            BankTransferOptions.Reference(id), config.QrImage(id, invoice.TongTienSauGiam)));
    }

    [Authorize, HttpPost("/api/v1/service-packages/purchases/{id:int}/bank-transfer")]
    public async Task<IActionResult> PackageInstructions(int id, CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var accountId)) return Unauthorized();
        var management = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        var query = db.CustomerPackages.AsNoTracking().Where(x => x.Id == id);
        if (!management) query = query.Where(x => db.Khachhangs.Any(c => c.KhachHangId == x.CustomerId && c.TaiKhoanId == accountId));
        var purchase = await query.SingleOrDefaultAsync(ct);
        if (purchase is null) return NotFound();
        if (purchase.Status != "Pending" || purchase.Price <= 0 || decimal.Truncate(purchase.Price) != purchase.Price)
            return Conflict("Gói dịch vụ này không cần hoặc không thể thanh toán chuyển khoản.");
        if (!await db.Khachhangs.AnyAsync(x => x.KhachHangId == purchase.CustomerId && x.TaiKhoanId.HasValue, ct))
            return Conflict("Khách hàng chưa có tài khoản. Vui lòng thanh toán gói tại quầy lễ tân.");
        var config = options.Value;
        if (!config.IsReady) return StatusCode(503, Unavailable);
        return Ok(new PackageBankTransferResponse(purchase.Id, purchase.Price, purchase.Status,
            config.BankName, config.BankCode, config.AccountNumber, config.AccountName,
            BankTransferOptions.PackageReference(id), config.PackageQrImage(id, purchase.Price)));
    }

    [AllowAnonymous, HttpPost("sepay/webhook"), RequestSizeLimit(16384)]
    public async Task<IActionResult> Webhook(SePayWebhookRequest request, CancellationToken ct)
    {
        var config = options.Value;
        if (!config.IsReady) return StatusCode(503, new { success = false });
        if (!config.Authorizes(Request.Headers.Authorization.ToString())) return Unauthorized(new { success = false });
        if (!ValidPayload(request, out var paidAt)) return BadRequest(new { success = false });
        // The database PK is the provider's transaction id, including ignored transfers.
        if (await db.SePayTransactions.AsNoTracking().AnyAsync(x => x.Id == request.Id, ct))
            return Ok(new { success = true });

        var transaction = new SePayTransaction
        {
            Id = request.Id, Amount = request.TransferAmount, Gateway = request.Gateway,
            AccountNumber = request.AccountNumber, TransferType = request.TransferType,
            Content = request.Content ?? "", ReferenceCode = request.ReferenceCode,
            ReceivedAt = DateTime.UtcNow, TransactionAt = paidAt, Outcome = "UnmatchedReference"
        };
        db.SePayTransactions.Add(transaction);
        if (request.TransferType != "in") transaction.Outcome = "NotIncoming";
        else if (!string.Equals(request.Gateway, config.BankName, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(request.AccountNumber, config.AccountNumber, StringComparison.Ordinal))
            transaction.Outcome = "WrongDestination";
        else if (PaymentReference(request) is { Package: false } invoiceReference)
        {
            var invoiceId = invoiceReference.Id;
            var invoice = await db.Hoadons.Include(x => x.Thanhtoans).FirstOrDefaultAsync(x => x.HoaDonId == invoiceId, ct);
            if (invoice is null) transaction.Outcome = "UnknownInvoice";
            else
            {
                transaction.InvoiceId = invoiceId;
                if (invoice.TrangThai == "DaThanhToan") transaction.Outcome = "AlreadyPaid";
                else if (invoice.TrangThai != "ChuaThanhToan") transaction.Outcome = "InvoiceNotPayable";
                else if (PredatesInvoice(paidAt, invoice.NgayLap)) transaction.Outcome = "TransactionBeforeInvoice";
                else if (invoice.TongTienSauGiam <= 0 || request.TransferAmount != invoice.TongTienSauGiam
                    || decimal.Truncate(request.TransferAmount) != request.TransferAmount)
                    transaction.Outcome = "AmountMismatch";
                else
                {
                    await InvoiceSettlement.StageAsync(db, notifications, invoice, "ChuyenKhoan", paidAt, ct);
                    transaction.Outcome = "Paid";
                }
            }
        }
        else if (PaymentReference(request) is { Package: true } packageReference)
        {
            var purchase = await db.CustomerPackages.SingleOrDefaultAsync(x => x.Id == packageReference.Id, ct);
            // Existing Content carries the purchase reference; package transactions never use
            // InvoiceId or Outcome=Paid (that filtered unique index belongs to invoices).
            var canonicalReference = BankTransferOptions.PackageReference(packageReference.Id);
            if (ContentReferences(transaction.Content).Count == 0)
            {
                // Preserve the resolved purchase ID even if SePay provides it only in Code.
                var recorded = canonicalReference + (string.IsNullOrWhiteSpace(transaction.Content) ? "" : " " + transaction.Content);
                transaction.Content = recorded[..Math.Min(2000, recorded.Length)];
            }
            if (purchase is null) transaction.Outcome = "UnknownPackage";
            else if (purchase.Status == "Paid") transaction.Outcome = "PackageAlreadyPaid";
            else if (purchase.Status != "Pending") transaction.Outcome = "PackageNotPayable";
            else if (PredatesInvoice(paidAt, purchase.CreatedAt)) transaction.Outcome = "TransactionBeforePackage";
            else if (purchase.Price <= 0 || request.TransferAmount != purchase.Price || decimal.Truncate(request.TransferAmount) != request.TransferAmount)
                transaction.Outcome = "AmountMismatch";
            else
            {
                // Package dates follow the server's local clock, as existing manual payment does.
                var localPaidAt = new DateTimeOffset(DateTime.SpecifyKind(paidAt, DateTimeKind.Unspecified), TimeSpan.FromHours(7)).LocalDateTime;
                var error = await PackageSettlement.StageAsync(db, notifications, purchase, "ChuyenKhoan", localPaidAt, null, ct);
                if (error is not null) { db.ChangeTracker.Clear(); return Conflict(new { success = false }); }
                transaction.Outcome = "PackagePaid";
            }
        }
        try
        {
            // SQL Server saves ledger, invoice, rewards and staged notification atomically.
            if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict(new { success = false });
        }
        catch (DbUpdateException exception) when (exception.InnerException is SqlException { Number: 2601 or 2627 })
        {
            db.ChangeTracker.Clear();
            if (await db.SePayTransactions.AsNoTracking().AnyAsync(x => x.Id == request.Id, ct))
                return Ok(new { success = true });
            // Another transaction settled this invoice. Retry records AlreadyPaid without rewards.
            return Conflict(new { success = false });
        }
        return Ok(new { success = true });
    }

    private static bool PredatesInvoice(DateTime transactionDate, DateTime createdAt)
    {
        // Legacy invoice timestamps use API-server DateTime.Now (SQL returns Unspecified).
        // SePay supplies Vietnam wall time, to seconds. SQL datetime2(0) rounds
        // invoice creation to seconds, so allow one second for that rounding only.
        var transactionUtc = new DateTimeOffset(DateTime.SpecifyKind(transactionDate, DateTimeKind.Unspecified),
            TimeSpan.FromHours(7)).UtcDateTime;
        var invoiceUtc = createdAt.ToUniversalTime();
        invoiceUtc = invoiceUtc.AddTicks(-(invoiceUtc.Ticks % TimeSpan.TicksPerSecond));
        return transactionUtc < invoiceUtc.AddSeconds(-1);
    }

    private static bool ValidPayload(SePayWebhookRequest request, out DateTime paidAt) =>
        DateTime.TryParseExact(request.TransactionDate, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out paidAt)
        && request.Id > 0 && !string.IsNullOrWhiteSpace(request.Gateway) && request.Gateway.Length <= 100
        && !string.IsNullOrWhiteSpace(request.AccountNumber) && request.AccountNumber.Length <= 19
        && request.TransferType is "in" or "out"
        && request.TransferAmount > 0 && request.TransferAmount <= 9999999999999999.99m
        && (request.Content?.Length ?? 0) <= 2000 && (request.Code?.Length ?? 0) <= 100
        && (request.ReferenceCode?.Length ?? 0) <= 100;

    private static (bool Package, int Id)? PaymentReference(SePayWebhookRequest request)
    {
        const string codePattern = @"^(HB|HP)([1-9][0-9]{0,9})$";
        if (!string.IsNullOrWhiteSpace(request.Code))
        {
            var code = Regex.Match(request.Code, codePattern, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
            if (!code.Success || !int.TryParse(code.Groups[2].Value, out var id)) return null;
            // Mixed invoice/package or multiple references are never settled.
            var refs = ContentReferences(request.Content);
            return refs.Count == 0 || refs.Count == 1 && string.Equals(refs[0].Value, code.Value, StringComparison.OrdinalIgnoreCase)
                ? (code.Groups[1].Value.Equals("HP", StringComparison.OrdinalIgnoreCase), id) : null;
        }
        var matches = ContentReferences(request.Content);
        return matches.Count == 1 && int.TryParse(matches[0].Groups[2].Value, out var parsed)
            ? (matches[0].Groups[1].Value.Equals("HP", StringComparison.OrdinalIgnoreCase), parsed) : null;
    }

    private static MatchCollection ContentReferences(string? content) => Regex.Matches(content ?? "",
        @"(?<![A-Za-z0-9])(HB|HP)([1-9][0-9]{0,9})(?![A-Za-z0-9])", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
}
