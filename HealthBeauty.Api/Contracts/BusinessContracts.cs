using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record UpdateCustomerRequest([property: Required, StringLength(100)] string FullName, [property: Phone, StringLength(15)] string? Phone, [property: StringLength(20)] string? Gender);
public sealed record CustomerResponse(int Id, string FullName, string? Phone, string? Gender, int RewardPoints);
public sealed record StaffRequest([property: Required, StringLength(100)] string FullName, [property: StringLength(50)] string? Position, [property: StringLength(255)] string? Specialty, [property: Phone, StringLength(15)] string? Phone, DateOnly? HireDate);
public sealed record WorkScheduleRequest([property: Range(1, int.MaxValue)] int StaffId, DateOnly WorkDate, TimeOnly StartAt, TimeOnly EndAt, [property: StringLength(30)] string? Status);
public sealed record ComboItemRequest([property: Range(1, int.MaxValue)] int ServiceId, [property: Range(1, 100)] int Quantity);
public sealed record ComboRequest([property: Required, StringLength(150)] string Name, [property: Range(0, 1000000000)] decimal Price, DateOnly? ValidFrom, DateOnly? ValidTo, [property: MinLength(1)] List<ComboItemRequest> Items);
public sealed record ComboItemResponse(int ServiceId, string ServiceName, int Quantity);
public sealed record ComboResponse(int Id, string Name, decimal Price, DateOnly? ValidFrom, DateOnly? ValidTo, bool Active, IReadOnlyList<ComboItemResponse> Items);
public sealed record InvoiceLineRequest(int? ServiceId, int? ComboId, [property: Range(1, 100)] int Quantity);
public sealed record CreateInvoiceRequest([property: Range(1, int.MaxValue)] int AppointmentId, [property: MinLength(1)] List<InvoiceLineRequest> Items, string? VoucherCode, [property: Range(0, 1000000)] int PointsToRedeem = 0);
public sealed record PaymentRequest([property: Required, StringLength(30)] string Method, [property: Required] string Status = "ThanhCong");
public sealed record InvoiceLineResponse(int Id, int? ServiceId, string? ServiceName, int? ComboId, string? ComboName, int Quantity, decimal UnitPrice);
public sealed record PaymentResponse(int Id, string Method, decimal Amount, DateTime? PaidAt, string Status);
public sealed record InvoiceResponse(int Id, int AppointmentId, int CustomerId, DateTime CreatedAt, decimal Subtotal, decimal Total, string Status, IReadOnlyList<InvoiceLineResponse> Items, IReadOnlyList<PaymentResponse> Payments);
public sealed record PromotionRequest([property: Required, StringLength(150)] string Name, [property: Required, StringLength(30)] string DiscountType, [property: Range(0, 1000000000)] decimal Discount, [property: StringLength(1000)] string? Condition, DateTime? StartsAt, DateTime? EndsAt);
public sealed record VoucherRequest([property: Required, StringLength(30)] string Code, [property: Range(1, int.MaxValue)] int PromotionId, int? CustomerId, [property: Range(0, 1000000000)] decimal DiscountValue, DateTime ExpiresAt);
public sealed record ReviewRequest([property: Range(1, 5)] byte Stars, [property: StringLength(1000)] string? Comment);
public sealed record RolePermissionRequest([property: Range(1, int.MaxValue)] int PermissionId, bool Granted);

