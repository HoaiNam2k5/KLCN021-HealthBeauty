using System.Security.Claims;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
namespace HealthBeauty.Api.Services;

// Database grants gate management roles; Customer and Staff ownership checks still apply.
public sealed class DatabasePermissionFilter(Klcn021HealthBeautyContext db) : IAsyncAuthorizationFilter
{
    public static string? RequiredPermission(string controller, string action, ClaimsPrincipal user)
    {
        var management = user.IsInRole("Admin") || user.IsInRole("Manager") || user.IsInRole("Reception");
        var employeeRead = management || user.IsInRole("Staff");
        return controller switch
        {
            "Administration" => action switch
            {
                "Roles" or "Permissions" or "RolePermissions" => "ROLE.READ",
                "SetRolePermission" => "ROLE.WRITE", "SetAccountStatus" or "CreateAccount" or "AssignAccountRole" => "ACCOUNT.WRITE", _ => "ACCOUNT.READ"
            },
            "Services" => action is "CreateService" or "UpdateService" or "DeactivateService" or "CreateCategory" or "UpdateCategory" or "DeactivateCategory" ? "SERVICE.WRITE" : null,
            "Combos" => action is "Create" or "Update" or "Deactivate" ? "SERVICE.WRITE" : null,
            "Promotions" => action is "List" or "ValidateVoucher" ? null : "PROMOTION.WRITE",
            "Reviews" => action is "Moderate" or "Pending" ? "REVIEW.MODERATE" : null,
            "Customers" => action switch { "List" => "CUSTOMER.READ", "Update" => "CUSTOMER.WRITE", _ => null },
            "Staff" => action switch
            {
                "MyAppointments" => "APPOINTMENT.READ", "MySchedules" or "Schedules" => "STAFF.READ",
                "List" => management ? "STAFF.READ" : null, _ => "STAFF.WRITE"
            },
            "StaffManagement" => action switch { "Get" => "STAFF.READ", "Appointments" => "APPOINTMENT.READ", _ => "STAFF.WRITE" },
            "Appointments" => action == "GetMine" ? (employeeRead ? "APPOINTMENT.READ" : null) : management ? "APPOINTMENT.WRITE" : null,
            "AppointmentManagement" => action switch
            {
                "AvailableSlots" => null, "Get" => employeeRead ? "APPOINTMENT.READ" : null,
                "Update" => "APPOINTMENT.WRITE", _ => management ? "APPOINTMENT.WRITE" : null
            },
            "Invoices" => action == "Pay" ? "PAYMENT.WRITE" : management ? (action == "List" ? "INVOICE.READ" : "INVOICE.WRITE") : null,
            "Reports" => "REPORT.READ",
            _ => null
        };
    }

    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        if (context.ActionDescriptor is not ControllerActionDescriptor action) return;
        var code = RequiredPermission(action.ControllerName, action.ActionName, context.HttpContext.User);
        if (code is null) return;
        var ids = context.HttpContext.User.FindAll(ClaimTypes.NameIdentifier).Select(x => x.Value).Distinct().ToArray();
        if (context.HttpContext.User.Identity?.IsAuthenticated != true || ids.Length != 1 || !int.TryParse(ids[0], out var accountId))
        {
            context.Result = new UnauthorizedResult(); return;
        }
        var now = DateTime.UtcNow;
        var allowed = await db.Taikhoans.AsNoTracking().AnyAsync(account => account.TaiKhoanId == accountId && account.TrangThai
            && (!account.KhoaDen.HasValue || account.KhoaDen <= now)
            && db.VaitroQuyens.Any(grant => grant.VaiTroId == account.VaiTroId && grant.DuocCap && grant.Quyen.TrangThai && grant.Quyen.MaQuyen == code), context.HttpContext.RequestAborted);
        if (!allowed) context.Result = new ForbidResult();
    }
}
