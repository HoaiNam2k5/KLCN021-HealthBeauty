using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ServicePackageSecurityTests
{
    private const string Root = "/api/v1/service-packages";
    private sealed class HeaderAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!int.TryParse(Request.Headers["X-Test-User"], out var id)) return Task.FromResult(AuthenticateResult.NoResult());
            var role = id == 1 ? "Admin" : id >= 4 ? "Customer" : "Reception";
            var identity = new ClaimsIdentity([new(ClaimTypes.NameIdentifier, id.ToString()), new(ClaimTypes.Role, role)], Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
        }
    }

    private sealed class Host(WebApplication app, HttpClient client) : IAsyncDisposable
    {
        public HttpClient Client { get; } = client;
        public void User(int id) { Client.DefaultRequestHeaders.Remove("X-Test-User"); if (id != 0) Client.DefaultRequestHeaders.Add("X-Test-User", id.ToString()); }
        public async Task Grant(int account, string permission, bool enabled)
        {
            using var scope = app.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            (await db.VaitroQuyens.SingleAsync(x => x.VaiTroId == account && x.Quyen.MaQuyen == permission)).DuocCap = enabled;
            await db.SaveChangesAsync();
        }
        public async Task<T> Read<T>(Func<Klcn021HealthBeautyContext, Task<T>> read)
        { using var scope = app.Services.CreateScope(); return await read(scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>()); }
        public async ValueTask DisposeAsync() { Client.Dispose(); await app.StopAsync(); await app.DisposeAsync(); }
    }

    private static async Task<Host> Start()
    {
        var builder = WebApplication.CreateBuilder();
        var name = Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(name));
        builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddControllers(o => o.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(ServicePackagesController).Assembly);
        builder.Services.AddAuthentication("Test").AddScheme<AuthenticationSchemeOptions, HeaderAuthentication>("Test", _ => { });
        builder.Services.AddAuthorization();
        var app = builder.Build(); app.UseAuthentication(); app.UseAuthorization(); app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var codes = new[] { "SERVICE.WRITE", "CUSTOMER.READ", "CUSTOMER.WRITE", "PAYMENT.WRITE", "REPORT.READ", "APPOINTMENT.WRITE", "INVOICE.WRITE" };
            var permissions = codes.Select((code, i) => new Quyen { QuyenId = i + 1, MaQuyen = code, TenQuyen = code, NhomQuyen = "Packages", TrangThai = true }).ToArray();
            db.Quyens.AddRange(permissions);
            for (var id = 1; id <= 5; id++)
            {
                var role = new Vaitro { VaiTroId = id, TenVaiTro = id == 1 ? "Admin" : id >= 4 ? "Customer" : "Reception" };
                db.Taikhoans.Add(new Taikhoan { TaiKhoanId = id, VaiTro = role, Email = $"package{id}@example.invalid", MatKhauHash = "unused", TrangThai = true });
                foreach (var permission in permissions) db.VaitroQuyens.Add(new VaitroQuyen { VaiTroId = id, Quyen = permission, DuocCap = id <= 2 });
            }
            db.Khachhangs.AddRange(new Khachhang { KhachHangId = 40, TaiKhoanId = 4, HoTen = "Owner" }, new Khachhang { KhachHangId = 50, TaiKhoanId = 5, HoTen = "Other" });
            db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Massage", TrangThai = true });
            db.ServicePackages.AddRange(new ServicePackage { Id = 1, Name = "Five sessions", Price = 500000, ValidityDays = 30, Items = [new() { ServiceId = 1, Sessions = 5 }] }, new ServicePackage { Id = 2, Name = "Private inactive", Price = 10, ValidityDays = 1, Active = false });
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        return new Host(app, new HttpClient { BaseAddress = new Uri(app.Urls.Single()) });
    }

    [Fact]
    public async Task PublicCatalogHidesInactiveAndPrivateRoutesRequireAuthentication()
    {
        await using var host = await Start();
        var catalog = await host.Client.GetFromJsonAsync<JsonElement>(Root);
        Assert.Single(catalog.EnumerateArray()); Assert.Equal(1, catalog[0].GetProperty("id").GetInt32());
        Assert.Equal(HttpStatusCode.BadRequest, (await host.Client.GetAsync(Root + "?includeInactive=true")).StatusCode);
        foreach (var path in new[] { "/mine", "/management", "/purchases/1", "/customers/40", "/sales" })
            Assert.Equal(HttpStatusCode.Unauthorized, (await host.Client.GetAsync(Root + path)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await host.Client.PostAsJsonAsync(Root + "/purchases", new { packageId = 1 })).StatusCode);
    }

    [Fact]
    public async Task CustomerCannotAssignPurchaseToOthersOrInspectCancelOrPayOthersPurchase()
    {
        await using var host = await Start(); host.User(4);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.PostAsJsonAsync(Root + "/purchases", new { packageId = 1, customerId = 50 })).StatusCode);
        var created = await host.Client.PostAsJsonAsync(Root + "/purchases", new { packageId = 1 });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var id = (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt32();
        Assert.Equal(HttpStatusCode.OK, (await host.Client.GetAsync(Root + $"/purchases/{id}")).StatusCode);
        Assert.Single((await host.Client.GetFromJsonAsync<JsonElement>(Root + "/mine")).EnumerateArray());
        host.User(5);
        Assert.Empty((await host.Client.GetFromJsonAsync<JsonElement>(Root + "/mine")).EnumerateArray());
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.GetAsync(Root + $"/purchases/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.DeleteAsync(Root + $"/purchases/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.PostAsJsonAsync(Root + $"/purchases/{id}/pay", new { method = "TienMat" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.PostAsJsonAsync(Root, new { name = "Unauthorized" })).StatusCode);
        Assert.Equal("Pending", await host.Read(db => db.CustomerPackages.Select(x => x.Status).SingleAsync()));
        host.User(4); Assert.Equal(HttpStatusCode.NoContent, (await host.Client.DeleteAsync(Root + $"/purchases/{id}")).StatusCode);
    }

    [Fact]
    public async Task ManagementUsesCurrentPreciseDatabaseGrantsEvenForAdmin()
    {
        await using var host = await Start(); host.User(3);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.GetAsync(Root + "/management")).StatusCode);
        host.User(2); Assert.Equal(HttpStatusCode.OK, (await host.Client.GetAsync(Root + "/management")).StatusCode);
        await host.Grant(2, "SERVICE.WRITE", false);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.GetAsync(Root + "/management")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await host.Client.GetAsync(Root + "/customers/40")).StatusCode);
        await host.Grant(2, "CUSTOMER.WRITE", false);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.PostAsJsonAsync(Root + "/purchases", new { packageId = 1, customerId = 40 })).StatusCode);
        host.User(1); await host.Grant(1, "CUSTOMER.READ", false);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.GetAsync(Root + "/customers/40")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await host.Client.GetAsync(Root + "/management")).StatusCode);
        await host.Grant(1, "REPORT.READ", false);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.GetAsync(Root + "/sales")).StatusCode);
    }

    [Fact]
    public async Task ClientCannotSetPriceOrActivateUnpaidPackageAndPaymentRequiresGrant()
    {
        await using var host = await Start(); host.User(4);
        var response = await host.Client.PostAsJsonAsync(Root + "/purchases", new { packageId = 1, price = 1, status = "Paid", granted = 9999 });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var purchase = await response.Content.ReadFromJsonAsync<JsonElement>(); var id = purchase.GetProperty("id").GetInt32();
        Assert.Equal(500000, purchase.GetProperty("price").GetDecimal()); Assert.Equal("Pending", purchase.GetProperty("status").GetString());
        Assert.Equal(5, purchase.GetProperty("items")[0].GetProperty("granted").GetInt32()); Assert.Equal(0, purchase.GetProperty("items")[0].GetProperty("available").GetInt32());
        host.User(2); await host.Grant(2, "PAYMENT.WRITE", false);
        Assert.Equal(HttpStatusCode.Forbidden, (await host.Client.PostAsJsonAsync(Root + $"/purchases/{id}/pay", new { method = "TienMat" })).StatusCode);
        await host.Grant(2, "PAYMENT.WRITE", true);
        Assert.Equal(HttpStatusCode.OK, (await host.Client.PostAsJsonAsync(Root + $"/purchases/{id}/pay", new { method = "TienMat", price = 1 })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await host.Client.PostAsJsonAsync(Root + $"/purchases/{id}/pay", new { method = "TienMat" })).StatusCode);
        Assert.Equal(50, await host.Read(db => db.Khachhangs.Where(x => x.KhachHangId == 40).Select(x => x.DiemThuong).SingleAsync()));
        Assert.Equal(1, await host.Read(db => db.Giaodichdiems.CountAsync()));
    }

    [Fact]
    public async Task PaidPackageFlowsThroughBookingCancellationCompletionInvoiceAndReviewWithoutChargingAgain()
    {
        await using var host = await Start(); host.User(4);
        var purchaseResponse = await host.Client.PostAsJsonAsync(Root + "/purchases", new { packageId = 1 });
        Assert.Equal(HttpStatusCode.Created, purchaseResponse.StatusCode);
        var purchaseId = (await purchaseResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt32();
        var appointmentAt = DateTime.Now.AddDays(1);
        object Booking() => new { appointmentAt, customerPackageId = purchaseId, items = new[] { new { serviceId = 1, expectedPrice = 999999 } } };
        Assert.Equal(HttpStatusCode.BadRequest, (await host.Client.PostAsJsonAsync("/api/v1/appointments", Booking())).StatusCode);
        host.User(1);
        Assert.Equal(HttpStatusCode.OK, (await host.Client.PostAsJsonAsync(Root + $"/purchases/{purchaseId}/pay", new { method = "TienMat" })).StatusCode);
        host.User(4);
        var booked = await host.Client.PostAsJsonAsync("/api/v1/appointments", Booking());
        Assert.Equal(HttpStatusCode.Created, booked.StatusCode);
        var first = await booked.Content.ReadFromJsonAsync<JsonElement>(); var firstId = first.GetProperty("id").GetInt32();
        Assert.Equal("ServicePackage", first.GetProperty("fundingSource").GetString());
        Assert.Equal(0, first.GetProperty("items")[0].GetProperty("expectedPrice").GetDecimal());
        Assert.Equal(1, await host.Read(db => db.CustomerPackageItems.Select(x => x.Reserved).SingleAsync()));
        Assert.Equal(HttpStatusCode.BadRequest, (await host.Client.PostAsJsonAsync($"/api/v1/appointments/{firstId}/reschedule", new { appointmentAt = DateTime.Now.AddDays(40) })).StatusCode);
        host.User(1);
        Assert.Equal(HttpStatusCode.BadRequest, (await host.Client.PutAsJsonAsync($"/api/v1/appointments/{firstId}", new { appointmentAt = DateTime.Now.AddDays(40) })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await host.Client.PostAsJsonAsync("/api/v1/invoices", new { appointmentId = firstId, items = new[] { new { serviceId = 1, quantity = 1, unitPrice = 1 } } })).StatusCode);
        host.User(4);
        Assert.Equal(HttpStatusCode.NoContent, (await host.Client.DeleteAsync($"/api/v1/appointments/{firstId}")).StatusCode);
        Assert.Equal(0, await host.Read(db => db.CustomerPackageItems.Select(x => x.Reserved).SingleAsync()));
        var secondResponse = await host.Client.PostAsJsonAsync("/api/v1/appointments", Booking());
        Assert.Equal(HttpStatusCode.Created, secondResponse.StatusCode);
        var secondId = (await secondResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt32();
        host.User(1);
        foreach (var status in new[] { "DaXacNhan", "DaDen", "DangThucHien", "HoanThanh" })
            Assert.Equal(HttpStatusCode.NoContent, (await host.Client.PatchAsJsonAsync($"/api/v1/appointments/{secondId}/status", new { status })).StatusCode);
        var invoice = await host.Read(db => db.Hoadons.SingleAsync());
        Assert.Equal(secondId, invoice.LichHenId); Assert.Equal("DaThanhToan", invoice.TrangThai); Assert.Equal(0, invoice.TongTienSauGiam);
        Assert.Equal(0, await host.Read(db => db.CustomerPackageItems.Select(x => x.Reserved).SingleAsync()));
        Assert.Equal(1, await host.Read(db => db.CustomerPackageItems.Select(x => x.Used).SingleAsync()));
        Assert.Equal(50, await host.Read(db => db.Khachhangs.Where(x => x.KhachHangId == 40).Select(x => x.DiemThuong).SingleAsync()));
        Assert.Equal(1, await host.Read(db => db.Giaodichdiems.CountAsync()));
        host.User(4);
        Assert.Equal(HttpStatusCode.Created, (await host.Client.PostAsJsonAsync($"/api/v1/reviews/invoices/{invoice.HoaDonId}", new { stars = 5, comment = "Package visit completed" })).StatusCode);
    }
}
