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
        return Ok(await query.OrderBy(x => x.TenDichVu).Select(x => new ServiceResponse(x.DichVuId, x.LoaiDichVuId, x.TenDichVu, x.Gia, x.ThoiLuongPhut, x.MoTa)).ToListAsync(cancellationToken));
    }

    [AllowAnonymous, HttpGet("services/{id:int}")]
    public async Task<ActionResult<ServiceResponse>> GetService(int id, CancellationToken cancellationToken)
    {
        var item = await db.Dichvus.AsNoTracking().Where(x => x.DichVuId == id && x.TrangThai).Select(x => new ServiceResponse(x.DichVuId, x.LoaiDichVuId, x.TenDichVu, x.Gia, x.ThoiLuongPhut, x.MoTa)).FirstOrDefaultAsync(cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    [Authorize(Roles = "Admin,Manager"), HttpPost("services")]
    public async Task<ActionResult<ServiceResponse>> CreateService(CreateServiceRequest request, CancellationToken cancellationToken)
    {
        if (!await db.Loaidichvus.AnyAsync(x => x.LoaiDichVuId == request.CategoryId && x.TrangThai, cancellationToken)) return BadRequest("Loại dịch vụ không tồn tại.");
        var item = new Dichvu { LoaiDichVuId = request.CategoryId, TenDichVu = request.Name.Trim(), Gia = request.Price, ThoiLuongPhut = request.DurationMinutes, MoTa = request.Description?.Trim(), TrangThai = true };
        db.Dichvus.Add(item); await db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetService), new { id = item.DichVuId }, new ServiceResponse(item.DichVuId, item.LoaiDichVuId, item.TenDichVu, item.Gia, item.ThoiLuongPhut, item.MoTa));
    }

    [Authorize(Roles = "Admin,Manager"), HttpPost("service-categories")]
    public async Task<ActionResult<ServiceCategoryResponse>> CreateCategory(CreateCategoryRequest request, CancellationToken cancellationToken)
    {
        var item = new Loaidichvu { TenLoai = request.Name.Trim(), MoTa = request.Description?.Trim(), TrangThai = true };
        db.Loaidichvus.Add(item); await db.SaveChangesAsync(cancellationToken);
        return Ok(new ServiceCategoryResponse(item.LoaiDichVuId, item.TenLoai, item.MoTa));
    }
}
