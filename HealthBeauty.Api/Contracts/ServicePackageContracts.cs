using System.ComponentModel.DataAnnotations;
namespace HealthBeauty.Api.Contracts;
public sealed record ServicePackageItemRequest([param: Range(1, int.MaxValue)] int ServiceId, [param: Range(1, 10000)] int Sessions);
public sealed record ServicePackageRequest([param: Required, StringLength(200)] string Name, [param: Range(typeof(decimal), "0.01", "1000000000")] decimal Price, [param: Range(1, 3650)] int ValidityDays, [param: Required, MinLength(1), MaxLength(100)] List<ServicePackageItemRequest> Items, bool Active = true, string? ImageUrl = null);
public sealed record PackagePurchaseRequest([param: Range(1, int.MaxValue)] int PackageId, int? CustomerId = null);
public sealed record PackagePaymentRequest([param: Required, StringLength(30)] string Method);
