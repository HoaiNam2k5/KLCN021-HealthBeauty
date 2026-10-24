using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/customers/me/avatar"), Authorize(Roles = "Customer")]
[EnableRateLimiting(MobileAuthenticationRateLimiting.AvatarPolicy)]
public sealed class CustomerAvatarController(Klcn021HealthBeautyContext db, ICloudinaryImageStorage storage) : ControllerBase
{
    private static CustomerResponse View(Khachhang customer) => new(customer.KhachHangId, customer.HoTen,
        customer.SoDienThoai, customer.GioiTinh, customer.DiemThuong, customer.AvatarUrl);

    [HttpPost, Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 6 * 1024 * 1024, MemoryBufferThreshold = 6 * 1024 * 1024)]
    public async Task<ActionResult<CustomerResponse>> Upload([FromForm] UploadImageRequest request, CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var accountId)) return Unauthorized();
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null) return NotFound();
        var image = await ImageUploadValidation.ReadAsync(request.File, ct);
        if (image.Error is not null) return image.StatusCode == 400 ? BadRequest(image.Error) : StatusCode(image.StatusCode, image.Error);
        if (!storage.IsConfigured) return StatusCode(503, "Image upload is not configured.");
        UploadImageResponse uploaded;
        try { uploaded = await storage.UploadAsync(image.Bytes!, image.ContentType!, ct); }
        catch (TimeoutException) { return StatusCode(504, "Image storage timed out. Please retry."); }
        catch (ImageStorageException) { return StatusCode(502, "Image storage is unavailable. Please retry."); }
        if (string.IsNullOrWhiteSpace(uploaded.ImageUrl) || !CatalogImageUrl.IsValid(uploaded.ImageUrl))
            return StatusCode(502, "Image storage returned an invalid image URL.");
        customer.AvatarUrl = uploaded.ImageUrl;
        AddAudit(accountId, customer, "CustomerAvatarUpdated");
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Customer profile changed. Please reload and retry.");
        return Ok(View(customer));
    }

    [HttpDelete]
    public async Task<ActionResult<CustomerResponse>> Delete(CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var accountId)) return Unauthorized();
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null) return NotFound();
        customer.AvatarUrl = null;
        AddAudit(accountId, customer, "CustomerAvatarRemoved");
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Customer profile changed. Please reload and retry.");
        // Never delete a cloud asset from a supplied/shared URL.
        return Ok(View(customer));
    }

    private void AddAudit(int accountId, Khachhang customer, string action) => db.Auditlogs.Add(new Auditlog
    {
        TaiKhoanId = accountId, ActionName = action, EntityName = "KHACHHANG", EntityId = customer.KhachHangId.ToString(),
        CreatedAt = DateTime.UtcNow, IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
        NewValues = JsonSerializer.Serialize(new { customer.AvatarUrl })
    });
}
