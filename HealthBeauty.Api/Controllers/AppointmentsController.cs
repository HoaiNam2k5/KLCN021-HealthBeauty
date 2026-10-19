using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/appointments")]
public sealed class AppointmentsController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMine([FromQuery] DateTime? from, [FromQuery] DateTime? to, [FromQuery] string? status, [FromQuery] int? staffId, [FromQuery] string? keyword, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default)
    {
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 100);
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(cancellationToken);
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        var query = db.Lichhens.AsNoTracking().Include(x => x.Chitietlichhens).ThenInclude(x => x.DichVu).Include(x => x.KhachHang).Include(x => x.Hoadons).ThenInclude(x => x.Danhgia).AsSplitQuery().AsQueryable();
        if (!isStaff && User.IsInRole("Staff"))
        {
            var ownStaffId = await db.Nhanviens.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.NhanVienId).FirstOrDefaultAsync(cancellationToken);
            if (!ownStaffId.HasValue) return Forbid();
            query = query.Where(x => x.NhanVienId == ownStaffId.Value);
        }
        else if (!isStaff)
        {
            if (!customerId.HasValue) return Forbid();
            query = query.Where(x => x.KhachHangId == customerId.Value);
        }
        if (from.HasValue) query = query.Where(x => x.NgayGioHen >= from.Value);
        if (to.HasValue) query = query.Where(x => x.NgayGioHen < to.Value);
        if (!string.IsNullOrWhiteSpace(status)) query = query.Where(x => x.TrangThai == status);
        if (staffId.HasValue) query = query.Where(x => x.NhanVienId == staffId.Value);
        if (!string.IsNullOrWhiteSpace(keyword)) query = query.Where(x => x.KhachHang.HoTen.Contains(keyword) || (x.KhachHang.SoDienThoai != null && x.KhachHang.SoDienThoai.Contains(keyword)));
        var totalCount = await query.CountAsync(cancellationToken);
        var list = await query.OrderByDescending(x => x.NgayGioHen).ThenByDescending(x => x.LichHenId).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return Ok(new { items = list.Select(Map), totalCount, page, pageSize });
    }

    [HttpPost]
    public async Task<ActionResult<AppointmentResponse>> Create(CreateAppointmentRequest request, CancellationToken cancellationToken)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var ownCustomerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(cancellationToken);
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        if (isStaff && request.CustomerId is null) return BadRequest("CustomerId is required for staff-created appointments.");
        var customerId = request.CustomerId ?? ownCustomerId;
        if (customerId is null) return BadRequest("Customer profile is required.");
        if (!isStaff && request.CustomerId.HasValue && request.CustomerId != ownCustomerId) return Forbid();
        if (!await db.Khachhangs.AnyAsync(x => x.KhachHangId == customerId.Value, cancellationToken)) return BadRequest("Customer does not exist.");
        if (request.StaffId.HasValue && !await db.Nhanviens.AnyAsync(x => x.NhanVienId == request.StaffId.Value, cancellationToken)) return BadRequest("Staff does not exist.");
        if (request.AppointmentAt <= DateTime.Now) return BadRequest("Appointment time must be in the future.");
        if (request.Items is null || request.Items.Count == 0) return BadRequest("At least one service is required.");
        if (request.CustomerPackageId.HasValue && request.Items.Any(x => x.ComboId.HasValue)) return BadRequest("Package sessions cannot be combined with combos or cash-funded services.");
        var serviceIds = request.Items.Select(x => x.ServiceId).Distinct().ToList();
        var services = await db.Dichvus.Where(x => serviceIds.Contains(x.DichVuId) && x.TrangThai).ToDictionaryAsync(x => x.DichVuId, cancellationToken);
        if (services.Count != serviceIds.Count) return BadRequest("One or more services are invalid.");
        var comboIds = request.Items.Where(x => x.ComboId.HasValue).Select(x => x.ComboId!.Value).Distinct().ToList();
        var bookingDate = DateOnly.FromDateTime(request.AppointmentAt);
        var today = DateOnly.FromDateTime(DateTime.Today);
        var combos = await db.Combodichvus.Include(x => x.Chitietcombos).Where(x => comboIds.Contains(x.ComboId) && x.TrangThai
            && (!x.NgayBatDauHieuLuc.HasValue || (x.NgayBatDauHieuLuc <= today && x.NgayBatDauHieuLuc <= bookingDate))
            && (!x.NgayKetThucHieuLuc.HasValue || (x.NgayKetThucHieuLuc >= today && x.NgayKetThucHieuLuc >= bookingDate)))
            .ToDictionaryAsync(x => x.ComboId, cancellationToken);
        if (combos.Count != comboIds.Count) return BadRequest("One or more combos are missing, inactive or outside their validity period.");
        var expectedPrices = request.Items.Select(x => services[x.ServiceId].Gia).ToArray();
        foreach (var group in request.Items.Select((item, index) => new { Item = item, Index = index }).Where(x => x.Item.ComboId.HasValue).GroupBy(x => x.Item.ComboId!.Value))
        {
            var combo = combos[group.Key];
            var counts = group.GroupBy(x => x.Item.ServiceId).ToDictionary(x => x.Key, x => x.Count());
            if (combo.Chitietcombos.Count == 0 || counts.Count != combo.Chitietcombos.Count) return BadRequest("Booking must include every combo component with its configured quantity.");
            int? copies = null;
            foreach (var component in combo.Chitietcombos)
            {
                if (component.SoLuong <= 0 || !counts.TryGetValue(component.DichVuId, out var count) || count % component.SoLuong != 0)
                    return BadRequest("Booking must include every combo component with its configured quantity.");
                var quantity = count / component.SoLuong;
                if (quantity <= 0 || (copies.HasValue && copies.Value != quantity)) return BadRequest("Combo component quantities must describe complete copies of the combo.");
                copies = quantity;
            }
            // Allocate combo price evenly across component rows; the last row receives the cent rounding remainder.
            var lines = group.ToList();
            var total = combo.GiaCombo * copies!.Value;
            var perComponent = decimal.Floor(total / lines.Count * 100m) / 100m;
            foreach (var line in lines) expectedPrices[line.Index] = perComponent;
            expectedPrices[lines[^1].Index] += total - perComponent * lines.Count;
        }
        var durationMinutes = request.Items.Sum(x => services[x.ServiceId].ThoiLuongPhut > 0 ? services[x.ServiceId].ThoiLuongPhut : 30);
        if (await AppointmentTiming.HasConflictAsync(db, customerId.Value, request.StaffId,
            request.AppointmentAt, durationMinutes, null, cancellationToken))
            return Conflict("Khách hàng hoặc nhân viên đã có lịch hẹn trong khoảng thời gian này.");
        if (!await AppointmentTiming.IsWithinShiftAsync(db, request.StaffId, request.AppointmentAt, durationMinutes, cancellationToken))
            return BadRequest("The entire appointment must be within the selected staff member's working shift.");
        var appointment = new Lichhen { KhachHangId = customerId.Value, NhanVienId = request.StaffId, NgayGioHen = request.AppointmentAt, TrangThai = "ChoXacNhan", GhiChu = request.Note?.Trim() };
        for (var index = 0; index < request.Items.Count; index++)
        {
            var item = request.Items[index];
            appointment.Chitietlichhens.Add(new Chitietlichhen { DichVuId = item.ServiceId, ComboId = item.ComboId, GiaDuKien = expectedPrices[index], ThoiLuongThucTe = services[item.ServiceId].ThoiLuongPhut });
        }
        if (request.CustomerPackageId.HasValue) {
            foreach (var line in appointment.Chitietlichhens) line.GiaDuKien = 0;
            var packageError = await ServicePackageLifecycle.ReserveAsync(db, appointment, request.CustomerPackageId.Value, cancellationToken);
            if (packageError != null) return BadRequest(packageError);
        }
        db.Lichhens.Add(appointment);
        if (!await NotificationPersistence.TrySaveAsync(db, cancellationToken)) return Conflict("Package session balance changed. Reload availability.");
        await db.Entry(appointment).Collection(x => x.Chitietlichhens).Query().Include(x => x.DichVu).LoadAsync(cancellationToken);
        return CreatedAtAction(nameof(GetMine), new { id = appointment.LichHenId }, Map(appointment));
    }

    private static AppointmentResponse Map(Lichhen item)
    {
        var invoice = item.Hoadons.OrderByDescending(x => x.NgayLap).ThenByDescending(x => x.HoaDonId).FirstOrDefault();
        var review = invoice?.Danhgia.OrderByDescending(x => x.NgayDanhGia).ThenByDescending(x => x.DanhGiaId).FirstOrDefault();
        return new AppointmentResponse(item.LichHenId, item.KhachHangId, item.NhanVienId, item.NgayGioHen,
            item.TrangThai, item.GhiChu,
            item.Chitietlichhens.Select(x => new AppointmentItemResponse(x.ChiTietLichHenId, x.DichVuId,
                x.DichVu?.TenDichVu ?? string.Empty, x.ComboId, x.GiaDuKien, AppointmentTiming.ItemDurationMinutes(x))).ToList(),
            InvoiceId: invoice?.HoaDonId, InvoiceStatus: invoice?.TrangThai,
            HasReviewed: review is not null, ReviewStars: review?.SoSao, CustomerPackageId: item.CustomerPackageId, FundingSource: item.CustomerPackageId.HasValue ? "ServicePackage" : "Cash");
    }
}
