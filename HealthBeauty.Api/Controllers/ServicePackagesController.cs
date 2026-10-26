using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace HealthBeauty.Api.Controllers;
[ApiController, Authorize, Route("api/v1/service-packages")]
public sealed class ServicePackagesController(Klcn021HealthBeautyContext db) : ControllerBase
{
    private bool Management => User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
    [AllowAnonymous, HttpGet]
    public async Task<IActionResult> List(CancellationToken ct, [FromQuery] bool includeInactive = false)
    {
        if (includeInactive) return BadRequest("Use the management catalog endpoint for inactive packages.");
        return Ok(await db.ServicePackages.AsNoTracking().Include(x => x.Items).Where(x => x.Active || includeInactive).OrderBy(x => x.Id).ToListAsync(ct));
    }
    [AllowAnonymous, HttpGet("{id:int}")]
    public async Task<IActionResult> CatalogDetail(int id, CancellationToken ct)
    {
        var package = await db.ServicePackages.AsNoTracking().Include(x => x.Items).SingleOrDefaultAsync(x => x.Id == id && x.Active, ct);
        return package is null ? NotFound() : Ok(package);
    }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("management")] public async Task<IActionResult> ManagementList(CancellationToken ct) => Ok(await db.ServicePackages.AsNoTracking().Include(x => x.Items).OrderBy(x => x.Id).ToListAsync(ct));
    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost]
    public async Task<IActionResult> Create(ServicePackageRequest request, CancellationToken ct)
    {
        var error = await Validate(request, ct);
        if (error != null) return BadRequest(error);
        var p = new ServicePackage();
        Apply(p, request);
        db.ServicePackages.Add(p);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/service-packages/{p.Id}", p);
    }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, ServicePackageRequest request, CancellationToken ct)
    {
        var error = await Validate(request, ct);
        if (error != null) return BadRequest(error);
        var p = await db.ServicePackages.Include(x => x.Items).SingleOrDefaultAsync(x => x.Id == id, ct);
        if (p == null) return NotFound();
        Apply(p, request);
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Package changed. Reload before editing.");
        return Ok(p);
    }
    private async Task<string?> Validate(ServicePackageRequest r, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Length > 200 || r.Price < 0.01m || decimal.Round(r.Price, 2) != r.Price || r.Price > 1000000000 || r.ValidityDays < 1 || r.ValidityDays > 3650 || r.Items is null || r.Items.Count < 1 || r.Items.Count > 100 || r.Items.Any(x => x.Sessions < 1 || x.Sessions > 10000) || r.Items.Select(x => x.ServiceId).Distinct().Count() != r.Items.Count) return "Invalid package name, price, validity or session quantities.";
        if (r.ImageUrl != null && !CatalogImageUrl.IsValid(r.ImageUrl)) return "Invalid image URL.";
        var ids = r.Items.Select(x => x.ServiceId).ToList();
        return await db.Dichvus.CountAsync(x => ids.Contains(x.DichVuId) && (!r.Active || x.TrangThai), ct) == ids.Count ? null : "Services must exist and be active.";
    }
    private static void Apply(ServicePackage p, ServicePackageRequest r)
    {
        p.Version = Guid.NewGuid();
        p.Name = r.Name.Trim();
        p.Price = r.Price;
        p.ValidityDays = r.ValidityDays;
        p.Active = r.Active;
        if (r.ImageUrl != null) p.ImageUrl = CatalogImageUrl.Normalize(r.ImageUrl);
        foreach (var old in p.Items.Where(x => !r.Items.Any(i => i.ServiceId == x.ServiceId)).ToList()) p.Items.Remove(old);
        foreach (var i in r.Items)
        {
            var existing = p.Items.SingleOrDefault(x => x.ServiceId == i.ServiceId);
            if (existing != null) existing.Sessions = i.Sessions;
            else p.Items.Add(new ServicePackageItem
            {
                ServiceId = i.ServiceId,
                Sessions = i.Sessions
            }
            );
        }
    }
    [HttpPost("purchases")]
    public async Task<IActionResult> Purchase(PackagePurchaseRequest r, CancellationToken ct)
    {
        var own = await OwnCustomer(ct);
        if (!Management && (!own.HasValue || r.CustomerId.HasValue && r.CustomerId != own)) return Forbid();
        var customer = Management ? r.CustomerId : own;
        if (!customer.HasValue || !await db.Khachhangs.AnyAsync(x => x.KhachHangId == customer, ct)) return BadRequest("Valid customer is required.");
        var p = await db.ServicePackages.AsNoTracking().Include(x => x.Items).SingleOrDefaultAsync(x => x.Id == r.PackageId && x.Active, ct);
        if (p == null) return NotFound();
        var ids = p.Items.Select(x => x.ServiceId).ToList();
        var names = await db.Dichvus.Where(x => ids.Contains(x.DichVuId) && x.TrangThai).ToDictionaryAsync(x => x.DichVuId, x => x.TenDichVu, ct);
        if (names.Count != ids.Count) return BadRequest("Package contains inactive services.");
        var purchase = new CustomerPackage
        {
            ServicePackageId = p.Id,
            CustomerId = customer.Value,
            Name = p.Name,
            Price = p.Price,
            ValidityDays = p.ValidityDays,
            CreatedAt = DateTime.Now,
            Items = p.Items.Select(x => new CustomerPackageItem
            {
                ServiceId = x.ServiceId,
                ServiceName = names[x.ServiceId],
                Granted = x.Sessions
            }
        ).ToList()
        }
        ;
        db.CustomerPackages.Add(purchase);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/service-packages/purchases/{purchase.Id}", View(purchase));
    }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost("purchases/{id:int}/pay")]
    public async Task<IActionResult> Pay(int id, PackagePaymentRequest r, CancellationToken ct)
    {
        if (r.Method is not ("TienMat" or "ChuyenKhoan" or "The")) return BadRequest("Method must be TienMat, ChuyenKhoan or The.");
        var p = await db.CustomerPackages.Include(x => x.Items).SingleOrDefaultAsync(x => x.Id == id, ct);
        if (p == null) return NotFound();
        if (p.Status != "Pending") return Conflict("Purchase is already paid or cancelled.");
        var error = await PackageSettlement.StageAsync(db, new NotificationService(db), p, r.Method, DateTime.Now,
            int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!), ct);
        if (error is not null) return Conflict(error);
        if (!await NotificationPersistence.TrySaveAsync(db, ct)) return Conflict("Purchase or customer reward balance changed. Reload.");
        return Ok(View(p));
    }
    [HttpGet("mine")]
    public async Task<IActionResult> Mine(CancellationToken ct)
    {
        var own = await OwnCustomer(ct);
        if (!own.HasValue) return Forbid();
        return Ok((await db.CustomerPackages.AsNoTracking().Include(x => x.Items).Where(x => x.CustomerId == own).OrderByDescending(x => x.Id).ToListAsync(ct)).Select(View));
    }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("customers/{customerId:int}")] public async Task<IActionResult> Customer(int customerId, CancellationToken ct) => Ok((await db.CustomerPackages.AsNoTracking().Include(x => x.Items).Where(x => x.CustomerId == customerId).OrderByDescending(x => x.Id).ToListAsync(ct)).Select(View));
    [HttpGet("purchases/{id:int}")]
    public async Task<IActionResult> Detail(int id, CancellationToken ct)
    {
        var p = await db.CustomerPackages.AsNoTracking().Include(x => x.Items).SingleOrDefaultAsync(x => x.Id == id, ct);
        if (p == null) return NotFound();
        if (!Management && p.CustomerId != await OwnCustomer(ct)) return Forbid();
        var ids = p.Items.Select(x => x.Id).ToList();
        var history = await db.PackageUsages.AsNoTracking().Where(x => ids.Contains(x.CustomerPackageItemId)).OrderByDescending(x => x.Id).Select(x => new
        {
            x.Id,
            x.CustomerPackageItemId,
            x.AppointmentId,
            x.Quantity,
            x.Status,
            x.CreatedAt,
            x.SettledAt
        }
        ).ToListAsync(ct);
        return Ok(new
        {
            package = View(p),
            history
        }
        );
    }
    [HttpDelete("purchases/{id:int}")]
    public async Task<IActionResult> CancelPurchase(int id, CancellationToken ct)
    {
        var p = await db.CustomerPackages.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (p == null) return NotFound();
        if (!Management && p.CustomerId != await OwnCustomer(ct)) return Forbid();
        if (p.Status != "Pending") return Conflict("Only pending purchases may be cancelled; paid packages are not refundable here.");
        p.Version = Guid.NewGuid();
        p.Status = "Cancelled";
        return await NotificationPersistence.TrySaveAsync(db, ct) ? NoContent() : Conflict("Purchase changed.");
    }
    [Authorize(Roles = "Admin,Manager,Reception"), HttpGet("sales")]
    public async Task<IActionResult> Sales([FromQuery] DateTime from, [FromQuery] DateTime to, CancellationToken ct)
    {
        if (from == default || to <= from || (to - from).TotalDays > 366) return BadRequest("Choose an exclusive date range of at most 366 days.");
        var query = db.CustomerPackages.AsNoTracking().Where(x => x.Status == "Paid" && x.PaidAt >= from && x.PaidAt < to);
        if (await query.CountAsync(ct) > 10000) return BadRequest("Narrow the date range to at most 10000 paid package purchases.");
        var rows = await query.OrderBy(x => x.PaidAt).Select(x => new
        {
            x.Id,
            x.CustomerId,
            x.Name,
            x.Price,
            x.PaidAt,
            x.PaymentMethod
        }
        ).ToListAsync(ct);
        return Ok(new
        {
            from,
            to,
            count = rows.Count,
            revenue = rows.Sum(x => x.Price),
            items = rows
        }
        );
    }
    private async Task<int?> OwnCustomer(CancellationToken ct)
    {
        var id = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        return await db.Khachhangs.Where(x => x.TaiKhoanId == id).Select(x => (int?)x.KhachHangId).SingleOrDefaultAsync(ct);
    }
    private static object View(CustomerPackage p) => new
    {
        p.Id,
        p.ServicePackageId,
        p.CustomerId,
        p.Name,
        p.Price,
        p.ValidityDays,
        p.Status,
        p.CreatedAt,
        p.PaidAt,
        p.ExpiresAt,
        p.PaymentMethod,
        items = p.Items.Select(x => new
        {
            x.Id,
            x.ServiceId,
            x.ServiceName,
            x.Granted,
            x.Reserved,
            x.Used,
            remaining = x.Granted - x.Used,
            available = p.Status == "Paid" && p.ExpiresAt >= DateTime.Now ? x.Granted - x.Used - x.Reserved : 0
        }
    )
    }
    ;
}
