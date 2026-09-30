using System.ComponentModel.DataAnnotations;

namespace HealthBeauty.Api.Contracts;

public sealed record UpdateCustomerRequest([param: Required, StringLength(100)] string FullName, [param: Phone, StringLength(15)] string? Phone, [param: StringLength(20)] string? Gender);
public sealed record CustomerResponse(int Id, string FullName, string? Phone, string? Gender, int RewardPoints);
public sealed record StaffRequest([param: Required, StringLength(100)] string FullName, [param: StringLength(50)] string? Position, [param: StringLength(255)] string? Specialty, [param: Phone, StringLength(15)] string? Phone, DateOnly? HireDate);
public sealed record WorkScheduleRequest([param: Range(1, int.MaxValue)] int StaffId, DateOnly WorkDate, TimeOnly StartAt, TimeOnly EndAt, [param: StringLength(30)] string? Status);
public sealed record ComboItemRequest([param: Range(1, int.MaxValue)] int ServiceId, [param: Range(1, 100)] int Quantity);
public sealed record ComboRequest([param: Required, StringLength(150)] string Name, [param: Range(0, 1000000000)] decimal Price, DateOnly? ValidFrom, DateOnly? ValidTo, [param: MinLength(1)] List<ComboItemRequest> Items);
public sealed record ComboItemResponse(int ServiceId, string ServiceName, int Quantity);
public sealed record ComboResponse(int Id, string Name, decimal Price, DateOnly? ValidFrom, DateOnly? ValidTo, bool Active, IReadOnlyList<ComboItemResponse> Items);
public sealed record InvoiceLineRequest(int? ServiceId, int? ComboId, [param: Range(1, 100)] int Quantity);
public sealed record CreateInvoiceRequest([param: Range(1, int.MaxValue)] int AppointmentId, [param: MinLength(1)] List<InvoiceLineRequest> Items, string? VoucherCode, [param: Range(0, 1000000)] int PointsToRedeem = 0);
public sealed record PaymentRequest([param: Required, StringLength(30)] string Method, [param: Required] string Status = "ThanhCong");
public sealed record InvoiceLineResponse(int Id, int? ServiceId, string? ServiceName, int? ComboId, string? ComboName, int Quantity, decimal UnitPrice);
public sealed record PaymentResponse(int Id, string Method, decimal Amount, DateTime? PaidAt, string Status);
public sealed record InvoiceResponse(int Id, int AppointmentId, int CustomerId, DateTime CreatedAt, decimal Subtotal, decimal Total, string Status, IReadOnlyList<InvoiceLineResponse> Items, IReadOnlyList<PaymentResponse> Payments);
public sealed record PromotionRequest([param: Required, StringLength(150)] string Name, [param: Required, StringLength(30)] string DiscountType, [param: Range(0, 1000000000)] decimal Discount, [param: StringLength(1000)] string? Condition, DateTime? StartsAt, DateTime? EndsAt);
public sealed record VoucherRequest([param: Required, StringLength(30)] string Code, [param: Range(1, int.MaxValue)] int PromotionId, int? CustomerId, [param: Range(0, 1000000000)] decimal DiscountValue, DateTime ExpiresAt);
public sealed record ReviewRequest([param: Range(1, 5)] byte Stars, [param: StringLength(1000)] string? Comment);
public sealed record RolePermissionRequest([param: Range(1, int.MaxValue)] int PermissionId, bool Granted);
