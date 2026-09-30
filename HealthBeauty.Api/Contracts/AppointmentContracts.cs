using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record AppointmentItemRequest([param: Required] int ServiceId, int? ComboId, [param: Range(0, 1000000000)] decimal ExpectedPrice);
public sealed record CreateAppointmentRequest([param: Required] DateTime AppointmentAt, [param: Required, MinLength(1)] List<AppointmentItemRequest> Items, string? Note);
public sealed record AppointmentItemResponse(int Id, int ServiceId, string ServiceName, int? ComboId, decimal ExpectedPrice);
public sealed record AppointmentResponse(int Id, int CustomerId, int? StaffId, DateTime AppointmentAt, string Status, string? Note, IReadOnlyList<AppointmentItemResponse> Items);
