using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1")]
public sealed class ServicesController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [AllowAnonymous, HttpGet("service-categories")]
    public async Task<ActionResult<IEnumerable<ServiceCategoryResponse>>> Categories(CancellationToken cancellationToken) =>
        Ok(await db.Loaidichvus.AsNoTracking().Where(x => x.TrangThai).OrderBy(x => x.TenLoai).Select(x => new ServiceCategoryResponse(x.LoaiDichVuId, x.TenLoai, x.MoTa)).ToListAsync(cancellationToken));

    [AllowAnonymous, HttpGet("services")]
    public async Task<ActionResult<IEnumerable<ServiceResponse>>> Services([FromQuery] int? categoryId, [FromQuery] string? keyword, CancellationToken cancellationToken)
    {
        var query = db.Dichvus.AsNoTracking().Where(x => x.TrangThai);
        if (categoryId.HasValue) query = query.Where(x => x.LoaiDichVuId == categoryId.Value);
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.TenDichVu.Contains(keyword));
        return Ok(await WithStatistics(query.OrderBy(x => x.TenDichVu), cancellationToken));
    }

    [AllowAnonymous, HttpGet("services/{id:int}")]
    public async Task<ActionResult<ServiceResponse>> GetService(int id, CancellationToken cancellationToken)
    {
        var item = (await WithStatistics(db.Dichvus.AsNoTracking().Where(x => x.DichVuId == id && x.TrangThai), cancellationToken)).SingleOrDefault();
        return item is null ? NotFound() : Ok(item);
    }


    private sealed record ReviewAggregate(int ServiceId, int Total, double Average);
    private sealed record BookingAggregate(int ServiceId, int Total);

    private async Task<List<ServiceResponse>> WithStatistics(IQueryable<Dichvu> query, CancellationToken ct)
    {
        var items = await query.Select(x => new ServiceResponse(x.DichVuId, x.LoaiDichVuId,
            x.TenDichVu, x.Gia, x.ThoiLuongPhut, x.MoTa, x.ImageUrl, 0, 0, 0)).ToListAsync(ct);
        if (items.Count == 0) return items;
        var ids = items.Select(x => x.Id).ToArray();
        var reviews = await ReviewStatistics(ids).ToDictionaryAsync(x => x.ServiceId, ct);
        var bookings = await BookingStatistics(ids).ToDictionaryAsync(x => x.ServiceId, ct);
        // Three queries total for any catalog size: services, review aggregates,
        // booking aggregates. No per-service database round trips.
        return items.Select(item => item with
        {
            AverageRating = reviews.TryGetValue(item.Id, out var review)
                ? Math.Round(review.Average, 1, MidpointRounding.AwayFromZero) : 0,
            TotalReviews = reviews.GetValueOrDefault(item.Id)?.Total ?? 0,
            BookedCount = bookings.GetValueOrDefault(item.Id)?.Total ?? 0
        }).ToList();
    }


    private IQueryable<ReviewAggregate> ReviewStatistics(int[] ids)
    {
        var visible = db.Danhgia.AsNoTracking().Where(x => x.TrangThai == "HienThi" && !x.IsDeleted);
        var directReviews = from review in visible
            join line in db.Chitiethoadons.AsNoTracking() on review.HoaDonId equals line.HoaDonId
            where line.DichVuId.HasValue && ids.Contains(line.DichVuId.Value)
            select new { ServiceId = line.DichVuId.GetValueOrDefault(), ReviewId = review.DanhGiaId, Stars = (double)review.SoSao };
        var comboReviews = from review in visible
            join line in db.Chitiethoadons.AsNoTracking() on review.HoaDonId equals line.HoaDonId
            join component in db.Chitietcombos.AsNoTracking() on line.ComboId equals (int?)component.ComboId
            where ids.Contains(component.DichVuId)
            select new { ServiceId = component.DichVuId, ReviewId = review.DanhGiaId, Stars = (double)review.SoSao };
        // UNION removes a review reached via duplicate invoice lines or both a
        // direct service and its combo. Visibility matches GET /reviews.
        return directReviews.Union(comboReviews).GroupBy(x => x.ServiceId)
            .Select(g => new ReviewAggregate(g.Key, g.Count(), g.Average(x => x.Stars)));
    }

    private IQueryable<BookingAggregate> BookingStatistics(int[] ids)
    {
        var directBookings = from line in db.Chitietlichhens.AsNoTracking()
            where ids.Contains(line.DichVuId) && line.LichHen.TrangThai != "DaHuy"
            select new { ServiceId = line.DichVuId, AppointmentId = line.LichHenId };
        var comboBookings = from line in db.Chitietlichhens.AsNoTracking()
            join component in db.Chitietcombos.AsNoTracking() on line.ComboId equals (int?)component.ComboId
            where ids.Contains(component.DichVuId) && line.LichHen.TrangThai != "DaHuy"
            select new { ServiceId = component.DichVuId, AppointmentId = line.LichHenId };
        // A booking is one non-cancelled appointment, not service quantity.
        return directBookings.Union(comboBookings).GroupBy(x => x.ServiceId)
            .Select(g => new BookingAggregate(g.Key, g.Count()));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost("services")]
    public async Task<ActionResult<ServiceResponse>> CreateService(CreateServiceRequest request, CancellationToken cancellationToken)
    {
        if (!CatalogImageUrl.IsValid(request.ImageUrl)) return BadRequest("ImageUrl must be an HTTP/HTTPS URL without credentials, up to 2048 characters.");
        if (!await db.Loaidichvus.AnyAsync(x => x.LoaiDichVuId == request.CategoryId && x.TrangThai, cancellationToken)) return BadRequest("Loại dịch vụ không tồn tại.");
        var item = new Dichvu { LoaiDichVuId = request.CategoryId, TenDichVu = request.Name.Trim(), Gia = request.Price, ThoiLuongPhut = request.DurationMinutes, MoTa = request.Description?.Trim(), ImageUrl = CatalogImageUrl.Normalize(request.ImageUrl), TrangThai = true };
        db.Dichvus.Add(item); await db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetService), new { id = item.DichVuId }, new ServiceResponse(item.DichVuId, item.LoaiDichVuId, item.TenDichVu, item.Gia, item.ThoiLuongPhut, item.MoTa, item.ImageUrl));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("services/{id:int}")]
    public async Task<IActionResult> UpdateService(int id, CreateServiceRequest request, CancellationToken ct)
    {
        var item = await db.Dichvus.FindAsync([id], ct); if (item is null) return NotFound();
        if (!CatalogImageUrl.IsValid(request.ImageUrl)) return BadRequest("ImageUrl must be an HTTP/HTTPS URL without credentials, up to 2048 characters.");
        if (!await db.Loaidichvus.AnyAsync(x => x.LoaiDichVuId == request.CategoryId && x.TrangThai, ct)) return BadRequest("Loại dịch vụ không tồn tại.");
        if (request.ImageUrl is not null) item.ImageUrl = CatalogImageUrl.Normalize(request.ImageUrl);
        item.LoaiDichVuId=request.CategoryId; item.TenDichVu=request.Name.Trim(); item.Gia=request.Price; item.ThoiLuongPhut=request.DurationMinutes; item.MoTa=request.Description?.Trim(); await db.SaveChangesAsync(ct); return Ok(new ServiceResponse(item.DichVuId,item.LoaiDichVuId,item.TenDichVu,item.Gia,item.ThoiLuongPhut,item.MoTa,item.ImageUrl));
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpDelete("services/{id:int}")]
    public async Task<IActionResult> DeactivateService(int id, CancellationToken ct) { var item=await db.Dichvus.FindAsync([id],ct); if(item is null)return NotFound(); item.TrangThai=false; await db.SaveChangesAsync(ct); return NoContent(); }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("service-categories/{id:int}")]
    public async Task<IActionResult> UpdateCategory(int id, CreateCategoryRequest request, CancellationToken ct) { var item=await db.Loaidichvus.FindAsync([id],ct); if(item is null)return NotFound(); item.TenLoai=request.Name.Trim(); item.MoTa=request.Description?.Trim(); await db.SaveChangesAsync(ct); return Ok(new ServiceCategoryResponse(item.LoaiDichVuId,item.TenLoai,item.MoTa)); }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpDelete("service-categories/{id:int}")]
    public async Task<IActionResult> DeactivateCategory(int id, CancellationToken ct) { var item=await db.Loaidichvus.FindAsync([id],ct); if(item is null)return NotFound(); item.TrangThai=false; await db.SaveChangesAsync(ct); return NoContent(); }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost("service-categories")]
    public async Task<ActionResult<ServiceCategoryResponse>> CreateCategory(CreateCategoryRequest request, CancellationToken cancellationToken)
    {
        var item = new Loaidichvu { TenLoai = request.Name.Trim(), MoTa = request.Description?.Trim(), TrangThai = true };
        db.Loaidichvus.Add(item); await db.SaveChangesAsync(cancellationToken);
        return Ok(new ServiceCategoryResponse(item.LoaiDichVuId, item.TenLoai, item.MoTa));
    }
}
