using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record AppointmentItemRequest([property: Required] int ServiceId, int? ComboId, [property: Range(0, 1000000000)] decimal ExpectedPrice);
public sealed record CreateAppointmentRequest([property: Required] DateTime AppointmentAt, [property: Required, MinLength(1)] List<AppointmentItemRequest> Items, string? Note);
public sealed record AppointmentItemResponse(int Id, int ServiceId, string ServiceName, int? ComboId, decimal ExpectedPrice);
public sealed record AppointmentResponse(int Id, int CustomerId, int? StaffId, DateTime AppointmentAt, string Status, string? Note, IReadOnlyList<AppointmentItemResponse> Items);
