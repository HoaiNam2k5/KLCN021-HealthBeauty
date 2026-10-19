using System.ComponentModel.DataAnnotations;
namespace HealthBeauty.Api.Contracts;
public sealed record CreateAccountRequest(
    [param: Required, EmailAddress, StringLength(255)] string Email,
    [param: Required, MinLength(8), MaxLength(128)] string Password,
    [param: Required, StringLength(100)] string FullName,
    [param: Phone, StringLength(15)] string? Phone,
    [param: Range(1, int.MaxValue)] int RoleId,
    [param: Range(1, int.MaxValue)] int? StaffId = null);
public sealed record AssignAccountRoleRequest([param: Range(1, int.MaxValue)] int RoleId,
    [param: Range(1, int.MaxValue)] int? StaffId = null);
public sealed record AdminAccountResponse(int TaiKhoanId, string Email, string? TenTaiKhoan, string FullName,
    int RoleId, string Role, bool TrangThai, DateTime? KhoaDen, DateTime NgayTao, DateTime? LanDangNhapCuoi);
public sealed record CurrentPermissionsResponse(string Role, IReadOnlyList<string> Permissions);
