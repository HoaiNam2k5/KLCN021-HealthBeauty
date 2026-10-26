using System.ComponentModel.DataAnnotations;
namespace HealthBeauty.Api.Contracts;
public sealed record AppointmentUpdateRequest(DateTime AppointmentAt, int? StaffId, string? Note);
public sealed record AppointmentStatusRequest([param: Required] string Status, [param: MaxLength(1000)] string? Reason = null);
public sealed record ChangePasswordRequest([param: Required, MaxLength(4096)] string CurrentPassword, [param: Required, MinLength(8), MaxLength(128)] string NewPassword);
public sealed record ReportRangeRequest(DateTime? From, DateTime? To);
