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

public sealed class NotificationHttpTests
{
    private sealed class Server : IAsyncDisposable
    {
        public required WebApplication App { get; init; }
        public required HttpClient Client { get; init; }
        public required string[] Tokens { get; init; }
        public async Task Db(Func<Klcn021HealthBeautyContext, Task> action)
        {
            using var scope = App.Services.CreateScope();
            await action(scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>());
        }
        public void User(int id) => Client.DefaultRequestHeaders.Authorization = new("Bearer", Tokens[id - 1]);
        public async ValueTask DisposeAsync() { Client.Dispose(); await App.StopAsync(); await App.DisposeAsync(); }
    }
    private static async Task<Server> Start()
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["Jwt:Key"] = "notification-http-test-signing-key-not-production-123456", ["Jwt:Issuer"] = "Notifications", ["Jwt:Audience"] = "Notifications" }).Build();
        var builder = WebApplication.CreateBuilder(); var name = Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o => o.UseInMemoryDatabase(name));
        builder.Services.AddScoped<AccountTokenValidation>(); builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddControllers(o => o.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(NotificationsController).Assembly);
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o => {
            o.EventsType = typeof(AccountTokenValidation);
            o.TokenValidationParameters = new TokenValidationParameters { ValidateIssuer = true, ValidIssuer = "Notifications",
                ValidateAudience = true, ValidAudience = "Notifications", ValidateLifetime = true, ClockSkew = TimeSpan.Zero,
                ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!)) };
        });
        builder.Services.AddAuthorization(); var app = builder.Build();
        app.UseAuthentication(); app.UseAuthorization(); app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        var tokens = new List<string>();
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var role = new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" }; db.Vaitros.Add(role);
            for (int id = 1; id <= 2; id++)
            {
                var account = new Taikhoan { TaiKhoanId = id, VaiTro = role, VaiTroId = 1, Email = $"user{id}@example.invalid", MatKhauHash = "unused", TrangThai = true };
                db.Taikhoans.Add(account); db.Khachhangs.Add(new Khachhang { KhachHangId = id, TaiKhoanId = id, HoTen = $"Customer {id}" });
                tokens.Add(new TokenService(config).CreateAccessToken(account).Token);
            }
            db.ThongBaos.AddRange(new ThongBao { ThongBaoId = 1, TieuDe = "Broadcast", NoiDung = "Body", LoaiThongBao = "KhuyenMai", NgayTao = DateTime.UtcNow },
                new ThongBao { ThongBaoId = 2, TaiKhoanId = 1, KhachHangId = 1, TieuDe = "Private", NoiDung = "Body", LoaiThongBao = "LichHen", DuLieuKemTheo = "{\"appointmentId\":\"7\"}", NgayTao = DateTime.UtcNow });
            await db.SaveChangesAsync();
        }
        await app.StartAsync(); return new Server { App = app, Tokens = tokens.ToArray(), Client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) } };
    }

    [Fact]
    public async Task AllSixRoutesRequireJwtAndDeviceValidationUsesActualHttpModelBinding()
    {
        await using var s = await Start();
        foreach (var (method, path) in new[] { (HttpMethod.Get, ""), (HttpMethod.Get, "/unread-count"),
            (HttpMethod.Post, "/device-token"), (HttpMethod.Delete, "/device-token?token=device"),
            (HttpMethod.Patch, "/1/read"), (HttpMethod.Patch, "/read-all") })
        {
            using var request = new HttpRequestMessage(method, "/api/v1/notifications" + path);
            if (method == HttpMethod.Post) request.Content = JsonContent.Create(new { token = "device", deviceType = "android" });
            using var response = await s.Client.SendAsync(request); Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
        s.User(1);
        foreach (var payload in new[] { new { token = "", deviceType = "android" }, new { token = new string('x', 501), deviceType = "ios" }, new { token = "device", deviceType = "other" } })
        {
            using var response = await s.Client.PostAsJsonAsync("/api/v1/notifications/device-token", payload);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }
        await s.Db(async db => Assert.Empty(await db.ThietBiKhachHangs.ToListAsync()));
        await s.Db(async db => { (await db.Taikhoans.FindAsync(1))!.TrangThai = false; await db.SaveChangesAsync(); });
        using var denied = await s.Client.GetAsync("/api/v1/notifications"); Assert.Equal(HttpStatusCode.Unauthorized, denied.StatusCode);
    }

    [Fact]
    public async Task HttpWireContractPreservesPrivateReadStateAndTokenRebindingOwnership()
    {
        await using var s = await Start(); s.User(1);
        using var inbox = await s.Client.GetAsync("/api/v1/notifications"); Assert.Equal(HttpStatusCode.OK, inbox.StatusCode);
        var json = JsonDocument.Parse(await inbox.Content.ReadAsStringAsync()).RootElement;
        Assert.Equal(2, json.GetProperty("totalCount").GetInt32());
        var item = json.GetProperty("items").EnumerateArray().Single(x => x.GetProperty("id").GetInt32() == 2);
        Assert.Equal(JsonValueKind.String, item.GetProperty("data").ValueKind);
        Assert.Equal(new[] { "id", "title", "body", "type", "data", "isRead", "createdAt" }, item.EnumerateObject().Select(x => x.Name));
        Assert.Equal(HttpStatusCode.NoContent, (await s.Client.PatchAsync("/api/v1/notifications/1/read", null)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/notifications/device-token", new { token = "shared-device", deviceType = "android" })).StatusCode);
        s.User(2);
        Assert.Equal(HttpStatusCode.NotFound, (await s.Client.PatchAsync("/api/v1/notifications/2/read", null)).StatusCode);
        var second = await s.Client.GetFromJsonAsync<JsonElement>("/api/v1/notifications");
        Assert.Equal(1, second.GetProperty("unreadCount").GetInt32()); Assert.False(second.GetProperty("items")[0].GetProperty("isRead").GetBoolean());
        Assert.Equal(HttpStatusCode.OK, (await s.Client.PostAsJsonAsync("/api/v1/notifications/device-token", new { token = "shared-device", deviceType = "ios" })).StatusCode);
        s.User(1); Assert.Equal(HttpStatusCode.NoContent, (await s.Client.DeleteAsync("/api/v1/notifications/device-token?token=shared-device")).StatusCode);
        await s.Db(async db => { var device = Assert.Single(await db.ThietBiKhachHangs.ToListAsync()); Assert.Equal(2, device.TaiKhoanId); Assert.True(device.TrangThai); });
    }
}
