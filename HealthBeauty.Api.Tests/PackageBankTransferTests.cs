using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class PackageBankTransferTests
{
    private const string Key = "package-test-only-webhook-secret-32chars";
    private sealed class ConflictContext(DbContextOptions<Klcn021HealthBeautyContext> options) : Klcn021HealthBeautyContext(options)
    {
        public bool FailSave { get; set; }
        public override Task<int> SaveChangesAsync(CancellationToken ct = default) => FailSave
            ? throw new DbUpdateConcurrencyException("Simulated package settlement conflict") : base.SaveChangesAsync(ct);
    }
    private static async Task<ConflictContext> Db()
    {
        var db = new ConflictContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "One", DiemThuong = 20 },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Two" });
        db.CustomerPackages.AddRange(new CustomerPackage { Id = 1, CustomerId = 1, Name = "Prepaid", Price = 100000m, ValidityDays = 30,
            CreatedAt = DateTime.Now.AddHours(-1), Items = [new() { ServiceId = 1, ServiceName = "Care", Granted = 5 }] },
            new CustomerPackage { Id = 2, CustomerId = 2, Name = "Other", Price = 100000m, ValidityDays = 30, CreatedAt = DateTime.Now.AddHours(-1) });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static T User<T>(T controller, int id = 1, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new() { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static BankTransfersController Controller(Klcn021HealthBeautyContext db, int id = 1, string role = "Customer", bool enabled = true)
    {
        var c = User(new BankTransfersController(db, Options.Create(new BankTransferOptions { Enabled = enabled,
            BankName = "MBBank", BankCode = "MBBank", AccountNumber = "00112233", AccountName = "TEST", WebhookApiKey = Key }), new NotificationService(db)), id, role);
        c.Request.Headers.Authorization = "Apikey " + Key; return c;
    }
    private static SePayWebhookRequest Transfer(long id = 100, string? code = null, string? content = "HP1") =>
        new(id, "MBBank", "00112233", "in", 100000m, code, content, "TEST" + id,
            DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss"));

    [Fact]
    public async Task QrIsOwnerScopedAndCannotActivatePendingPurchase()
    {
        await using var db = await Db();
        var qr = Assert.IsType<PackageBankTransferResponse>(Assert.IsType<OkObjectResult>(await Controller(db).PackageInstructions(1, default)).Value);
        Assert.Equal("HP1", qr.TransferContent); Assert.Equal(100000m, qr.Amount);
        Assert.Contains("des=HP1", qr.QrImageUrl); Assert.Contains("amount=100000", qr.QrImageUrl);
        Assert.IsType<NotFoundResult>(await Controller(db).PackageInstructions(2, default));
        Assert.IsType<OkObjectResult>(await Controller(db, 99, "Reception").PackageInstructions(2, default));
        var appointment = new Lichhen { KhachHangId = 1, NgayGioHen = DateTime.Now.AddDays(1), Chitietlichhens = [new() { DichVuId = 1 }] };
        Assert.NotNull(await ServicePackageLifecycle.ReserveAsync(db, appointment, 1, default));
        Assert.Equal("Pending", (await db.CustomerPackages.FindAsync(1))!.Status);
        Assert.Empty(db.SePayTransactions); Assert.Empty(db.Giaodichdiems);
    }

    [Fact]
    public async Task MatchingWebhookActivatesOnceAndOnlyThenAllowsPackageBooking()
    {
        await using var db = await Db(); var bank = Controller(db);
        Assert.IsType<OkObjectResult>(await bank.Webhook(Transfer(), default));
        var purchase = await db.CustomerPackages.Include(x => x.Items).SingleAsync(x => x.Id == 1);
        Assert.Equal("Paid", purchase.Status); Assert.Equal("ChuyenKhoan", purchase.PaymentMethod);
        Assert.Equal(1, purchase.PaidByAccountId); Assert.Equal(purchase.PaidAt!.Value.AddDays(30), purchase.ExpiresAt);
        Assert.Equal(30, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Null((await db.SePayTransactions.SingleAsync()).InvoiceId);
        Assert.Equal("PackagePaid", (await db.SePayTransactions.SingleAsync()).Outcome);
        Assert.Single(db.Giaodichdiems); Assert.Single(db.ThongBaos); Assert.Empty(db.Hoadons); Assert.Empty(db.Thanhtoans);
        Assert.IsType<OkObjectResult>(await bank.Webhook(Transfer(), default));
        Assert.IsType<OkObjectResult>(await bank.Webhook(Transfer(101), default));
        Assert.Equal(30, (await db.Khachhangs.FindAsync(1))!.DiemThuong); Assert.Single(db.Giaodichdiems); Assert.Single(db.ThongBaos);
        Assert.Equal("PackageAlreadyPaid", (await db.SePayTransactions.FindAsync(101L))!.Outcome);
        var appointment = new Lichhen { KhachHangId = 1, NgayGioHen = DateTime.Now.AddDays(1), Chitietlichhens = [new() { DichVuId = 1 }] };
        Assert.Null(await ServicePackageLifecycle.ReserveAsync(db, appointment, 1, default));
    }

    [Theory]
    [InlineData("HP1 HB1", null)]
    [InlineData("HP1 HP2", null)]
    [InlineData("HP1 HP1", null)]
    [InlineData("HP1", "HB1")]
    [InlineData("HB1", "HP1")]
    [InlineData("HP2", "HP1")]
    public async Task AmbiguousInvoiceOrPackageReferencesDoNotActivate(string content, string? code)
    {
        await using var db = await Db();
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(code: code, content: content), default));
        Assert.Equal("Pending", (await db.CustomerPackages.FindAsync(1))!.Status); Assert.Empty(db.Giaodichdiems);
        Assert.Equal("UnmatchedReference", (await db.SePayTransactions.SingleAsync()).Outcome);
    }

    [Theory]
    [InlineData("amount", "AmountMismatch")]
    [InlineData("gateway", "WrongDestination")]
    [InlineData("account", "WrongDestination")]
    [InlineData("out", "NotIncoming")]
    [InlineData("old", "TransactionBeforePackage")]
    [InlineData("unknown", "UnknownPackage")]
    [InlineData("cancelled", "PackageNotPayable")]
    public async Task NonmatchingTransfersKeepPackageInactive(string change, string outcome)
    {
        await using var db = await Db(); var transfer = Transfer();
        transfer = change switch { "amount" => transfer with { TransferAmount = 99999 }, "gateway" => transfer with { Gateway = "Other" },
            "account" => transfer with { AccountNumber = "other" }, "out" => transfer with { TransferType = "out" },
            "old" => transfer with { TransactionDate = "2020-01-01 00:00:00" }, "unknown" => transfer with { Content = "HP999" }, _ => transfer };
        if (change == "cancelled") { (await db.CustomerPackages.FindAsync(1))!.Status = "Cancelled"; await db.SaveChangesAsync(); }
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(transfer, default));
        Assert.NotEqual("Paid", (await db.CustomerPackages.FindAsync(1))!.Status); Assert.Empty(db.Giaodichdiems); Assert.Empty(db.ThongBaos);
        Assert.Equal(outcome, (await db.SePayTransactions.SingleAsync()).Outcome);
    }

    [Fact]
    public async Task ConflictRollsBackStagedPackageLedgerRewardsAndNotification()
    {
        await using var db = await Db(); db.FailSave = true;
        Assert.IsType<ConflictObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Equal("Pending", (await db.CustomerPackages.FindAsync(1))!.Status);
        Assert.Equal(20, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        Assert.Empty(db.SePayTransactions); Assert.Empty(db.Giaodichdiems); Assert.Empty(db.ThongBaos);
    }

    [Fact]
    public async Task CodeOnlyPackageReferenceIsKeptInExistingLedgerContent()
    {
        await using var db = await Db();
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(code: "HP1", content: "Bank transfer"), default));
        Assert.Equal("HP1 Bank transfer", (await db.SePayTransactions.SingleAsync()).Content);
        Assert.Equal("Paid", (await db.CustomerPackages.FindAsync(1))!.Status);
    }

    [Fact]
    public async Task RewardOverflowLeavesPackageAndTransferUnapplied()
    {
        await using var db = await Db();
        (await db.Khachhangs.FindAsync(1))!.DiemThuong = int.MaxValue; await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Equal("Pending", (await db.CustomerPackages.FindAsync(1))!.Status);
        Assert.Empty(db.SePayTransactions); Assert.Empty(db.Giaodichdiems); Assert.Empty(db.ThongBaos);
    }

    [Fact]
    public async Task AutomaticPaymentFulfillsExistingSqlPaidConstraintAndAccountForeignKey()
    {
        var sql = await File.ReadAllTextAsync(Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../DB_KLCN021/13_ServicePackages.sql")));
        Assert.Contains("CONSTRAINT CK_CustomerPackage_Paid", sql);
        Assert.Contains("PaidByAccountId IS NOT NULL", sql);
        Assert.Contains("PaidByAccountId int NULL REFERENCES dbo.TAIKHOAN(TaiKhoanID)", sql);
        await using var db = await Db();
        var entity = db.Model.FindEntityType(typeof(CustomerPackage))!;
        Assert.Contains(entity.GetForeignKeys(), fk => fk.Properties.Single().Name == nameof(CustomerPackage.PaidByAccountId)
            && fk.PrincipalEntityType.ClrType == typeof(Taikhoan));
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(), default));
        var purchase = (await db.CustomerPackages.FindAsync(1))!;
        Assert.Equal("Paid", purchase.Status);
        Assert.NotNull(purchase.PaidAt); Assert.NotNull(purchase.ExpiresAt);
        Assert.True(purchase.ExpiresAt > purchase.PaidAt);
        Assert.NotNull(purchase.PaymentMethod);
        Assert.Equal((await db.Khachhangs.FindAsync(1))!.TaiKhoanId, purchase.PaidByAccountId);
        Assert.NotNull(purchase.PaidByAccountId);
    }

    [Fact]
    public async Task WalkInWithoutAccountCannotReceiveAutomaticQrOrActivateViaWebhook()
    {
        await using var db = await Db();
        (await db.Khachhangs.FindAsync(1))!.TaiKhoanId = null; await db.SaveChangesAsync();
        Assert.IsType<ConflictObjectResult>(await Controller(db, 99, "Reception").PackageInstructions(1, default));
        Assert.IsType<ConflictObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Equal("Pending", (await db.CustomerPackages.FindAsync(1))!.Status);
        Assert.Null((await db.CustomerPackages.FindAsync(1))!.PaidByAccountId);
        Assert.Empty(db.SePayTransactions); Assert.Empty(db.Giaodichdiems); Assert.Empty(db.ThongBaos);
        Assert.IsType<OkObjectResult>(await User(new ServicePackagesController(db), 99, "Reception").Pay(1, new("TienMat"), default));
        Assert.Equal(99, (await db.CustomerPackages.FindAsync(1))!.PaidByAccountId);
    }

    [Fact]
    public async Task ManualPaymentAndPackageQrShareOneSettlementAndDoNotDoubleAward()
    {
        await using var db = await Db();
        Assert.IsType<OkObjectResult>(await User(new ServicePackagesController(db), 99, "Reception").Pay(1, new("TienMat"), default));
        Assert.IsType<ConflictObjectResult>(await Controller(db).PackageInstructions(1, default));
        Assert.IsType<OkObjectResult>(await Controller(db).Webhook(Transfer(), default));
        Assert.Equal(30, (await db.Khachhangs.FindAsync(1))!.DiemThuong); Assert.Single(db.Giaodichdiems); Assert.Single(db.ThongBaos);
        Assert.Equal(99, (await db.CustomerPackages.FindAsync(1))!.PaidByAccountId);
    }
}
