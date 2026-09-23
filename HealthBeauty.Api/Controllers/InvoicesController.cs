using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Models;
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
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        var query = db.Hoadons.AsNoTracking().Include(x => x.Chitiethoadons).ThenInclude(x => x.DichVu).Include(x => x.Chitiethoadons).ThenInclude(x => x.Combo).Include(x => x.Thanhtoans).AsQueryable();
        if (customerId.HasValue) query = query.Where(x => x.KhachHangId == customerId.Value);
        else if (!User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        var list = await query.OrderByDescending(x => x.NgayLap).Take(100).ToListAsync(ct);
        return Ok(list.Select(Map));
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateInvoiceRequest request, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customer = await db.Khachhangs.FirstOrDefaultAsync(x => x.TaiKhoanId == accountId, ct);
        if (customer is null && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        var appointment = await db.Lichhens.Include(x => x.Chitietlichhens).FirstOrDefaultAsync(x => x.LichHenId == request.AppointmentId, ct);
        if (appointment is null) return NotFound("Không tìm thấy lịch hẹn.");
        if (customer is not null && appointment.KhachHangId != customer.KhachHangId) return Forbid();
        if (await db.Hoadons.AnyAsync(x => x.LichHenId == appointment.LichHenId, ct)) return Conflict("Lịch hẹn đã có hóa đơn.");
        if (request.Items.Any(x => (x.ServiceId.HasValue ? 1 : 0) + (x.ComboId.HasValue ? 1 : 0) != 1)) return BadRequest("Mỗi dòng hóa đơn phải chọn đúng một dịch vụ hoặc combo.");
        var serviceIds = request.Items.Where(x => x.ServiceId.HasValue).Select(x => x.ServiceId!.Value).Distinct().ToList();
        var comboIds = request.Items.Where(x => x.ComboId.HasValue).Select(x => x.ComboId!.Value).Distinct().ToList();
        var services = await db.Dichvus.Where(x => serviceIds.Contains(x.DichVuId) && x.TrangThai).ToDictionaryAsync(x => x.DichVuId, ct);
        var combos = await db.Combodichvus.Where(x => comboIds.Contains(x.ComboId) && x.TrangThai).ToDictionaryAsync(x => x.ComboId, ct);
        if (services.Count != serviceIds.Count || combos.Count != comboIds.Count) return BadRequest("Dịch vụ hoặc combo không hợp lệ.");
        var invoice = new Hoadon { LichHenId = appointment.LichHenId, KhachHangId = appointment.KhachHangId, NgayLap = DateTime.Now, TrangThai = "ChuaThanhToan" };
        foreach (var line in request.Items)
        {
            var unitPrice = line.ServiceId.HasValue ? services[line.ServiceId.Value].Gia : combos[line.ComboId!.Value].GiaCombo;
            invoice.Chitiethoadons.Add(new Chitiethoadon { DichVuId = line.ServiceId, ComboId = line.ComboId, SoLuong = line.Quantity, DonGia = unitPrice });
        }
        var subtotal = invoice.Chitiethoadons.Sum(x => x.DonGia * x.SoLuong);
        var discount = 0m;
        if (!string.IsNullOrWhiteSpace(request.VoucherCode))
        {
            var voucher = await db.Vouchers.Include(x => x.KhuyenMai).FirstOrDefaultAsync(x => x.MaCode == request.VoucherCode.Trim() && x.TrangThai && x.HanSuDung >= DateTime.Now && (x.KhachHangId == null || x.KhachHangId == appointment.KhachHangId), ct);
            if (voucher is null || (voucher.KhuyenMai.NgayBatDauHieuLuc.HasValue && voucher.KhuyenMai.NgayBatDauHieuLuc > DateTime.Now) || (voucher.KhuyenMai.NgayKetThucHieuLuc.HasValue && voucher.KhuyenMai.NgayKetThucHieuLuc < DateTime.Now)) return BadRequest("Voucher không hợp lệ hoặc đã hết hạn.");
            var configuredDiscount = voucher.KhuyenMai.LoaiGiam.Equals("PhanTram", StringComparison.OrdinalIgnoreCase)
                ? subtotal * voucher.KhuyenMai.MucGiam / 100m
                : voucher.KhuyenMai.MucGiam;
            discount += Math.Min(subtotal, Math.Min(voucher.GiaTriGiam, configuredDiscount));
            voucher.TrangThai = false;
        }
        if (request.PointsToRedeem > 0)
        {
            if (customer is null || appointment.KhachHangId != customer.KhachHangId) customer = await db.Khachhangs.FirstAsync(x => x.KhachHangId == appointment.KhachHangId, ct);
            if (request.PointsToRedeem > customer.DiemThuong) return BadRequest("Số điểm sử dụng vượt quá số dư.");
            var pointsDiscount = Math.Min(subtotal - discount, request.PointsToRedeem);
            discount += pointsDiscount; customer.DiemThuong -= request.PointsToRedeem;
            db.Giaodichdiems.Add(new Giaodichdiem { KhachHangId = customer.KhachHangId, SoDiem = -request.PointsToRedeem, LoaiGiaoDich = "SuDung", NgayGiaoDich = DateTime.Now, GhiChu = "Đổi điểm trên hóa đơn" });
        }
        invoice.TongTienTruocGiam = subtotal; invoice.TongTienSauGiam = Math.Max(0, subtotal - discount);
        db.Hoadons.Add(invoice); await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(List), new { id = invoice.HoaDonId }, new { invoice.HoaDonId, invoice.TongTienTruocGiam, invoice.TongTienSauGiam, invoice.TrangThai });
    }

    [HttpPost("{id:int}/payments")]
    public async Task<IActionResult> Pay(int id, PaymentRequest request, CancellationToken ct)
    {
        var accountId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var customerId = await db.Khachhangs.Where(x => x.TaiKhoanId == accountId).Select(x => (int?)x.KhachHangId).FirstOrDefaultAsync(ct);
        var invoice = await db.Hoadons.Include(x => x.Thanhtoans).FirstOrDefaultAsync(x => x.HoaDonId == id, ct);
        if (invoice is null) return NotFound();
        if (customerId.HasValue && invoice.KhachHangId != customerId.Value) return Forbid();
        if (!customerId.HasValue && !User.IsInRole("Admin") && !User.IsInRole("Manager") && !User.IsInRole("Reception")) return Forbid();
        if (invoice.TrangThai == "DaThanhToan") return Conflict("Hóa đơn đã thanh toán.");
        if (request.Status != "ThanhCong") return BadRequest("Chỉ ghi nhận giao dịch thành công qua endpoint này.");
        var payment = new Thanhtoan { HoaDonId = invoice.HoaDonId, PhuongThuc = request.Method.Trim(), SoTien = invoice.TongTienSauGiam, NgayGioThanhToan = DateTime.Now, TrangThai = "ThanhCong" };
        invoice.TrangThai = "DaThanhToan"; invoice.Thanhtoans.Add(payment);
        var customer = await db.Khachhangs.FirstAsync(x => x.KhachHangId == invoice.KhachHangId, ct);
        var earned = decimal.ToInt32(decimal.Floor(invoice.TongTienSauGiam / 10000m));
        if (earned > 0) { customer.DiemThuong += earned; db.Giaodichdiems.Add(new Giaodichdiem { KhachHangId = customer.KhachHangId, HoaDonId = invoice.HoaDonId, SoDiem = earned, LoaiGiaoDich = "TichLuy", NgayGiaoDich = DateTime.Now, GhiChu = "Tích điểm thanh toán" }); }
        await db.SaveChangesAsync(ct);
        return Ok(new PaymentResponse(payment.ThanhToanId, payment.PhuongThuc, payment.SoTien, payment.NgayGioThanhToan, payment.TrangThai));
    }

    private static InvoiceResponse Map(Hoadon x) => new(x.HoaDonId, x.LichHenId, x.KhachHangId, x.NgayLap, x.TongTienTruocGiam, x.TongTienSauGiam, x.TrangThai,
        x.Chitiethoadons.Select(i => new InvoiceLineResponse(i.HoaDonChiTietId, i.DichVuId, i.DichVu?.TenDichVu, i.ComboId, i.Combo?.TenCombo, i.SoLuong, i.DonGia)).ToList(),
        x.Thanhtoans.Select(p => new PaymentResponse(p.ThanhToanId, p.PhuongThuc, p.SoTien, p.NgayGioThanhToan, p.TrangThai)).ToList());
}
