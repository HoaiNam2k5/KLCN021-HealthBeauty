using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Route("api/v1/combos")]
public sealed class CombosController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [AllowAnonymous, HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await db.Combodichvus.AsNoTracking().Where(x => x.TrangThai)
        .Include(x => x.Chitietcombos).ThenInclude(x => x.DichVu).OrderBy(x => x.TenCombo).Select(x => Map(x)).ToListAsync(ct));

    [AllowAnonymous, HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct)
    {
        var item = await db.Combodichvus.AsNoTracking().Include(x => x.Chitietcombos).ThenInclude(x => x.DichVu).FirstOrDefaultAsync(x => x.ComboId == id && x.TrangThai, ct);
        return item is null ? NotFound() : Ok(Map(item));
    }

    [Authorize(Roles = "Admin,Manager"), HttpPost]
    public async Task<IActionResult> Create(ComboRequest request, CancellationToken ct)
    {
        if (request.ValidFrom.HasValue && request.ValidTo.HasValue && request.ValidTo < request.ValidFrom) return BadRequest("Ngày kết thúc phải sau ngày bắt đầu.");
        var ids = request.Items.Select(x => x.ServiceId).Distinct().ToList();
        var services = await db.Dichvus.Where(x => ids.Contains(x.DichVuId) && x.TrangThai).Select(x => x.DichVuId).ToListAsync(ct);
        if (ids.Count != services.Count) return BadRequest("Có dịch vụ không tồn tại hoặc đã ngừng hoạt động.");
        var item = new Combodichvu { TenCombo = request.Name.Trim(), GiaCombo = request.Price, NgayBatDauHieuLuc = request.ValidFrom, NgayKetThucHieuLuc = request.ValidTo, TrangThai = true };
        foreach (var line in request.Items) item.Chitietcombos.Add(new Chitietcombo { DichVuId = line.ServiceId, SoLuong = line.Quantity });
        db.Combodichvus.Add(item); await db.SaveChangesAsync(ct);
        await db.Entry(item).Collection(x => x.Chitietcombos).Query().Include(x => x.DichVu).LoadAsync(ct);
        return CreatedAtAction(nameof(Get), new { id = item.ComboId }, Map(item));
    }

    [Authorize(Roles = "Admin,Manager"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, ComboRequest request, CancellationToken ct)
    {
        var item = await db.Combodichvus.Include(x => x.Chitietcombos).FirstOrDefaultAsync(x => x.ComboId == id, ct); if (item is null) return NotFound();
        if (request.ValidFrom.HasValue && request.ValidTo.HasValue && request.ValidTo < request.ValidFrom) return BadRequest("Ngày kết thúc phải sau ngày bắt đầu.");
        var ids = request.Items.Select(x => x.ServiceId).Distinct().ToList();
        if (ids.Count != await db.Dichvus.CountAsync(x => ids.Contains(x.DichVuId) && x.TrangThai, ct)) return BadRequest("Có dịch vụ không tồn tại hoặc đã ngừng hoạt động.");
        item.TenCombo = request.Name.Trim(); item.GiaCombo = request.Price; item.NgayBatDauHieuLuc = request.ValidFrom; item.NgayKetThucHieuLuc = request.ValidTo;
        db.Chitietcombos.RemoveRange(item.Chitietcombos);
        foreach (var line in request.Items) item.Chitietcombos.Add(new Chitietcombo { DichVuId = line.ServiceId, SoLuong = line.Quantity });
        await db.SaveChangesAsync(ct);
        var updated = await db.Combodichvus.AsNoTracking().Include(x => x.Chitietcombos).ThenInclude(x => x.DichVu).FirstAsync(x => x.ComboId == id, ct);
        return Ok(Map(updated));
    }

    [Authorize(Roles = "Admin,Manager"), HttpDelete("{id:int}")]
    public async Task<IActionResult> Deactivate(int id, CancellationToken ct)
    {
        var item = await db.Combodichvus.FindAsync([id], ct); if (item is null) return NotFound(); item.TrangThai = false; await db.SaveChangesAsync(ct); return NoContent();
    }

    private static ComboResponse Map(Combodichvu x) => new(x.ComboId, x.TenCombo, x.GiaCombo, x.NgayBatDauHieuLuc, x.NgayKetThucHieuLuc, x.TrangThai,
        x.Chitietcombos.Select(c => new ComboItemResponse(c.DichVuId, c.DichVu.TenDichVu, c.SoLuong)).ToList());
}

