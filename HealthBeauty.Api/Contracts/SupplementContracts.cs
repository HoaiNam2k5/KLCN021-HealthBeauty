using System.ComponentModel.DataAnnotations;
namespace HealthBeauty.Api.Contracts;
public sealed record AppointmentUpdateRequest(DateTime AppointmentAt, int? StaffId, string? Note);
public sealed record AppointmentStatusRequest([param: Required] string Status);
public sealed record ChangePasswordRequest([param: Required] string CurrentPassword, [param: Required, MinLength(8)] string NewPassword);
public sealed record ReportRangeRequest(DateTime? From, DateTime? To);
