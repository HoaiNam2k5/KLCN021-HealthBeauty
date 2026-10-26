using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class BankTransferHttpTests
{
    private const string WebhookKey = "http-test-webhook-key-32-characters-only";

    private sealed class Server : IAsyncDisposable
    {
        public required WebApplication App { get; init; }
        public required HttpClient Client { get; init; }
        public required string[] Tokens { get; init; }
        public void User(int id) => Client.DefaultRequestHeaders.Authorization = new("Bearer", Tokens[id - 1]);
        public async ValueTask DisposeAsync() { Client.Dispose(); await App.StopAsync(); await App.DisposeAsync(); }
    }

    private static async Task<Server> Start(bool lifecycle = false)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = "bank-transfer-http-test-signing-key-1234567890",
            ["Jwt:Issuer"] = "BankTransferTests", ["Jwt:Audience"] = "BankTransferTests"
        }).Build();
        var builder = WebApplication.CreateBuilder();
        var name = Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(name));
        builder.Services.AddScoped<AccountTokenValidation>();
        builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddScoped<INotificationService, NotificationService>();
        builder.Services.Configure<BankTransferOptions>(o =>
        {
            o.Enabled = true; o.BankName = "Vietcombank"; o.BankCode = "VCB";
            o.AccountNumber = "001122334455"; o.AccountName = "TEST ONLY"; o.WebhookApiKey = WebhookKey;
        });
        builder.Services.AddControllers(o => o.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(InvoicesController).Assembly);
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
        {
            o.EventsType = typeof(AccountTokenValidation);
            o.TokenValidationParameters = new()
            {
                ValidateIssuer = true, ValidIssuer = "BankTransferTests", ValidateAudience = true, ValidAudience = "BankTransferTests",
                ValidateLifetime = true, ClockSkew = TimeSpan.Zero, ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!))
            };
        });
        builder.Services.AddAuthorization();
        var app = builder.Build();
        app.UseAuthentication(); app.UseAuthorization(); app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        var tokens = new List<string>();
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var role = new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" }; db.Vaitros.Add(role);
            for (var id = 1; id <= 2; id++)
            {
                var account = new Taikhoan { TaiKhoanId = id, VaiTroId = 1, VaiTro = role, Email = $"bank{id}@example.invalid", MatKhauHash = "unused", TrangThai = true };
                db.Taikhoans.Add(account);
                db.Khachhangs.Add(new Khachhang { KhachHangId = id, TaiKhoanId = id, HoTen = "Customer " + id, DiemThuong = lifecycle ? 50 : 0 });
                tokens.Add(new TokenService(config).CreateAccessToken(account).Token);
            }
            if (lifecycle)
            {
                var reception = new Vaitro { VaiTroId = 2, TenVaiTro = "Reception" };
                var account = new Taikhoan { TaiKhoanId = 3, VaiTroId = 2, VaiTro = reception,
                    Email = "reception@example.invalid", MatKhauHash = "unused", TrangThai = true };
                db.Vaitros.Add(reception); db.Taikhoans.Add(account);
                tokens.Add(new TokenService(config).CreateAccessToken(account).Token);
                var codes = new[] { "APPOINTMENT.WRITE", "INVOICE.READ", "INVOICE.WRITE", "PAYMENT.WRITE" };
                for (var index = 0; index < codes.Length; index++)
                {
                    var permission = new Quyen { QuyenId = index + 1, MaQuyen = codes[index], TenQuyen = codes[index], NhomQuyen = "Test", TrangThai = true };
                    db.Quyens.Add(permission);
                    db.VaitroQuyens.Add(new VaitroQuyen { VaiTroId = 2, QuyenId = index + 1, Quyen = permission, DuocCap = true });
                }
                db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Booked service", Gia = 999000m, TrangThai = true });
                db.Lichhens.Add(new Lichhen { LichHenId = 7, KhachHangId = 1, NgayGioHen = DateTime.Now, TrangThai = "ChoXacNhan",
                    Chitietlichhens = [new() { DichVuId = 1, GiaDuKien = 100000m }] });
            }
            else
                db.Hoadons.Add(new Hoadon { HoaDonId = 1, LichHenId = 1, KhachHangId = 1, NgayLap = DateTime.Now.AddHours(-1), TrangThai = "ChuaThanhToan", TongTienSauGiam = 100000m });
            db.CustomerPackages.Add(new CustomerPackage { Id = 1, CustomerId = 1, Name = "Prepaid HTTP", Price = 100000m,
                ValidityDays = 30, CreatedAt = DateTime.Now.AddHours(-1), Items = [new() { ServiceId = 1, ServiceName = "Care", Granted = 5 }] });
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        return new() { App = app, Tokens = tokens.ToArray(), Client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) } };
    }

    private static object Transfer() => new
    {
        id = 1234, gateway = "Vietcombank", accountNumber = "001122334455", transferType = "in",
        transferAmount = 100000, code = "HB1", content = "HB1", referenceCode = "HTTP-TEST",
        transactionDate = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss")
    };

    [Fact]
    public async Task PackageQrJwtOwnershipAndAuthenticatedWebhookActivateThroughActualHttp()
    {
        await using var s = await Start();
        const string path = "/api/v1/service-packages/purchases/1/bank-transfer";
        Assert.Equal(HttpStatusCode.Unauthorized, (await s.Client.PostAsync(path, null)).StatusCode);
        s.User(2); Assert.Equal(HttpStatusCode.NotFound, (await s.Client.PostAsync(path, null)).StatusCode);
        s.User(1);
        var qr = await s.Client.PostAsync(path, null); Assert.Equal(HttpStatusCode.OK, qr.StatusCode);
        var info = await qr.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, info.GetProperty("purchaseId").GetInt32());
        Assert.Equal("HP1", info.GetProperty("transferContent").GetString());
        Assert.Equal("Pending", info.GetProperty("status").GetString());
        Assert.DoesNotContain(WebhookKey, info.ToString());
        var payload = new { id = 90001, gateway = "Vietcombank", accountNumber = "001122334455", transferType = "in",
            transferAmount = 100000, code = "HP1", content = "HP1", referenceCode = "PACKAGE-HTTP-TEST",
            transactionDate = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss") };
        Assert.Equal(HttpStatusCode.Unauthorized, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", payload)).StatusCode);
        s.Client.DefaultRequestHeaders.Authorization = new("Apikey", WebhookKey);
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", payload)).StatusCode);
        s.User(1);
        var detail = await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/service-packages/purchases/1");
        Assert.Equal("Paid", detail.GetProperty("package").GetProperty("status").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await s.Client.PostAsync(path, null)).StatusCode);
        using var scope = s.App.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
        Assert.Single(await db.SePayTransactions.ToListAsync()); Assert.Single(await db.Giaodichdiems.ToListAsync());
        Assert.Equal(10, (await db.Khachhangs.FindAsync(1))!.DiemThuong);
        var purchase = (await db.CustomerPackages.FindAsync(1))!;
        Assert.Equal(1, purchase.PaidByAccountId);
        Assert.NotNull(await db.Taikhoans.FindAsync(purchase.PaidByAccountId));
        Assert.NotNull(purchase.PaidAt); Assert.NotNull(purchase.ExpiresAt);
        Assert.True(purchase.ExpiresAt > purchase.PaidAt);
        Assert.Equal("ChuyenKhoan", purchase.PaymentMethod);
        Assert.Equal("ChuaThanhToan", (await db.Hoadons.FindAsync(1))!.TrangThai);
    }

    [Fact]
    public async Task JwtOwnershipAndApiKeyWebhookUseActualWireContract()
    {
        await using var s = await Start();
        Assert.Equal(HttpStatusCode.Unauthorized, (await s.Client.GetAsync("/api/v1/invoices/1")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await s.Client.PostAsync("/api/v1/invoices/1/bank-transfer", null)).StatusCode);
        s.User(2);
        Assert.Equal(HttpStatusCode.NotFound, (await s.Client.GetAsync("/api/v1/invoices/1")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await s.Client.PostAsync("/api/v1/invoices/1/bank-transfer", null)).StatusCode);
        s.User(1);
        var qrResponse = await s.Client.PostAsync("/api/v1/invoices/1/bank-transfer", null);
        Assert.Equal(HttpStatusCode.OK, qrResponse.StatusCode);
        var qr = await qrResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("HB1", qr.GetProperty("transferContent").GetString());
        Assert.Equal(100000, qr.GetProperty("amount").GetDecimal());
        Assert.DoesNotContain(WebhookKey, qr.ToString());
        Assert.Equal(HttpStatusCode.Forbidden, (await s.Client.PostAsJsonAsync("/api/v1/invoices/1/payments", new { method = "ChuyenKhoan", status = "ThanhCong" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", Transfer())).StatusCode);
        s.Client.DefaultRequestHeaders.Authorization = new("Apikey", WebhookKey);
        var settled = await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", Transfer());
        Assert.Equal(HttpStatusCode.OK, settled.StatusCode);
        Assert.True((await settled.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("success").GetBoolean());
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", Transfer())).StatusCode);
        s.User(1);
        var detail = (await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices/1"));
        Assert.Equal("DaThanhToan", detail.GetProperty("status").GetString());
        Assert.Single(detail.GetProperty("payments").EnumerateArray());
        var history = await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?offset=0&limit=50");
        Assert.Equal(JsonValueKind.Array, history.ValueKind);
        Assert.Single(history.EnumerateArray());
    }

    [Fact]
    public async Task InvalidWebhookPayloadIsRejectedByModelBindingWithoutSettlement()
    {
        await using var s = await Start();
        s.Client.DefaultRequestHeaders.Authorization = new("Apikey", WebhookKey);
        Assert.Equal(HttpStatusCode.BadRequest, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", new { id = -1 })).StatusCode);
        s.User(1);
        var detail = await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices/1");
        Assert.Equal("ChuaThanhToan", detail.GetProperty("status").GetString());
        Assert.Empty(detail.GetProperty("payments").EnumerateArray());
    }
    [Fact]
    public async Task HttpAppointmentCompletionCreatesPrivatePendingNoticeAndWebhookUpdatesAdminHistory()
    {
        await using var s = await Start(lifecycle: true);
        s.User(1);
        Assert.Equal(HttpStatusCode.Forbidden, (await s.Client.PatchAsJsonAsync("/api/v1/appointments/7/status", new { status = "HoanThanh" })).StatusCode);
        s.User(3);
        foreach (var status in new[] { "DaXacNhan", "DaDen", "DangThucHien" })
        {
            Assert.Equal(HttpStatusCode.NoContent, (await s.Client.PatchAsJsonAsync("/api/v1/appointments/7/status", new { status })).StatusCode);
            Assert.Empty((await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?appointmentId=7")).EnumerateArray());
        }
        Assert.Equal(HttpStatusCode.NoContent, (await s.Client.PatchAsJsonAsync("/api/v1/appointments/7/status", new { status = "HoanThanh" })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await s.Client.PatchAsJsonAsync("/api/v1/appointments/7/status", new { status = "HoanThanh" })).StatusCode);
        s.User(1);
        var invoice = Assert.Single((await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?status=ChuaThanhToan&appointmentId=7")).EnumerateArray());
        Assert.Equal(100000m, invoice.GetProperty("total").GetDecimal());
        var id = invoice.GetProperty("id").GetInt32();
        Assert.Equal(HttpStatusCode.Forbidden, (await s.Client.PostAsJsonAsync($"/api/v1/invoices/{id}/discounts", new { pointsToRedeem = 1 })).StatusCode);
        var inbox = await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/notifications");
        var pending = Assert.Single(inbox.GetProperty("items").EnumerateArray().Where(x => x.GetProperty("type").GetString() == "HoaDon"));
        var pendingData = JsonDocument.Parse(pending.GetProperty("data").GetString()!).RootElement;
        Assert.Equal("INVOICE", pendingData.GetProperty("type").GetString());
        Assert.Equal("7", pendingData.GetProperty("appointmentId").GetString());
        Assert.False(pendingData.TryGetProperty("invoiceId", out _));
        s.User(2);
        Assert.Empty((await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?appointmentId=7")).EnumerateArray());
        s.Client.DefaultRequestHeaders.Authorization = new("Apikey", WebhookKey);
        var payment = new { id = 555, gateway = "Vietcombank", accountNumber = "001122334455", transferType = "in",
            transferAmount = 100000, code = "HB" + id, content = "HB" + id, referenceCode = "LIFECYCLE-TEST",
            transactionDate = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd HH:mm:ss") };
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", payment)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/payments/sepay/webhook", payment)).StatusCode);
        s.User(3);
        var admin = Assert.Single((await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?status=DaThanhToan&appointmentId=7")).EnumerateArray());
        Assert.Equal(id, admin.GetProperty("id").GetInt32());
        Assert.Single(admin.GetProperty("payments").EnumerateArray());
        Assert.Empty((await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?status=ChuaThanhToan&appointmentId=7")).EnumerateArray());
    }

    [Fact]
    public async Task HttpFirstTimeDiscountKeepsPriceSnapshotsAndCannotBeAppliedTwice()
    {
        await using var s = await Start(lifecycle: true); s.User(3);
        foreach (var status in new[] { "DaXacNhan", "DaDen", "DangThucHien", "HoanThanh" })
            Assert.Equal(HttpStatusCode.NoContent, (await s.Client.PatchAsJsonAsync("/api/v1/appointments/7/status", new { status })).StatusCode);
        var invoice = Assert.Single((await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/invoices?appointmentId=7")).EnumerateArray());
        var id = invoice.GetProperty("id").GetInt32();
        var response = await s.Client.PostAsJsonAsync($"/api/v1/invoices/{id}/discounts", new { voucherCode = (string?)null, pointsToRedeem = 10 });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var adjusted = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(99990m, adjusted.GetProperty("total").GetDecimal());
        Assert.Equal(100000m, adjusted.GetProperty("subtotal").GetDecimal());
        Assert.Equal(HttpStatusCode.Conflict, (await s.Client.PostAsJsonAsync($"/api/v1/invoices/{id}/discounts", new { pointsToRedeem = 10 })).StatusCode);
    }

}
