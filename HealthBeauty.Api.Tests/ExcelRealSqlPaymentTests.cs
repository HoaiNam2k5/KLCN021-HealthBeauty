using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class RealSqlPaymentFactAttribute : FactAttribute
{
    public RealSqlPaymentFactAttribute() { if (Environment.GetEnvironmentVariable("HEALTHBEAUTY_TEST_SQL_COPY") != "1") Skip = "Real SQL copy tests require explicit opt-in."; }
}
public sealed class RealSqlPaymentTheoryAttribute : TheoryAttribute
{
    public RealSqlPaymentTheoryAttribute() { if (Environment.GetEnvironmentVariable("HEALTHBEAUTY_TEST_SQL_COPY") != "1") Skip = "Real SQL copy tests require explicit opt-in."; }
}

/// <summary>Tests the explicitly approved local database copy only. No external payment call.</summary>
public class ExcelRealSqlPaymentTests
{
    private static Klcn021HealthBeautyContext OpenCopy()
    {
        if (Environment.GetEnvironmentVariable("HEALTHBEAUTY_TEST_SQL_COPY") != "1") throw new InvalidOperationException("Real SQL copy tests require explicit opt-in.");
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "KLCN021_HealthBeauty.sln"))) dir = dir.Parent;
        if (dir == null) throw new InvalidOperationException("Project root missing");
        using var json = JsonDocument.Parse(File.ReadAllText(Path.Combine(dir.FullName, "HealthBeauty.Api", "appsettings.Development.local.json")));
        var raw = json.RootElement.GetProperty("ConnectionStrings").GetProperty("DefaultConnection").GetString();
        var connection = new SqlConnectionStringBuilder(raw);
        var server = connection.DataSource.ToLowerInvariant();
        if (server is not ("localhost\\sqlexpress" or ".\\sqlexpress")) throw new InvalidOperationException("Only local SQL Express is permitted");
        connection.InitialCatalog = "KLCN021_HealthBeauty_Test";
        connection.TrustServerCertificate = true;
        connection.Encrypt = false;
        return new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseSqlServer(connection.ConnectionString).Options);
    }
    private static T As<T>(T controller, int accountId, string role) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, role)], "Test")) } };
        return controller;
    }
    private static BankTransfersController Payment(Klcn021HealthBeautyContext db, int accountId, string role) => As(new BankTransfersController(db,
        Options.Create(new BankTransferOptions { Enabled = true, BankName = "Test Bank", BankCode = "MBBank", AccountNumber = "00112233", AccountName = "TEST", WebhookApiKey = "local-test-secret-not-a-production-key-123" }), new NotificationService(db)), accountId, role);

    [RealSqlPaymentFact]
    public async Task PKG01_RealSqlCatalogReturnsExistingActivePackages()
    {
        await using var db = OpenCopy();
        var catalog = await db.ServicePackages.AsNoTracking().Include(x => x.Items).Where(x => x.Active).ToListAsync();
        Assert.NotEmpty(catalog);
        var controller = new ServicePackagesController(db);
        var result = Assert.IsType<OkObjectResult>(await controller.List(default));
        var actual = Assert.IsAssignableFrom<IReadOnlyCollection<ServicePackage>>(result.Value);
        Assert.Equal(catalog.Select(x => x.Id).Order(), actual.Select(x => x.Id).Order());
        Assert.All(actual, p => Assert.True(p.Active));
    }

    [RealSqlPaymentFact]
    public async Task PKG02_RealSqlPurchaseIsPendingAndQrMatchesSnapshot_RolledBack()
    {
        await using var db = OpenCopy();
        await using var tx = await db.Database.BeginTransactionAsync();
        var customer = await db.Khachhangs.AsNoTracking().FirstAsync(x => x.TaiKhoanId.HasValue);
        var catalog = await db.ServicePackages.Include(x => x.Items).FirstAsync(x => x.Active && x.Items.Any());
        Assert.All(catalog.Items, i => Assert.True(db.Dichvus.Any(s => s.DichVuId == i.ServiceId && s.TrangThai)));
        var controller = As(new ServicePackagesController(db), customer.TaiKhoanId!.Value, "Customer");
        var created = Assert.IsType<CreatedResult>(await controller.Purchase(new PackagePurchaseRequest(catalog.Id), default));
        Assert.NotNull(created.Value);
        db.ChangeTracker.Clear();
        var purchase = await db.CustomerPackages.Include(x => x.Items).OrderByDescending(x => x.Id).FirstAsync(x => x.CustomerId == customer.KhachHangId && x.ServicePackageId == catalog.Id);
        Assert.Equal("Pending", purchase.Status);
        Assert.Equal(catalog.Price, purchase.Price);
        Assert.Equal(catalog.Items.Count, purchase.Items.Count);
        var qr = Assert.IsType<PackageBankTransferResponse>(Assert.IsType<OkObjectResult>(await Payment(db, customer.TaiKhoanId.Value, "Customer").PackageInstructions(purchase.Id, default)).Value);
        Assert.Equal(purchase.Price, qr.Amount);
        Assert.Equal(BankTransferOptions.PackageReference(purchase.Id), qr.TransferContent);
        await tx.RollbackAsync();
    }

    [RealSqlPaymentFact]
    public async Task PAY02_RealSqlInvoiceQrUsesDatabaseAmountAndReference()
    {
        await using var db = OpenCopy();
        var invoice = await db.Hoadons.AsNoTracking().FirstAsync(x => x.TrangThai == "ChuaThanhToan" && x.TongTienSauGiam > 0);
        Assert.Equal(decimal.Truncate(invoice.TongTienSauGiam), invoice.TongTienSauGiam);
        var qr = Assert.IsType<BankTransferResponse>(Assert.IsType<OkObjectResult>(await Payment(db, 999, "Reception").Instructions(invoice.HoaDonId, default)).Value);
        Assert.Equal(invoice.TongTienSauGiam, qr.Amount);
        Assert.Equal(BankTransferOptions.Reference(invoice.HoaDonId), qr.TransferContent);
    }

    [RealSqlPaymentFact]
    public async Task PAY01_RealSqlOwnerCanReadExistingPendingInvoice()
    {
        await using var db = OpenCopy();
        var pair = await (from invoice in db.Hoadons.AsNoTracking()
                          join customer in db.Khachhangs.AsNoTracking() on invoice.KhachHangId equals customer.KhachHangId
                          where invoice.TrangThai == "ChuaThanhToan" && customer.TaiKhoanId.HasValue
                          select new { invoice.HoaDonId, invoice.TongTienSauGiam, AccountId = customer.TaiKhoanId!.Value }).FirstAsync();
        var owner = As(new InvoicesController(db), pair.AccountId, "Customer");
        var result = Assert.IsType<InvoiceResponse>(Assert.IsType<OkObjectResult>(await owner.Detail(pair.HoaDonId, default)).Value);
        Assert.Equal(pair.HoaDonId, result.Id);
        Assert.Equal(pair.TongTienSauGiam, result.Total);
        Assert.Equal("ChuaThanhToan", result.Status);
    }

    [RealSqlPaymentFact]
    public async Task PAY03_RealSqlWebhookWithoutKeyIsRejected()
    {
        await using var db = OpenCopy();
        var before = await db.SePayTransactions.CountAsync();
        var controller = Payment(db, 999, "Reception");
        var request = new SePayWebhookRequest(899999999999L, "MBBank", "00112233", "in", 1, null, "HB1", "TEST", "2026-11-04 10:00:00");
        Assert.IsType<UnauthorizedObjectResult>(await controller.Webhook(request, default));
        Assert.Equal(before, await db.SePayTransactions.CountAsync());
    }

    [RealSqlPaymentTheory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PAY04_PAY05_PAY06_RealSqlPackageTransferIsAtomicAndIdempotent(bool wrongAmount)
    {
        await using var db = OpenCopy();
        await using var tx = await db.Database.BeginTransactionAsync();
        var customer = await db.Khachhangs.AsNoTracking().FirstAsync(x => x.TaiKhoanId.HasValue);
        var catalog = await db.ServicePackages.Include(x => x.Items).FirstAsync(x => x.Active && x.Items.Any());
        Assert.True(catalog.Price > 1);
        var packages = As(new ServicePackagesController(db), customer.TaiKhoanId!.Value, "Customer");
        Assert.IsType<CreatedResult>(await packages.Purchase(new PackagePurchaseRequest(catalog.Id), default));
        db.ChangeTracker.Clear();
        var purchase = await db.CustomerPackages.OrderByDescending(x => x.Id).FirstAsync(x => x.CustomerId == customer.KhachHangId && x.ServicePackageId == catalog.Id);
        var id = Random.Shared.NextInt64(1000000000000L, 9000000000000L);
        var request = new SePayWebhookRequest(id, "Test Bank", "00112233", "in", wrongAmount ? purchase.Price - 1 : purchase.Price,
            null, BankTransferOptions.PackageReference(purchase.Id), "LOCAL-TEST", DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss"));
        var controller = Payment(db, customer.TaiKhoanId.Value, "Customer");
        controller.Request.Headers.Authorization = "Apikey local-test-secret-not-a-production-key-123";
        Assert.IsType<OkObjectResult>(await controller.Webhook(request, default));
        db.ChangeTracker.Clear();
        var after = await db.CustomerPackages.AsNoTracking().SingleAsync(x => x.Id == purchase.Id);
        Assert.Equal(wrongAmount ? "Pending" : "Paid", after.Status);
        if (!wrongAmount) { Assert.NotNull(after.PaidAt); Assert.NotNull(after.ExpiresAt); }
        Assert.Equal(wrongAmount ? "AmountMismatch" : "PackagePaid", (await db.SePayTransactions.AsNoTracking().SingleAsync(x => x.Id == id)).Outcome);
        Assert.IsType<OkObjectResult>(await controller.Webhook(request, default));
        Assert.Equal(1, await db.SePayTransactions.CountAsync(x => x.Id == id));
        await tx.RollbackAsync();
    }

    [RealSqlPaymentTheory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PAY04_PAY05_PAY06_RealSqlInvoiceWebhookDoesNotDuplicatePayment(bool wrongAmount)
    {
        await using var db = OpenCopy();
        await using var tx = await db.Database.BeginTransactionAsync();
        var now = DateTime.Now;
        var invoice = await db.Hoadons.AsNoTracking().FirstAsync(x => x.TrangThai == "ChuaThanhToan" && x.TongTienSauGiam > 1 && x.NgayLap <= now && db.Khachhangs.Any(c => c.KhachHangId == x.KhachHangId && c.TaiKhoanId.HasValue));
        Assert.Equal(decimal.Truncate(invoice.TongTienSauGiam), invoice.TongTienSauGiam);
        var before = await db.Thanhtoans.CountAsync(x => x.HoaDonId == invoice.HoaDonId);
        var id = Random.Shared.NextInt64(1000000000000L, 9000000000000L);
        var request = new SePayWebhookRequest(id, "Test Bank", "00112233", "in", wrongAmount ? invoice.TongTienSauGiam - 1 : invoice.TongTienSauGiam,
            null, BankTransferOptions.Reference(invoice.HoaDonId), "LOCAL-TEST", DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss"));
        var controller = Payment(db, 999, "Reception");
        controller.Request.Headers.Authorization = "Apikey local-test-secret-not-a-production-key-123";
        Assert.IsType<OkObjectResult>(await controller.Webhook(request, default));
        db.ChangeTracker.Clear();
        var after = await db.Hoadons.AsNoTracking().SingleAsync(x => x.HoaDonId == invoice.HoaDonId);
        Assert.Equal(wrongAmount ? "ChuaThanhToan" : "DaThanhToan", after.TrangThai);
        Assert.Equal(wrongAmount ? "AmountMismatch" : "Paid", (await db.SePayTransactions.AsNoTracking().SingleAsync(x => x.Id == id)).Outcome);
        if (!wrongAmount)
        {
            var ownerId = await db.Khachhangs.Where(x => x.KhachHangId == invoice.KhachHangId).Select(x => x.TaiKhoanId!.Value).SingleAsync();
            var owner = As(new InvoicesController(db), ownerId, "Customer");
            var staff = As(new InvoicesController(db), 999, "Reception");
            var ownerResult = Assert.IsType<InvoiceResponse>(Assert.IsType<OkObjectResult>(await owner.Detail(invoice.HoaDonId, default)).Value);
            var staffResult = Assert.IsType<InvoiceResponse>(Assert.IsType<OkObjectResult>(await staff.Detail(invoice.HoaDonId, default)).Value);
            Assert.Equal("DaThanhToan", ownerResult.Status);
            Assert.Equal(ownerResult.Status, staffResult.Status);
            Assert.Equal(ownerResult.Total, staffResult.Total);
        }
        Assert.IsType<OkObjectResult>(await controller.Webhook(request, default));
        Assert.Equal(before + (wrongAmount ? 0 : 1), await db.Thanhtoans.CountAsync(x => x.HoaDonId == invoice.HoaDonId));
        Assert.Equal(1, await db.SePayTransactions.CountAsync(x => x.Id == id));
        await tx.RollbackAsync();
    }

    [RealSqlPaymentFact]
    public async Task PKG06_RealSqlOwnerDetailsMatchGrantedUsedAndReserved()
    {
        await using var db = OpenCopy();
        var pair = await (from package in db.CustomerPackages.AsNoTracking()
                          join customer in db.Khachhangs.AsNoTracking() on package.CustomerId equals customer.KhachHangId
                          where package.Status == "Paid" && customer.TaiKhoanId.HasValue
                          select new { package.Id, AccountId = customer.TaiKhoanId!.Value }).FirstAsync();
        var persisted = await db.CustomerPackages.AsNoTracking().Include(x => x.Items).SingleAsync(x => x.Id == pair.Id);
        Assert.NotEmpty(persisted.Items);
        var result = Assert.IsType<OkObjectResult>(await As(new ServicePackagesController(db), pair.AccountId, "Customer").Detail(pair.Id, default));
        var payload = JsonSerializer.SerializeToElement(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        var items = payload.GetProperty("package").GetProperty("items");
        Assert.Equal(persisted.Items.Count, items.GetArrayLength());
        foreach (var item in persisted.Items)
        {
            var json = items.EnumerateArray().Single(x => x.GetProperty("serviceId").GetInt32() == item.ServiceId);
            Assert.Equal(item.Granted, json.GetProperty("granted").GetInt32());
            Assert.Equal(item.Used, json.GetProperty("used").GetInt32());
            Assert.Equal(item.Reserved, json.GetProperty("reserved").GetInt32());
            Assert.Equal(item.Granted - item.Used - item.Reserved, json.GetProperty("available").GetInt32());
        }
    }

    [RealSqlPaymentFact]
    public async Task PKG04_PKG05_RealSqlReservationConsumesOnlyAvailablePackageSession()
    {
        await using var db = OpenCopy();
        await using var tx = await db.Database.BeginTransactionAsync();
        var customer = await db.Khachhangs.AsNoTracking().FirstAsync(x => x.TaiKhoanId.HasValue);
        var catalog = await db.ServicePackages.Include(x => x.Items).FirstAsync(x => x.Active && x.Items.Any());
        var packages = As(new ServicePackagesController(db), customer.TaiKhoanId!.Value, "Customer");
        Assert.IsType<CreatedResult>(await packages.Purchase(new PackagePurchaseRequest(catalog.Id), default));
        db.ChangeTracker.Clear();
        var purchase = await db.CustomerPackages.Include(x => x.Items).OrderByDescending(x => x.Id).FirstAsync(x => x.CustomerId == customer.KhachHangId && x.ServicePackageId == catalog.Id);
        var payment = Payment(db, customer.TaiKhoanId.Value, "Customer");
        payment.Request.Headers.Authorization = "Apikey local-test-secret-not-a-production-key-123";
        var transfer = new SePayWebhookRequest(Random.Shared.NextInt64(1000000000000L, 9000000000000L), "Test Bank", "00112233", "in", purchase.Price,
            null, BankTransferOptions.PackageReference(purchase.Id), "LOCAL-PKG", DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss"));
        Assert.IsType<OkObjectResult>(await payment.Webhook(transfer, default));
        db.ChangeTracker.Clear();
        var paid = await db.CustomerPackages.Include(x => x.Items).SingleAsync(x => x.Id == purchase.Id);
        var item = paid.Items.First();
        Assert.True(item.Granted > 0);
        var appointment = new Lichhen { KhachHangId = customer.KhachHangId, NgayGioHen = DateTime.Now.AddMinutes(30), TrangThai = "ChoXacNhan",
            Chitietlichhens = [new Chitietlichhen { DichVuId = item.ServiceId, GiaDuKien = 0 }] };
        Assert.Null(await ServicePackageLifecycle.ReserveAsync(db, appointment, paid.Id, default));
        db.Lichhens.Add(appointment);
        await db.SaveChangesAsync();
        Assert.Equal(1, item.Reserved);
        Assert.Equal(paid.Id, appointment.CustomerPackageId);
        Assert.Single(await db.PackageUsages.Where(x => x.AppointmentId == appointment.LichHenId).ToListAsync());
        appointment.TrangThai = "HoanThanh";
        await ServicePackageLifecycle.SettleAsync(db, appointment, true, default);
        await db.SaveChangesAsync();
        var invoice = await db.Hoadons.Include(x => x.Thanhtoans).SingleAsync(x => x.LichHenId == appointment.LichHenId);
        Assert.Equal(0, invoice.TongTienSauGiam);
        Assert.Empty(invoice.Thanhtoans);
        Assert.Equal("DaThanhToan", invoice.TrangThai);
        Assert.Equal(0, item.Reserved);
        Assert.Equal(1, item.Used);
        item.Used = item.Granted;
        await db.SaveChangesAsync();
        var another = new Lichhen { KhachHangId = customer.KhachHangId, NgayGioHen = DateTime.Now.AddMinutes(45), TrangThai = "ChoXacNhan",
            Chitietlichhens = [new Chitietlichhen { DichVuId = item.ServiceId, GiaDuKien = 0 }] };
        Assert.NotNull(await ServicePackageLifecycle.ReserveAsync(db, another, paid.Id, default));
        Assert.Null(another.CustomerPackageId);
        await tx.RollbackAsync();
    }
}
