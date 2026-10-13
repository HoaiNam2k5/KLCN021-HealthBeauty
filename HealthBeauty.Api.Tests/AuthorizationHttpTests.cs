using System.Net;
using System.Net.Http.Json;
using System.Text;
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
public sealed class AuthorizationHttpTests
{
    [Fact] public async Task SameSignedTokenHonorsPermissionRevocationAndAccountLockOverHttp()
    {
        var builder=WebApplication.CreateBuilder();
        var config=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{
            ["Jwt:Key"]="isolated-http-test-key-only-never-production-12345",["Jwt:Issuer"]="Isolated",["Jwt:Audience"]="Isolated"}).Build();
        // One database name for all requests/scopes in this isolated application.
        var databaseName=Guid.NewGuid().ToString();
        builder.Services.AddDbContext<Klcn021HealthBeautyContext>(o=>o.UseInMemoryDatabase(databaseName));
        builder.Services.AddScoped<AccountTokenValidation>();builder.Services.AddScoped<DatabasePermissionFilter>();
        builder.Services.AddControllers(o=>o.Filters.AddService<DatabasePermissionFilter>()).AddApplicationPart(typeof(AppointmentsController).Assembly);
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o=>{
            o.EventsType=typeof(AccountTokenValidation);
            o.TokenValidationParameters=new TokenValidationParameters{ValidateIssuer=true,ValidIssuer="Isolated",ValidateAudience=true,ValidAudience="Isolated",ValidateIssuerSigningKey=true,IssuerSigningKey=new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!)),ValidateLifetime=true,ClockSkew=TimeSpan.Zero};
        });builder.Services.AddAuthorization();
        await using var app=builder.Build();app.UseAuthentication();app.UseAuthorization();app.MapControllers();app.Urls.Add("http://127.0.0.1:0");
        string token;
        using(var scope=app.Services.CreateScope())
        {
            var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();
            var role=new Vaitro{VaiTroId=1,TenVaiTro="Manager"};db.Vaitros.Add(role);
            var account=new Taikhoan{TaiKhoanId=1,VaiTroId=1,VaiTro=role,Email="http@example.invalid",MatKhauHash="unused",TrangThai=true};db.Taikhoans.Add(account);
            db.Quyens.Add(new Quyen{QuyenId=1,MaQuyen="SERVICE.WRITE",NhomQuyen="SERVICE",TenQuyen="Write",TrangThai=true});db.VaitroQuyens.Add(new VaitroQuyen{VaiTroId=1,QuyenId=1,DuocCap=true});
            db.Loaidichvus.Add(new Loaidichvu{LoaiDichVuId=1,TenLoai="Category",TrangThai=true});db.Dichvus.Add(new Dichvu{DichVuId=1,LoaiDichVuId=1,TenDichVu="Before",Gia=100,ThoiLuongPhut=30,TrangThai=true});
            await db.SaveChangesAsync();token=new TokenService(config).CreateAccessToken(account).Token;
        }
        await app.StartAsync();
        try
        {
            using var client=new HttpClient{BaseAddress=new Uri(app.Urls.Single())};client.DefaultRequestHeaders.Authorization=new("Bearer",token);
            async Task<HttpStatusCode> Update() => (await client.PutAsJsonAsync("/api/v1/services/1",new {name="After",description="test",price=100,durationMinutes=30,categoryId=1})).StatusCode;
            Assert.Equal(HttpStatusCode.OK,await Update());
            using(var scope=app.Services.CreateScope()) {var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();(await db.VaitroQuyens.SingleAsync()).DuocCap=false;await db.SaveChangesAsync();}
            Assert.Equal(HttpStatusCode.Forbidden,await Update());
            Assert.Equal(HttpStatusCode.OK,(await client.GetAsync("/api/v1/services")).StatusCode); // Public reads survive grant revocation.
            using(var scope=app.Services.CreateScope()) {var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();(await db.VaitroQuyens.SingleAsync()).DuocCap=true;(await db.Taikhoans.SingleAsync()).TrangThai=false;await db.SaveChangesAsync();}
            Assert.Equal(HttpStatusCode.Unauthorized,await Update());
            using(var scope=app.Services.CreateScope()) {var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();var account=await db.Taikhoans.SingleAsync();account.TrangThai=true;account.KhoaDen=DateTime.UtcNow.AddMinutes(10);await db.SaveChangesAsync();}
            Assert.Equal(HttpStatusCode.Unauthorized,await Update());
            using(var scope=app.Services.CreateScope()) {var db=scope.ServiceProvider.GetRequiredService<Klcn021HealthBeautyContext>();(await db.Taikhoans.SingleAsync()).KhoaDen=null;await db.SaveChangesAsync();}
            Assert.Equal(HttpStatusCode.OK,await Update());
        }
        finally {await app.StopAsync();}
    }
}
