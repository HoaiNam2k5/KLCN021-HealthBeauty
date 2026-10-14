using System.Net;
using System.Net.Http.Json;
using System.Text;
using HealthBeauty.Api.Contracts;
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

public sealed class AccountPermissionsHttpTests
{
    [Fact]
    public async Task ReceptionGrantsUnlockManagementRoutesRevocationDeniesAndAdminRoutesRemainRestricted()
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["Jwt:Key"] = "account-permissions-isolated-http-test-key-123456789", ["Jwt:Issuer"] = "Isolated", ["Jwt:Audience"] = "Isolated" }).Build();
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddSingleton<IConfiguration>(config);
        var databaseName = Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(options => options.UseInMemoryDatabase(databaseName));
        builder.Services.AddScoped<AccountTokenValidation>(); builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddScoped<IPasswordService, PasswordService>(); builder.Services.AddScoped<ITokenService, TokenService>();
        builder.Services.AddControllers(options => options.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(AdministrationController).Assembly);
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options => {
            options.EventsType = typeof(AccountTokenValidation);
            options.TokenValidationParameters = new TokenValidationParameters { ValidateIssuer = true, ValidIssuer = "Isolated", ValidateAudience = true, ValidAudience = "Isolated",
                ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!)), ValidateLifetime = true, ClockSkew = TimeSpan.Zero };
        });
        builder.Services.AddAuthorization();
        builder.Services.AddCors(options => options.AddPolicy(DevelopmentClientCors.PolicyName, DevelopmentClientCors.Configure));
        await using var app = builder.Build(); app.UseCors(DevelopmentClientCors.PolicyName); app.UseAuthentication(); app.UseAuthorization(); app.MapControllers(); app.Urls.Add("http://127.0.0.1:0");
        var tokens = new Dictionary<string, string>();
        var codes = new[] { "SERVICE.WRITE", "STAFF.READ", "STAFF.WRITE", "REPORT.READ", "PROMOTION.WRITE", "REVIEW.MODERATE", "ACCOUNT.WRITE", "ACCOUNT.READ", "APPOINTMENT.READ" };
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var roles = new[] { "Admin", "Manager", "Reception", "Staff", "Customer" };
            for (var index = 0; index < roles.Length; index++)
            {
                var role = new Vaitro { VaiTroId = index + 1, TenVaiTro = roles[index] };
                var account = new Taikhoan { TaiKhoanId = index + 1, VaiTro = role, VaiTroId = role.VaiTroId, Email = roles[index] + "@example.com", TenTaiKhoan = roles[index], MatKhauHash = "unused", TrangThai = true };
                db.Vaitros.Add(role); db.Taikhoans.Add(account);
                tokens[roles[index]] = new TokenService(config).CreateAccessToken(account).Token;
            }
            for (var index = 0; index < codes.Length; index++)
            {
                db.Quyens.Add(new Quyen { QuyenId = index + 1, MaQuyen = codes[index], TenQuyen = codes[index], NhomQuyen = "Test", TrangThai = true });
                foreach (var roleId in new[] { 1, 3, 4, 5 }) db.VaitroQuyens.Add(new VaitroQuyen { VaiTroId = roleId, QuyenId = index + 1, DuocCap = true });
            }
            db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 5, HoTen = "Customer" });
            db.Loaidichvus.Add(new Loaidichvu { LoaiDichVuId = 1, TenLoai = "Category", TrangThai = true });
            db.Dichvus.Add(new Dichvu { DichVuId = 1, LoaiDichVuId = 1, TenDichVu = "Service", Gia = 100000, ThoiLuongPhut = 30, TrangThai = true });
            db.Nhanviens.Add(new Nhanvien { NhanVienId = 4, TaiKhoanId = 4, HoTen = "Staff" });
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        try
        {
            using var client = new HttpClient { BaseAddress = new Uri(app.Urls.Single()) };
            foreach (var origin in new[] { "http://localhost:5173", "http://127.0.0.1:5174", "https://foreign.example" })
            {
                using var preflight = new HttpRequestMessage(HttpMethod.Options, "/api/v1/customers/me");
                preflight.Headers.Add("Origin", origin);
                preflight.Headers.Add("Access-Control-Request-Method", "GET");
                preflight.Headers.Add("Access-Control-Request-Headers", "authorization");
                using var cors = await client.SendAsync(preflight);
                Assert.Equal(HttpStatusCode.NoContent, cors.StatusCode);
                if (origin == "https://foreign.example") Assert.False(cors.Headers.Contains("Access-Control-Allow-Origin"));
                else Assert.Equal(origin, Assert.Single(cors.Headers.GetValues("Access-Control-Allow-Origin")));
            }
            client.DefaultRequestHeaders.Authorization = new("Bearer", tokens["Reception"]);
            var self = await client.GetFromJsonAsync<CurrentPermissionsResponse>("/api/v1/auth/permissions");
            Assert.Equal("Reception", self!.Role); Assert.Contains("REPORT.READ", self.Permissions);
            var cases = new (string Code, HttpStatusCode Expected, Func<Task<HttpResponseMessage>> Request)[] {
                ("REPORT.READ", HttpStatusCode.OK, () => client.GetAsync("/api/v1/reports/revenue")),
                ("PROMOTION.WRITE", HttpStatusCode.OK, () => client.GetAsync("/api/v1/vouchers")),
                ("REVIEW.MODERATE", HttpStatusCode.OK, () => client.GetAsync("/api/v1/reviews/pending")),
                ("STAFF.READ", HttpStatusCode.OK, () => client.GetAsync("/api/v1/staff/schedules")),
                ("SERVICE.WRITE", HttpStatusCode.OK, () => client.PutAsJsonAsync("/api/v1/services/1", new { categoryId = 1, name = "Changed", price = 100000, durationMinutes = 30 })),
                ("SERVICE.WRITE", HttpStatusCode.Created, () => client.PostAsJsonAsync("/api/v1/combos", new { name = "Combo", price = 80000, items = new[] { new { serviceId = 1, quantity = 1 } } })),
                ("STAFF.WRITE", HttpStatusCode.Created, () => client.PostAsJsonAsync("/api/v1/staff/schedules", new { staffId = 4, workDate = "2030-01-01", startAt = "09:00:00", endAt = "18:00:00" })),
                ("PROMOTION.WRITE", HttpStatusCode.Created, () => client.PostAsJsonAsync("/api/v1/promotions", new { name = "Promotion", discountType = "SoTien", discount = 1000 })),
            };
            foreach (var item in cases)
            {
                using var allowed = await item.Request();
                Assert.Equal(item.Expected, allowed.StatusCode);
                using (var scope = app.Services.CreateScope()) {
                    var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
                    (await db.VaitroQuyens.SingleAsync(grant => grant.VaiTroId == 3 && grant.Quyen.MaQuyen == item.Code)).DuocCap = false; await db.SaveChangesAsync();
                }
                using var denied = await item.Request(); Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
                using (var scope = app.Services.CreateScope()) {
                    var db = scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
                    (await db.VaitroQuyens.SingleAsync(grant => grant.VaiTroId == 3 && grant.Quyen.MaQuyen == item.Code)).DuocCap = true; await db.SaveChangesAsync();
                }
            }
            Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/v1/admin/accounts")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/v1/admin/accounts", new { email = "blocked@example.com", password = "password-123", fullName = "Blocked", roleId = 5 })).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PatchAsJsonAsync("/api/v1/admin/accounts/1/role", new { roleId = 5 })).StatusCode);
            foreach (var role in new[] { "Staff", "Customer" })
            {
                client.DefaultRequestHeaders.Authorization = new("Bearer", tokens[role]);
                Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/v1/reports/revenue")).StatusCode);
                Assert.Equal(HttpStatusCode.Forbidden, (await client.PutAsJsonAsync("/api/v1/services/1", new { categoryId = 1, name = "Blocked", price = 100000, durationMinutes = 30 })).StatusCode);
            }
            client.DefaultRequestHeaders.Authorization = new("Bearer", tokens["Admin"]);
            using var created = await client.PostAsJsonAsync("/api/v1/admin/accounts", new { email = "new@example.com", password = "password-123", fullName = "New User", roleId = 5 });
            Assert.Equal(HttpStatusCode.Created, created.StatusCode);
            var accountDto = await created.Content.ReadFromJsonAsync<AdminAccountResponse>();
            Assert.NotNull(accountDto); Assert.Equal(5, accountDto.RoleId);
            Assert.Equal(HttpStatusCode.OK, (await client.PatchAsJsonAsync($"/api/v1/admin/accounts/{accountDto.TaiKhoanId}/role", new { roleId = 4 })).StatusCode);
            // Full isolated HTTP flow: create linked employee, customer books them, new Staff logs in and sees only their booking.
            client.DefaultRequestHeaders.Authorization = new("Bearer", tokens["Reception"]);
            using var newEmployeeResponse = await client.PostAsJsonAsync("/api/v1/staff", new {
                fullName = "New therapist", position = "Therapist", specialty = "Facial", phone = "0901234567",
                hireDate = "2026-10-01", email = "therapist@example.com", password = "password-123", roleId = 1 });
            Assert.Equal(HttpStatusCode.Created, newEmployeeResponse.StatusCode);
            var employeeJson = await newEmployeeResponse.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
            var employeeId = employeeJson.GetProperty("nhanVienId").GetInt32();
            var accountId = employeeJson.GetProperty("taiKhoanId").GetInt32();
            Assert.DoesNotContain("MatKhauHash", employeeJson.ToString(), StringComparison.OrdinalIgnoreCase);
            var bookingDay = DateTime.Today.AddDays(10);
            using var newShift = await client.PostAsJsonAsync("/api/v1/staff/schedules", new {
                staffId = employeeId, workDate = bookingDay.ToString("yyyy-MM-dd"), startAt = "09:00:00", endAt = "18:00:00" });
            Assert.Equal(HttpStatusCode.Created, newShift.StatusCode);
            client.DefaultRequestHeaders.Authorization = new("Bearer", tokens["Customer"]);
            var availableEmployees = await client.GetFromJsonAsync<System.Text.Json.JsonElement>("/api/v1/staff");
            Assert.Contains(availableEmployees.EnumerateArray(), x => x.GetProperty("nhanVienId").GetInt32() == employeeId);
            Assert.All(availableEmployees.EnumerateArray(), x => Assert.Equal(System.Text.Json.JsonValueKind.Null, x.GetProperty("taiKhoanId").ValueKind));
            using var booking = await client.PostAsJsonAsync("/api/v1/appointments", new {
                appointmentAt = bookingDay.AddHours(10), staffId = employeeId, items = new[] { new { serviceId = 1 } } });
            Assert.Equal(HttpStatusCode.Created, booking.StatusCode);
            var bookingDto = await booking.Content.ReadFromJsonAsync<AppointmentResponse>();
            using var employeeLogin = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "therapist@example.com", password = "password-123" });
            Assert.Equal(HttpStatusCode.OK, employeeLogin.StatusCode);
            var employeeAuth = await employeeLogin.Content.ReadFromJsonAsync<AuthResponse>();
            Assert.Equal("Staff", employeeAuth!.Account!.Role); Assert.Equal(accountId, employeeAuth.Account.Id);
            client.DefaultRequestHeaders.Authorization = new("Bearer", employeeAuth.AccessToken);
            var ownBookings = await client.GetFromJsonAsync<System.Text.Json.JsonElement>("/api/v1/appointments");
            Assert.Equal(1, ownBookings.GetProperty("totalCount").GetInt32());
            Assert.Equal(bookingDto!.Id, ownBookings.GetProperty("items")[0].GetProperty("id").GetInt32());
            Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/v1/appointments/{bookingDto.Id}")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/v1/staff", new {
                fullName = "Blocked", email = "blocked-staff@example.com", password = "password-123" })).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PatchAsJsonAsync($"/api/v1/admin/accounts/{accountId}/role", new { roleId = 1 })).StatusCode);
            client.DefaultRequestHeaders.Authorization = new("Bearer", tokens["Staff"]);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/v1/appointments/{bookingDto.Id}")).StatusCode);
            client.DefaultRequestHeaders.Authorization = new("Bearer", tokens["Admin"]);
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/admin/accounts", new { email = "invalid", password = "short", fullName = "", roleId = 0 })).StatusCode);
        }
        finally { await app.StopAsync(); }
    }
}
