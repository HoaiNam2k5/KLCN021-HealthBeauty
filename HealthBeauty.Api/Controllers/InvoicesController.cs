using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Controllers;

[ApiController, Authorize, Route("api/v1/invoices")]
public sealed class InvoicesController(Klcn021HealthBeautyContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        var query = db.Hoadons.AsNoTracking().Include(x => x.Chitiethoadons).ThenInclude(x => x.DichVu).Include(x => x.Chitiethoadons).ThenInclude(x => x.Combo).Include(x => x.Thanhtoans).AsQueryable();
        if (!isStaff && customerId.HasValue) query = query.Where(x => x.KhachHangId == customerId.Value);
        else if (!isStaff) return Forbid();
        var list = await query.OrderByDescending(x => x.NgayLap).Take(100).ToListAsync(ct);
        return Ok(list.Select(Map));
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateInvoiceRequest request, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Manager") || User.IsInRole("Reception");
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null && !isStaff) return Forbid();
        var appointment = await db.Lichhens.Include(x => x.Chitietlichhens).FirstOrDefaultAsync(x => x.LichHenId == request.AppointmentId, ct);
        if (appointment is null) return NotFound("Không tìm thấy lịch hẹn.");
        if (!isStaff && customer is not null && appointment.KhachHangId != customer.KhachHangId) return Forbid();
        if (appointment.TrangThai != "HoanThanh") return BadRequest("Only completed appointments can be invoiced.");
        if (await db.Hoadons.AnyAsync(x => x.LichHenId == appointment.LichHenId, ct)) return Conflict("Lịch hẹn đã có hóa đơn.");
        if (request.Items is null || request.Items.Count==0 || request.PointsToRedeem<0) return BadRequest("Invoice items and nonnegative points are required.");
        if (request.Items.Any(x => (x.ServiceId.HasValue ? 1 : 0) + (x.ComboId.HasValue ? 1 : 0) != 1)) return BadRequest("Mỗi dòng hóa đơn phải chọn đúng một dịch vụ hoặc combo.");
        var serviceIds = request.Items.Where(x => x.ServiceId.HasValue).Select(x => x.ServiceId!.Value).Distinct().ToList();
        var comboIds = request.Items.Where(x => x.ComboId.HasValue).Select(x => x.ComboId!.Value).Distinct().ToList();
        var services = await db.Dichvus.Where(x => serviceIds.Contains(x.DichVuId) && x.TrangThai).ToDictionaryAsync(x => x.DichVuId, ct);
        var combos = await db.Combodichvus.Include(x => x.Chitietcombos).Where(x => comboIds.Contains(x.ComboId) && x.TrangThai).ToDictionaryAsync(x => x.ComboId, ct);
        if (services.Count != serviceIds.Count || combos.Count != comboIds.Count) return BadRequest("Dịch vụ hoặc combo không hợp lệ.");
        if (!MatchesBookedItems(appointment, request.Items, combos)) return BadRequest("Invoice items must match the booked services and complete combos, including quantities.");
        var invoice = new Hoadon { LichHenId = appointment.LichHenId, KhachHangId = appointment.KhachHangId, NgayLap = DateTime.Now, TrangThai = "ChuaThanhToan" };
        foreach (var line in request.Items)
        {
            var unitPrice = line.ServiceId.HasValue ? services[line.ServiceId.Value].Gia : combos[line.ComboId!.Value].GiaCombo;
            invoice.Chitiethoadons.Add(new Chitiethoadon { DichVuId = line.ServiceId, ComboId = line.ComboId, SoLuong = line.Quantity, DonGia = unitPrice });
        }
        var subtotal = invoice.Chitiethoadons.Sum(x => x.DonGia * x.SoLuong);
        var discount = 0m;
        Voucher? appliedVoucher = null;
        if (!string.IsNullOrWhiteSpace(request.VoucherCode))
        {
            var voucher = await VoucherRules.FindApplicableAsync(db, request.VoucherCode, appointment.KhachHangId, ct);
            if (voucher is null) return BadRequest("Voucher is not valid for this customer or date.");
            var configuredDiscount = VoucherRules.NormalizeDiscount(voucher.KhuyenMai.LoaiGiam) == "PhanTram"
                ? subtotal * voucher.KhuyenMai.MucGiam / 100m
                : voucher.KhuyenMai.MucGiam;
            discount += Math.Min(subtotal, Math.Min(voucher.GiaTriGiam, configuredDiscount));
            appliedVoucher = voucher;
        }
        if (request.PointsToRedeem > 0)
        {
            if (customer is null || appointment.KhachHangId != customer.KhachHangId) customer = await db.Khachhangs.FirstAsync(x => x.KhachHangId == appointment.KhachHangId, ct);
            if (request.PointsToRedeem > customer.DiemThuong) return BadRequest("Số điểm sử dụng vượt quá số dư.");
            var appliedPoints = (int)Math.Min(decimal.Floor(Math.Max(0, subtotal - discount)), request.PointsToRedeem);
            discount += appliedPoints; customer.DiemThuong -= appliedPoints;
            if (appliedPoints > 0) db.Giaodichdiems.Add(new Giaodichdiem { HoaDon = invoice, KhachHangId = customer.KhachHangId, SoDiem = -appliedPoints, LoaiGiaoDich = "SuDung", NgayGiaoDich = DateTime.Now, GhiChu = "Đổi điểm trên hóa đơn" });
        }
        invoice.TongTienTruocGiam = subtotal; invoice.TongTienSauGiam = Math.Max(0, subtotal - discount);
        if (appliedVoucher is not null) appliedVoucher.TrangThai = false;
        db.Hoadons.Add(invoice); await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(List), new { id = invoice.HoaDonId }, new { invoice.HoaDonId, invoice.TongTienTruocGiam, invoice.TongTienSauGiam, invoice.TrangThai });
    }

    [Authorize(Roles = "Admin,Manager,Reception"), HttpPost("{id:int}/payments")]
    public async Task<IActionResult> Pay(int id, PaymentRequest request, CancellationToken ct)
    {
        if (!User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        var invoice = await db.Hoadons.Include(x => x.Thanhtoans).FirstOrDefaultAsync(x => x.HoaDonId == id, ct);
        if (invoice is null) return NotFound();
        if (invoice.TrangThai == "DaThanhToan") return Conflict("Hóa đơn đã thanh toán.");
        if (request.Status != "ThanhCong") return BadRequest("Chỉ ghi nhận giao dịch thành công qua endpoint này.");
        if (invoice.TrangThai != "ChuaThanhToan" || invoice.TongTienSauGiam < 0) return Conflict("This invoice cannot be settled.");
        if (invoice.TongTienSauGiam == 0)
        {
            invoice.TrangThai = "DaThanhToan";
            await db.SaveChangesAsync(ct);
            return Ok(new { InvoiceId = invoice.HoaDonId, Status = invoice.TrangThai, Amount = 0m, PaymentRequired = false });
        }
        var payment = new Thanhtoan { HoaDonId = invoice.HoaDonId, PhuongThuc = request.Method.Trim(), SoTien = invoice.TongTienSauGiam, NgayGioThanhToan = DateTime.Now, TrangThai = "ThanhCong" };
        invoice.TrangThai = "DaThanhToan"; invoice.Thanhtoans.Add(payment);
        var customer = await db.Khachhangs.FirstAsync(x => x.KhachHangId == invoice.KhachHangId, ct);
        var earned = decimal.ToInt32(decimal.Floor(invoice.TongTienSauGiam / 10000m));
        if (earned > 0) { customer.DiemThuong += earned; db.Giaodichdiems.Add(new Giaodichdiem { KhachHangId = customer.KhachHangId, HoaDonId = invoice.HoaDonId, SoDiem = earned, LoaiGiaoDich = "TichLuy", NgayGiaoDich = DateTime.Now, GhiChu = "Tích điểm thanh toán" }); }
        await db.SaveChangesAsync(ct);
        return Ok(new PaymentResponse(payment.ThanhToanId, payment.PhuongThuc, payment.SoTien, payment.NgayGioThanhToan, payment.TrangThai));
    }

    private static bool MatchesBookedItems(Lichhen appointment, List<InvoiceLineRequest> items, Dictionary<int, Combodichvu> combos)
    {
        if (items.Count == 0 || items.Any(x => x.Quantity <= 0)) return false;
        var booked = appointment.Chitietlichhens.Where(x => !x.ComboId.HasValue)
            .GroupBy(x => (ServiceId: (int?)x.DichVuId, ComboId: (int?)null))
            .ToDictionary(g => g.Key, g => g.Count());
        foreach (var group in appointment.Chitietlichhens.Where(x => x.ComboId.HasValue).GroupBy(x => x.ComboId!.Value))
        {
            if (!combos.TryGetValue(group.Key, out var combo) || combo.Chitietcombos.Count == 0) return false;
            var counts = group.GroupBy(x => x.DichVuId).ToDictionary(g => g.Key, g => g.Count());
            if (counts.Count != combo.Chitietcombos.Count) return false;
            int? quantity = null;
            foreach (var component in combo.Chitietcombos)
            {
                if (component.SoLuong <= 0 || !counts.TryGetValue(component.DichVuId, out var count) || count % component.SoLuong != 0) return false;
                var copies = count / component.SoLuong;
                if (copies <= 0 || (quantity.HasValue && quantity != copies)) return false;
                quantity = copies;
            }
            booked.Add((null, group.Key), quantity!.Value);
        }
        var requested = items.GroupBy(x => (x.ServiceId, x.ComboId)).ToDictionary(g => g.Key, g => g.Sum(x => (long)x.Quantity));
        return booked.Count > 0 && booked.Count == requested.Count && booked.All(x => requested.TryGetValue(x.Key, out var quantity) && quantity == x.Value);
    }

    private static InvoiceResponse Map(Hoadon x) => new(x.HoaDonId, x.LichHenId, x.KhachHangId, x.NgayLap, x.TongTienTruocGiam, x.TongTienSauGiam, x.TrangThai,
        x.Chitiethoadons.Select(i => new InvoiceLineResponse(i.HoaDonChiTietId, i.DichVuId, i.DichVu?.TenDichVu, i.ComboId, i.Combo?.TenCombo, i.SoLuong, i.DonGia)).ToList(),
        x.Thanhtoans.Select(p => new PaymentResponse(p.ThanhToanId, p.PhuongThuc, p.SoTien, p.NgayGioThanhToan, p.TrangThai)).ToList());
}
