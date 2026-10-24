using System.Security.Claims;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using HealthBeauty.Api.Controllers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Xunit;
namespace HealthBeauty.Api.Tests;
public sealed class PermissionRegressionTests
{
    private static ClaimsPrincipal User(string role="Manager",string? id="1") => new(new ClaimsIdentity((id is null ? new List<Claim>() : [new Claim(ClaimTypes.NameIdentifier,id)]).Append(new Claim(ClaimTypes.Role,role)),"Test"));
    private static AuthorizationFilterContext Context(string controller,string action,ClaimsPrincipal user) => new(new ActionContext(new DefaultHttpContext{User=user},new RouteData(),new ControllerActionDescriptor{ControllerName=controller,ActionName=action},new ModelStateDictionary()),new List<IFilterMetadata>());
    private static async Task<Klcn021HealthBeautyContext> Db(string role="Manager")
    {
        var db=new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Vaitros.Add(new Vaitro{VaiTroId=1,TenVaiTro=role});db.Taikhoans.Add(new Taikhoan{TaiKhoanId=1,VaiTroId=1,Email="test@example.invalid",MatKhauHash="irrelevant",TrangThai=true});
        db.Quyens.AddRange(new Quyen{QuyenId=1,MaQuyen="SERVICE.WRITE",TenQuyen="Service",NhomQuyen="SERVICE",TrangThai=true},new Quyen{QuyenId=2,MaQuyen="REPORT.READ",TenQuyen="Report",NhomQuyen="REPORT",TrangThai=true});
        db.VaitroQuyens.AddRange(new VaitroQuyen{VaiTroId=1,QuyenId=1,DuocCap=true},new VaitroQuyen{VaiTroId=1,QuyenId=2,DuocCap=true});
        await db.SaveChangesAsync();db.ChangeTracker.Clear();return db;
    }
    [Theory][InlineData("Manager")][InlineData("Admin")]
    public async Task RevokeAndRestoreTakeEffectOnNextRequestWithSamePrincipal(string role)
    {
        await using var db=await Db(role);var filter=new DatabasePermissionFilter(db);var user=User(role);
        var context=Context("Services","UpdateService",user);await filter.OnAuthorizationAsync(context);Assert.Null(context.Result);
        var grant=await db.VaitroQuyens.SingleAsync(x=>x.QuyenId==1);grant.DuocCap=false;await db.SaveChangesAsync();
        context=Context("Services","UpdateService",user);await filter.OnAuthorizationAsync(context);Assert.IsType<ForbidResult>(context.Result);
        context=Context("Reports","Revenue",user);await filter.OnAuthorizationAsync(context);Assert.Null(context.Result);
        grant.DuocCap=true;await db.SaveChangesAsync();context=Context("Services","UpdateService",user);await filter.OnAuthorizationAsync(context);Assert.Null(context.Result);
    }
    [Fact] public async Task DisabledPermissionAndMissingGrantDeny()
    {
        await using var db=await Db();var filter=new DatabasePermissionFilter(db);
        (await db.Quyens.FindAsync(1))!.TrangThai=false;await db.SaveChangesAsync();
        var c=Context("Services","UpdateService",User());await filter.OnAuthorizationAsync(c);Assert.IsType<ForbidResult>(c.Result);
        c=Context("Invoices","Pay",User());await filter.OnAuthorizationAsync(c);Assert.IsType<ForbidResult>(c.Result);
    }
    [Theory][InlineData(null)][InlineData("bad")]
    public async Task MissingOrMalformedIdentityCannotUseManagementPermission(string? id)
    {
        await using var db=await Db();var c=Context("Services","UpdateService",User(id:id));await new DatabasePermissionFilter(db).OnAuthorizationAsync(c);Assert.IsType<UnauthorizedResult>(c.Result);
    }
    [Fact] public async Task CurrentAccountRoleIsUsedRatherThanOldGrant()
    {
        await using var db=await Db();db.Vaitros.Add(new Vaitro{VaiTroId=2,TenVaiTro="Reception"});(await db.Taikhoans.FindAsync(1))!.VaiTroId=2;await db.SaveChangesAsync();
        var c=Context("Services","UpdateService",User());await new DatabasePermissionFilter(db).OnAuthorizationAsync(c);Assert.IsType<ForbidResult>(c.Result);
    }
    [Theory]
    [InlineData("Appointments","GetMine","APPOINTMENT.READ")][InlineData("Appointments","Create","APPOINTMENT.WRITE")]
    [InlineData("AppointmentManagement","Get","APPOINTMENT.READ")][InlineData("AppointmentManagement","Cancel","APPOINTMENT.WRITE")]
    [InlineData("Invoices","List","INVOICE.READ")][InlineData("Invoices","Create","INVOICE.WRITE")][InlineData("Invoices","Pay","PAYMENT.WRITE")]
    [InlineData("Staff","List","STAFF.READ")][InlineData("Staff","MySchedules","STAFF.READ")][InlineData("Staff","MyAppointments","APPOINTMENT.READ")]
    [InlineData("Promotions","UpdateVoucher","PROMOTION.WRITE")][InlineData("Reviews","Pending","REVIEW.MODERATE")]
    public void ManagementMappingIsExplicit(string controller,string action,string permission) => Assert.Equal(permission,DatabasePermissionFilter.RequiredPermission(controller,action,User()));
    [Theory]
    [InlineData("Appointments","GetMine")][InlineData("Appointments","Create")][InlineData("AppointmentManagement","Cancel")]
    [InlineData("Invoices","List")][InlineData("Invoices","Create")][InlineData("Staff","List")][InlineData("Promotions","ValidateVoucher")]
    [InlineData("Auth","ChangePassword")][InlineData("CustomerAvatar","Upload")][InlineData("CustomerAvatar","Delete")]
    public void CustomerOwnedOperationsDoNotRequireManagementGrants(string controller,string action) => Assert.Null(DatabasePermissionFilter.RequiredPermission(controller,action,User("Customer")));
    [Fact] public void EveryExistingRoleRestrictedActionHasPermissionMapping()
    {
        foreach(var type in typeof(AppointmentsController).Assembly.GetTypes().Where(t=>t.IsSubclassOf(typeof(ControllerBase))))
        foreach(var method in type.GetMethods().Where(m=>m.DeclaringType==type))
        {
            var roles=type.GetCustomAttributes(typeof(AuthorizeAttribute),true).Cast<AuthorizeAttribute>().Concat(method.GetCustomAttributes(typeof(AuthorizeAttribute),true).Cast<AuthorizeAttribute>()).Where(a=>!string.IsNullOrEmpty(a.Roles)).ToList();
            if(roles.Count==0 || method.GetCustomAttributes(typeof(AllowAnonymousAttribute),true).Any()) continue;
            if ((type.Name, method.Name) is ("AuthController", "ChangePassword") or ("CustomerAvatarController", "Upload") or ("CustomerAvatarController", "Delete"))
            {
                // These new endpoints are customer-owned only, never management actions.
                Assert.All(roles, role => Assert.Equal("Customer", role.Roles));
                Assert.Null(DatabasePermissionFilter.RequiredPermission(type.Name.Replace("Controller", ""), method.Name, User("Customer")));
                continue;
            }
            Assert.True(DatabasePermissionFilter.RequiredPermission(type.Name.Replace("Controller",""),method.Name,User()) is not null,$"Unmapped: {type.Name}.{method.Name}");
        }
    }
}
