using System.Reflection;
using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class BankTransferTests
{
    private const string ApiKey = "test-only-webhook-secret-32-characters";

    private static BankTransferOptions Config(bool enabled = true) => new()
    {
        Enabled = enabled, BankName = "Vietcombank", BankCode = "VCB",
        AccountNumber = "001122334455", AccountName = "TEST SPA", WebhookApiKey = ApiKey
    };

    private sealed class ConflictContext(DbContextOptions<Klcn021HealthBeautyContext> options)
        : Klcn021HealthBeautyContext(options)
    {
        public bool FailSave { get; set; }
        public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
            => FailSave ? throw new DbUpdateConcurrencyException("Simulated concurrent settlement") : base.SaveChangesAsync(cancellationToken);
    }

    private static async Task<ConflictContext> Database()
    {
        var db = new ConflictContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "One", DiemThuong = 20 },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Two", DiemThuong = 30 });
        db.Hoadons.AddRange(new Hoadon
        {
            HoaDonId = 1, LichHenId = 1, KhachHangId = 1, NgayLap = new DateTimeOffset(2026, 10, 25, 8, 0, 0, TimeSpan.FromHours(7)).LocalDateTime,
            TongTienTruocGiam = 120000m, TongTienSauGiam = 100000m, TrangThai = "ChuaThanhToan"
        }, new Hoadon
        {
            HoaDonId = 2, LichHenId = 2, KhachHangId = 2, NgayLap = new DateTimeOffset(2026, 10, 25, 8, 0, 0, TimeSpan.FromHours(7)).LocalDateTime,
            TongTienSauGiam = 100000m, TrangThai = "ChuaThanhToan"
        });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        return db;
    }

    private static ClaimsPrincipal User(int accountId = 1, string role = "Customer") => new(new ClaimsIdentity(
        [new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, role)], "Test"));

    private static BankTransfersController Controller(Klcn021HealthBeautyContext db, BankTransferOptions? config = null,
        string? authorization = "Apikey " + ApiKey, int accountId = 1, string role = "Customer")
    {
        var http = new DefaultHttpContext { User = User(accountId, role) };
        if (authorization is not null) http.Request.Headers.Authorization = authorization;
        return new(db, Options.Create(config ?? Config()), new NotificationService(db))
        {
            ControllerContext = new() { HttpContext = http }
        };
    }

    private static SePayWebhookRequest Transfer(long id = 11, string? code = "HB1", string? content = "HB1") =>
        new(id, "Vietcombank", "001122334455", "in", 100000m, code, content, "TEST-REF-" + id, "2026-10-25 09:00:00");

    [Fact]
    public async Task InstructionsUseServerAmountAndReferenceAndProtectOwnership()
    {
        await using var db = await Database();
        var response = Assert.IsType<BankTransferResponse>(Assert.IsType<OkObjectResult>(await Controller(db).Instructions(1, default)).Value);
        Assert.Equal(100000m, response.Amount);
        Assert.Equal("HB1", response.TransferContent);
        Assert.Equal("ChuaThanhToan", response.Status);
        var uri = new Uri(response.QrImageUrl);
        Assert.Equal("https", uri.Scheme);
        Assert.Equal("vietqr.app", uri.Host);
        Assert.Contains("amount=100000", uri.Query);
        Assert.Contains("des=HB1", uri.Query);
        Assert.IsType<NotFoundResult>(await Controller(db).Instructions(2, default));
        Assert.IsType<OkObjectResult>(await Controller(db, accountId: 99, role: "Reception").Instructions(2, default));
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
    }

    [Fact]
    public async Task DisabledOrIncompleteConfigDoesNotExposeBankInstructions()
    {
        await using var db = await Database();
        foreach (var config in new[] { Config(false), new BankTransferOptions { Enabled = true }, Config() })
        {
            if (config.AccountName == "TEST SPA" && config.Enabled) config.WebhookApiKey = "";
            var result = Assert.IsType<ObjectResult>(await Controller(db, config).Instructions(1, default));
            Assert.Equal(503, result.StatusCode);
            Assert.Equal(503, Assert.IsType<ObjectResult>(await Controller(db, config).Webhook(Transfer(), default)).StatusCode);
        }
        Assert.Empty(await db.SePayTransactions.ToListAsync());
    }

    [Theory]
    [InlineData("DaThanhToan", 100000)]
    [InlineData("ChuaThanhToan", 0)]
    [InlineData("ChuaThanhToan", -1)]
    [InlineData("ChuaThanhToan", 100000.5)]
    [InlineData("DaHuy", 100000)]
    public async Task InstructionsRejectPaidZeroAndNonPayableInvoices(string status, double amount)
    {
        await using var db = await Database();
        var invoice = await db.Hoadons.FindAsync(1);
        invoice!.TrangThai = status;
        invoice.TongTienSauGiam = (decimal)amount;
        await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Controller(db).Instructions(1, default));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("Bearer " + ApiKey)]
    [InlineData("Apikey invalid")]
    [InlineData("Apikey " + ApiKey + "extra")]
    public async Task InvalidWebhookAuthenticationCannotChangeAnyData(string? authorization)
    {
        await using var db = await Database();
        Assert.IsType<UnauthorizedObjectResult>(await Controller(db, authorization: authorization).Webhook(Transfer(), default));
        Assert.Empty(await db.SePayTransactions.ToListAsync());
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
    }

    [Fact]
    public async Task VerifiedTransferSettlesExactlyOnceIncludingRewardsAndNotification()
    {
        await using var db = await Database();
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(), default));
        db.ChangeTracker.Clear();
        Assert.Equal("DaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
        var payment = Assert.Single(await db.Thanhtoans.ToListAsync());
        Assert.Equal("ChuyenKhoan", payment.PhuongThuc);
        Assert.Equal(100000m, payment.SoTien);
        Assert.Equal(new DateTime(2026, 10, 25, 9, 0, 0), payment.NgayGioThanhToan);
        Assert.Equal(30, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.Single(await db.ThongBaos.ToListAsync());
        Assert.Equal("Paid", (await db.SePayTransactions.SingleAsync()).Outcome);
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(12), default));
        Assert.Single(await db.Thanhtoans.ToListAsync());
        Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.Single(await db.ThongBaos.ToListAsync());
        Assert.Equal(30, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Equal("AlreadyPaid", (await db.SePayTransactions.FindAsync(12L))!.Outcome);
    }

    [Theory]
    [InlineData("bank", "WrongDestination")]
    [InlineData("account", "WrongDestination")]
    [InlineData("direction", "NotIncoming")]
    [InlineData("underpaid", "AmountMismatch")]
    [InlineData("overpaid", "AmountMismatch")]
    [InlineData("fraction", "AmountMismatch")]
    [InlineData("unknown", "UnknownInvoice")]
    [InlineData("substring", "UnmatchedReference")]
    [InlineData("ambiguous", "UnmatchedReference")]
    [InlineData("conflicting", "UnmatchedReference")]
    public async Task MismatchesAreRecordedForReconciliationWithoutMarkingPaid(string scenario, string outcome)
    {
        await using var db = await Database();
        var transfer = scenario switch
        {
            "bank" => Transfer() with { Gateway = "ACB" },
            "account" => Transfer() with { AccountNumber = "99887766" },
            "direction" => Transfer() with { TransferType = "out" },
            "underpaid" => Transfer() with { TransferAmount = 99999m },
            "overpaid" => Transfer() with { TransferAmount = 100001m },
            "fraction" => Transfer() with { TransferAmount = 100000.1m },
            "unknown" => Transfer(code: "HB999", content: "HB999"),
            "substring" => Transfer(code: null, content: "XHB1Z"),
            "ambiguous" => Transfer(code: null, content: "HB1 HB2"),
            _ => Transfer(code: "HB1", content: "HB2")
        };
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(transfer, default));
        Assert.Equal(outcome, (await db.SePayTransactions.SingleAsync()).Outcome);
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.Empty(await db.Giaodichdiems.ToListAsync());
        Assert.Empty(await db.ThongBaos.ToListAsync());
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
    }

    [Fact]
    public async Task OldTransferCannotPayInvoiceCreatedLaterEvenWhenAmountAndCodeMatch()
    {
        await using var db = await Database();
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer() with { TransactionDate = "2026-10-25 07:59:58" }, default));
        Assert.Equal("TransactionBeforeInvoice", (await db.SePayTransactions.SingleAsync()).Outcome);
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task SameSecondTransferUsesExplicitVietnamOffsetAndProviderSecondsPrecision(bool sqlRoundedUp)
    {
        await using var db = await Database();
        var invoice = (await db.Hoadons.FindAsync(1))!;
        invoice.NgayLap = new DateTimeOffset(2026, 10, 25, 9, 0, 0, TimeSpan.FromHours(7)).UtcDateTime
            .AddMilliseconds(sqlRoundedUp ? 1000 : 900);
        await db.SaveChangesAsync();
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Equal("Paid", (await db.SePayTransactions.SingleAsync()).Outcome);
    }

    [Fact]
    public async Task MissingProviderCodeCanMatchSingleStandaloneReferenceInBankContent()
    {
        await using var db = await Database();
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(code: null, content: "CHUYEN TIEN hb1. CAM ON"), default));
        Assert.Equal("Paid", (await db.SePayTransactions.SingleAsync()).Outcome);
    }

    [Fact]
    public async Task ConcurrencyConflictDoesNotAcknowledgeOrPersistPartialSettlementAndCanRetry()
    {
        await using var db = await Database();
        db.FailSave = true;
        Assert.IsType<ConflictObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Empty(await db.SePayTransactions.ToListAsync());
        Assert.Empty(await db.Thanhtoans.ToListAsync());
        Assert.Empty(await db.Giaodichdiems.ToListAsync());
        Assert.Empty(await db.ThongBaos.ToListAsync());
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
        Assert.Equal(20, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        db.FailSave = false;
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Single(await db.Thanhtoans.ToListAsync());
    }

    [Fact]
    public async Task CustomerHistoryAndDetailsCannotReadAnotherCustomersInvoice()
    {
        await using var db = await Database();
        var controller = new InvoicesController(db) { ControllerContext = new() { HttpContext = new DefaultHttpContext { User = User() } } };
        var result = Assert.IsType<OkObjectResult>(await controller.List(default));
        Assert.Equal(1, Assert.Single(Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(result.Value)).Id);
        Assert.IsType<OkObjectResult>(await controller.Detail(1, default));
        Assert.IsType<NotFoundResult>(await controller.Detail(2, default));
        Assert.IsType<BadRequestObjectResult>(await controller.List(default, -1, 50));
        Assert.IsType<BadRequestObjectResult>(await controller.List(default, 0, 101));
    }

    [Fact]
    public async Task HistoryPaginationKeepsArrayAndStableOrderForSameTimestamp()
    {
        await using var db = await Database();
        for (var i = 3; i <= 106; i++) db.Hoadons.Add(new Hoadon
        {
            HoaDonId = i, LichHenId = i, KhachHangId = 1, NgayLap = new(2026, 10, 25, 8, 0, 0),
            TongTienSauGiam = 100000m, TrangThai = "ChuaThanhToan"
        });
        await db.SaveChangesAsync();
        var controller = new InvoicesController(db) { ControllerContext = new() { HttpContext = new DefaultHttpContext { User = User() } } };
        var first = Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(Assert.IsType<OkObjectResult>(await controller.List(default, 0, 50)).Value).ToList();
        var second = Assert.IsAssignableFrom<IEnumerable<InvoiceResponse>>(Assert.IsType<OkObjectResult>(await controller.List(default, 50, 50)).Value).ToList();
        Assert.Equal(50, first.Count);
        Assert.Equal(106, first[0].Id);
        Assert.Equal(57, first[^1].Id);
        Assert.Equal(56, second[0].Id);
        Assert.Empty(first.Select(x => x.Id).Intersect(second.Select(x => x.Id)));
    }

    [Fact]
    public async Task LedgerAndInvoiceHaveDatabaseConcurrencyAndUniquenessGuards()
    {
        await using var db = await Database();
        var ledger = db.Model.FindEntityType(typeof(SePayTransaction))!;
        Assert.Equal(nameof(SePayTransaction.Id), Assert.Single(ledger.FindPrimaryKey()!.Properties).Name);
        Assert.Contains(ledger.GetIndexes(), x => x.IsUnique && x.GetFilter() == "[Outcome] = 'Paid'");
        Assert.True(db.Model.FindEntityType(typeof(Hoadon))!.FindProperty(nameof(Hoadon.RowVersion))!.IsConcurrencyToken);
        Assert.True(db.Model.FindEntityType(typeof(Khachhang))!.FindProperty(nameof(Khachhang.RowVersion))!.IsConcurrencyToken);
        Assert.NotNull(typeof(BankTransfersController).GetMethod(nameof(BankTransfersController.Instructions))!.GetCustomAttribute<AuthorizeAttribute>());
        Assert.NotNull(typeof(BankTransfersController).GetMethod(nameof(BankTransfersController.Webhook))!.GetCustomAttribute<AllowAnonymousAttribute>());
        Assert.Equal("INVOICE.READ", DatabasePermissionFilter.RequiredPermission("Invoices", "Detail", User(99, "Reception")));
        Assert.Equal("INVOICE.READ", DatabasePermissionFilter.RequiredPermission("BankTransfers", "Instructions", User(99, "Reception")));
    }
}
