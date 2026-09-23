using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/appointments")]
public sealed class AppointmentsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<AppointmentResponse>>> GetMine(CancellationToken cancellationToken)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(cancellationToken);
        if (customerId is null && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Ok(Array.Empty<AppointmentResponse>());
        var query = db.Lichhens.AsNoTracking().Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu).AsQueryable();
        if (customerId is not null) query = query.Where(x => x.KhachHangId == customerId.Value);
        var list = await query.OrderByDescending(x => x.NgayGioHen).Take(100).ToListAsync(cancellationToken);
        return Ok(list.Select(Map));
    }

    [HttpPost]
    public async Task<ActionResult<AppointmentResponse>> Create(CreateAppointmentRequest request, CancellationToken cancellationToken)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(cancellationToken);
        if (customerId is null) return BadRequest("Tài khoản chưa có hồ sơ khách hàng.");
        if (request.AppointmentAt <= DateTime.Now) return BadRequest("Thời gian hẹn phải ở tương lai.");
        var serviceIds = request.Items.Select(x => x.ServiceId).Distinct().ToList();
        var services = await db.Dichvus.Where(x => serviceIds.Contains(x.DichVuId) && x.TrangThai).ToDictionaryAsync(x => x.DichVuId, cancellationToken);
        if (services.Count != serviceIds.Count) return BadRequest("Một hoặc nhiều dịch vụ không hợp lệ.");
        var conflict = await db.Lichhens.AnyAsync(x => x.NhanVienId == null && x.KhachHangId == customerId && x.NgayGioHen == request.AppointmentAt && x.TrangThai != "DaHuy", cancellationToken);
        if (conflict) return Conflict("Khách hàng đã có lịch hẹn cùng thời điểm.");
        var appointment = new Lichhen { KhachHangId = customerId.Value, NgayGioHen = request.AppointmentAt, TrangThai = "ChoXacNhan", GhiChu = request.Note?.Trim() };
        foreach (var item in request.Items) appointment.Chitietlichhens.Add(new Chitietlichhen { DichVuId = item.ServiceId, ComboId = item.ComboId, GiaDuKien = item.ExpectedPrice > 0 ? item.ExpectedPrice : services[item.ServiceId].Gia, ThoiLuongThucTe = services[item.ServiceId].ThoiLuongPhut });
        db.Lichhens.Add(appointment); await db.SaveChangesAsync(cancellationToken);
        await db.Entry(appointment).Collection(x => x.Chitietlichhens).Query().Include(x => x.DichVu).LoadAsync(cancellationToken);
        return CreatedAtAction(nameof(GetMine), new { id = appointment.LichHenId }, Map(appointment));
    }

    private static AppointmentResponse Map(Lichhen item) => new(item.LichHenId, item.KhachHangId, item.NhanVienId, item.NgayGioHen, item.TrangThai, item.GhiChu, item.Chitietlichhens.Select(x => new AppointmentItemResponse(x.ChiTietLichHenId, x.DichVuId, x.DichVu.TenDichVu, x.ComboId, x.GiaDuKien)).ToList());
}
