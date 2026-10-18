using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Encodings.Web;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;
public sealed class ReportingHttpTests
{
    private sealed class HeaderAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!int.TryParse(Request.Headers["X-Test-User"], out var id)) return Task.FromResult(AuthenticateResult.NoResult());
            var role = id == 1 ? "Admin" : id == 4 ? "Customer" : "Reception";
            var principal = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, role) }, Scheme.Name));
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name)));
        }
    }


    [Fact]
    public async Task ReportsRequireAuthenticationRoleAndCurrentDatabaseGrant()
    {
        var builder=WebApplication.CreateBuilder();var name=Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o=>o.UseInMemoryDatabase(name));
        builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddControllers(o=>o.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(ReviewsController).Assembly);
        builder.Services.AddAuthentication("Test").AddScheme<AuthenticationSchemeOptions,HeaderAuthentication>("Test",_=>{});
        builder.Services.AddAuthorization();
        await using var app=builder.Build();app.UseAuthentication();app.UseAuthorization();app.MapControllers();app.Urls.Add("http://127.0.0.1:0");
        using(var scope=app.Services.CreateScope()) {
            var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var permission=new Quyen {QuyenId=1,MaQuyen="REPORT.READ",TenQuyen="Reviews",NhomQuyen="Reviews",TrangThai=true};db.Quyens.Add(permission);
            foreach(var id in Enumerable.Range(1,4)) {
                var role=new Vaitro {VaiTroId=id,TenVaiTro=id==1?"Admin":id==4?"Customer":"Reception"};db.Vaitros.Add(role);
                db.Taikhoans.Add(new Taikhoan {TaiKhoanId=id,VaiTro=role,Email=$"review{id}@example.invalid",MatKhauHash="unused",TrangThai=true});
                if(id<=2)db.VaitroQuyens.Add(new VaitroQuyen {VaiTroId=id,Quyen=permission,DuocCap=true});
            }
            await db.SaveChangesAsync();
        }
        await app.StartAsync();
        try {
            using var client=new HttpClient {BaseAddress=new Uri(app.Urls.Single())};
            foreach(var (id,status) in new[]{(0,401),(1,200),(2,200),(3,403),(4,403)}) {
                client.DefaultRequestHeaders.Remove("X-Test-User");if(id!=0)client.DefaultRequestHeaders.Add("X-Test-User",id.ToString());
                foreach(var route in new[]{"appointment-summary", "orders", "order-summary", "order-breakdown?groupBy=staff", "new-customers", "export?report=orders"})
                    Assert.Equal(status,(int)(await client.GetAsync("/api/v1/reports/"+route)).StatusCode);

            }
            client.DefaultRequestHeaders.Remove("X-Test-User"); client.DefaultRequestHeaders.Add("X-Test-User","2");
            using(var scope=app.Services.CreateScope()) {
                var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
                var grant=await db.VaitroQuyens.SingleAsync(x=>x.VaiTroId==2); grant.DuocCap=false; await db.SaveChangesAsync();
            }
            Assert.Equal(403,(int)(await client.GetAsync("/api/v1/reports/order-summary")).StatusCode);

        } finally {await app.StopAsync();}
    }
}
