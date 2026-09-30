/* KLCN021 demo seed data. Safe to run repeatedly; does not create login accounts. */
USE [KLCN021_HealthBeauty];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

/* Roles */
INSERT dbo.VAITRO (TenVaiTro, MoTa)
SELECT source.TenVaiTro, source.MoTa
FROM (VALUES
    (N'Admin', N'Quản trị toàn bộ hệ thống'),
    (N'Manager', N'Quản lý hoạt động spa'),
    (N'Reception', N'Tiếp nhận khách hàng và lịch hẹn'),
    (N'Staff', N'Nhân viên thực hiện dịch vụ'),
    (N'Customer', N'Khách hàng sử dụng dịch vụ')
) AS source(TenVaiTro, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM dbo.VAITRO role WHERE role.TenVaiTro = source.TenVaiTro);

/* Add the declared permission catalog if the schema script was from an older version. */
INSERT dbo.QUYEN (MaQuyen, TenQuyen, NhomQuyen, MoTa)
SELECT source.MaQuyen, source.TenQuyen, source.NhomQuyen, source.MoTa
FROM (VALUES
    ('ACCOUNT.READ', N'Xem tài khoản', 'ACCOUNT', N'Xem thông tin tài khoản'),
    ('ACCOUNT.WRITE', N'Quản lý tài khoản', 'ACCOUNT', N'Tạo và cập nhật tài khoản'),
    ('ROLE.READ', N'Xem vai trò và quyền', 'AUTHORIZATION', N'Tra cứu vai trò, quyền'),
    ('ROLE.WRITE', N'Quản lý vai trò và quyền', 'AUTHORIZATION', N'Gán hoặc thu hồi quyền'),
    ('CUSTOMER.READ', N'Xem khách hàng', 'CUSTOMER', N'Tra cứu hồ sơ khách hàng'),
    ('CUSTOMER.WRITE', N'Quản lý khách hàng', 'CUSTOMER', N'Tạo, sửa hồ sơ khách hàng'),
    ('STAFF.READ', N'Xem nhân viên', 'STAFF', N'Tra cứu nhân viên'),
    ('STAFF.WRITE', N'Quản lý nhân viên', 'STAFF', N'Tạo, sửa nhân viên'),
    ('SERVICE.READ', N'Xem dịch vụ', 'SERVICE', N'Tra cứu dịch vụ và combo'),
    ('SERVICE.WRITE', N'Quản lý dịch vụ', 'SERVICE', N'Tạo, sửa, ngừng dịch vụ'),
    ('APPOINTMENT.READ', N'Xem lịch hẹn', 'APPOINTMENT', N'Tra cứu lịch hẹn'),
    ('APPOINTMENT.WRITE', N'Quản lý lịch hẹn', 'APPOINTMENT', N'Tạo, phân công, hủy lịch'),
    ('INVOICE.READ', N'Xem hóa đơn', 'BILLING', N'Tra cứu hóa đơn'),
    ('INVOICE.WRITE', N'Quản lý hóa đơn', 'BILLING', N'Lập và cập nhật hóa đơn'),
    ('PAYMENT.WRITE', N'Xử lý thanh toán', 'BILLING', N'Ghi nhận và xác nhận thanh toán'),
    ('PROMOTION.WRITE', N'Quản lý khuyến mãi', 'PROMOTION', N'Quản lý chương trình và voucher'),
    ('REVIEW.MODERATE', N'Duyệt đánh giá', 'REVIEW', N'Duyệt hoặc ẩn đánh giá'),
    ('REPORT.READ', N'Xem báo cáo', 'REPORT', N'Xem và xuất báo cáo')
) AS source(MaQuyen, TenQuyen, NhomQuyen, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM dbo.QUYEN permission WHERE permission.MaQuyen = source.MaQuyen);

/* Role permissions */
INSERT dbo.VAITRO_QUYEN (VaiTroID, QuyenID, DuocCap)
SELECT role.VaiTroID, permission.QuyenID, 1
FROM dbo.VAITRO role
CROSS JOIN dbo.QUYEN permission
WHERE (role.TenVaiTro = N'Admin'
    OR (role.TenVaiTro = N'Manager' AND permission.MaQuyen <> 'ROLE.WRITE' AND permission.MaQuyen <> 'ACCOUNT.WRITE')
    OR (role.TenVaiTro = N'Reception' AND permission.MaQuyen IN ('CUSTOMER.READ','APPOINTMENT.READ','APPOINTMENT.WRITE','SERVICE.READ','INVOICE.READ','PAYMENT.WRITE'))
    OR (role.TenVaiTro = N'Staff' AND permission.MaQuyen IN ('APPOINTMENT.READ','SERVICE.READ'))
    OR (role.TenVaiTro = N'Customer' AND permission.MaQuyen IN ('SERVICE.READ')))
  AND NOT EXISTS (SELECT 1 FROM dbo.VAITRO_QUYEN existing WHERE existing.VaiTroID = role.VaiTroID AND existing.QuyenID = permission.QuyenID);

/* Local demo accounts. Password for all accounts: HealthBeauty@123 */
DECLARE @DemoPasswordHash varchar(255) = 'pbkdf2-sha256$120000$fnjwqvuwHQp88WUYf6pzWw==$8NUbd6hOBjpJzKJo8qZBD2tmef9wQiTU35Bx0jPF9vA=';
INSERT dbo.TAIKHOAN (VaiTroID, TenTaiKhoan, MatKhauHash, Email, TrangThai, NgayTao)
SELECT role.VaiTroID, source.TenTaiKhoan, @DemoPasswordHash, source.Email, 1, GETDATE()
FROM (VALUES
    (N'Admin', N'Quản trị demo', 'admin@healthbeauty.local'),
    (N'Reception', N'Lễ tân demo', 'reception@healthbeauty.local'),
    (N'Customer', N'Nguyễn Minh Anh', 'customer@healthbeauty.local')
) source(TenVaiTro, TenTaiKhoan, Email)
INNER JOIN dbo.VAITRO role ON role.TenVaiTro = source.TenVaiTro
WHERE NOT EXISTS (SELECT 1 FROM dbo.TAIKHOAN account WHERE account.Email = source.Email);

/* Customers and staff; phone numbers are stable demo keys for idempotent inserts. */
INSERT dbo.KHACHHANG (TaiKhoanID, HoTen, SoDienThoai, GioiTinh, DiemThuong)
SELECT NULL, source.HoTen, source.SoDienThoai, source.GioiTinh, 0
FROM (VALUES
    (N'Nguyễn Minh Anh', '0901000001', N'Nữ'),
    (N'Trần Ngọc Mai', '0901000002', N'Nữ'),
    (N'Lê Hoàng Nam', '0901000003', N'Nam')
) AS source(HoTen, SoDienThoai, GioiTinh)
WHERE NOT EXISTS (SELECT 1 FROM dbo.KHACHHANG customer WHERE customer.SoDienThoai = source.SoDienThoai);

INSERT dbo.NHANVIEN (TaiKhoanID, HoTen, ChucVu, ChuyenMon, SoDienThoai, NgayVaoLam)
SELECT NULL, source.HoTen, source.ChucVu, source.ChuyenMon, source.SoDienThoai, DATEADD(day, -180, CONVERT(date, GETDATE()))
FROM (VALUES
    (N'Phạm Thu Hà', N'Kỹ thuật viên', N'Chăm sóc da', '0912000001'),
    (N'Võ Thanh Trúc', N'Kỹ thuật viên', N'Massage thư giãn', '0912000002'),
    (N'Nguyễn Quốc Bảo', N'Tư vấn viên', N'Tư vấn liệu trình', '0912000003')
) AS source(HoTen, ChucVu, ChuyenMon, SoDienThoai)
WHERE NOT EXISTS (SELECT 1 FROM dbo.NHANVIEN staff WHERE staff.SoDienThoai = source.SoDienThoai);

UPDATE customer SET TaiKhoanID = account.TaiKhoanID
FROM dbo.KHACHHANG customer
INNER JOIN dbo.TAIKHOAN account ON account.Email = 'customer@healthbeauty.local'
WHERE customer.SoDienThoai = '0901000001' AND customer.TaiKhoanID IS NULL;

UPDATE staff SET TaiKhoanID = account.TaiKhoanID
FROM dbo.NHANVIEN staff
INNER JOIN dbo.TAIKHOAN account ON account.Email = 'reception@healthbeauty.local'
WHERE staff.SoDienThoai = '0912000003' AND staff.TaiKhoanID IS NULL;

/* Service catalog */
INSERT dbo.LOAIDICHVU (TenLoai, MoTa, TrangThai)
SELECT source.TenLoai, source.MoTa, 1
FROM (VALUES
    (N'Chăm sóc da mặt', N'Làm sạch và chăm sóc da mặt'),
    (N'Massage thư giãn', N'Các liệu trình thư giãn cơ thể'),
    (N'Chăm sóc cơ thể', N'Dịch vụ chăm sóc da và cơ thể'),
    (N'Triệt lông', N'Dịch vụ triệt lông công nghệ cao')
) AS source(TenLoai, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LOAIDICHVU category WHERE category.TenLoai = source.TenLoai);

INSERT dbo.DICHVU (LoaiDichVuID, TenDichVu, Gia, ThoiLuongPhut, MoTa, TrangThai)
SELECT category.LoaiDichVuID, source.TenDichVu, source.Gia, source.ThoiLuongPhut, source.MoTa, 1
FROM (VALUES
    (N'Chăm sóc da mặt', N'Làm sạch da chuyên sâu', CAST(350000 AS decimal(18,2)), 60, N'Làm sạch, tẩy tế bào chết và dưỡng ẩm cơ bản.'),
    (N'Chăm sóc da mặt', N'Chăm sóc da mụn', CAST(550000 AS decimal(18,2)), 75, N'Làm sạch và chăm sóc da mụn theo tình trạng da.'),
    (N'Chăm sóc da mặt', N'Điện di cấp ẩm', CAST(450000 AS decimal(18,2)), 60, N'Hỗ trợ cấp ẩm và làm dịu da.'),
    (N'Chăm sóc da mặt', N'Chăm sóc da mặt thư giãn', CAST(300000 AS decimal(18,2)), 45, N'Quy trình chăm sóc da mặt thư giãn.'),
    (N'Massage thư giãn', N'Massage cổ vai gáy', CAST(400000 AS decimal(18,2)), 60, N'Thư giãn vùng cổ, vai và gáy.'),
    (N'Massage thư giãn', N'Massage body đá nóng', CAST(750000 AS decimal(18,2)), 90, N'Massage toàn thân kết hợp đá nóng.'),
    (N'Massage thư giãn', N'Massage chân thư giãn', CAST(300000 AS decimal(18,2)), 45, N'Ngâm chân và massage thư giãn.'),
    (N'Chăm sóc cơ thể', N'Tẩy tế bào chết toàn thân', CAST(500000 AS decimal(18,2)), 60, N'Làm sạch tế bào chết trên da cơ thể.'),
    (N'Chăm sóc cơ thể', N'Ủ dưỡng trắng body', CAST(650000 AS decimal(18,2)), 75, N'Chăm sóc và dưỡng ẩm da cơ thể.'),
    (N'Triệt lông', N'Triệt lông nách', CAST(250000 AS decimal(18,2)), 30, N'Liệu trình triệt lông vùng nách.'),
    (N'Triệt lông', N'Triệt lông tay', CAST(500000 AS decimal(18,2)), 45, N'Liệu trình triệt lông vùng tay.'),
    (N'Triệt lông', N'Triệt lông chân', CAST(700000 AS decimal(18,2)), 60, N'Liệu trình triệt lông vùng chân.')
) AS source(TenLoai, TenDichVu, Gia, ThoiLuongPhut, MoTa)
INNER JOIN dbo.LOAIDICHVU category ON category.TenLoai = source.TenLoai
WHERE NOT EXISTS (SELECT 1 FROM dbo.DICHVU service WHERE service.TenDichVu = source.TenDichVu);

/* Active service packages */
INSERT dbo.COMBODICHVU (TenCombo, GiaCombo, NgayBatDauHieuLuc, NgayKetThucHieuLuc, TrangThai)
SELECT source.TenCombo, source.GiaCombo, CONVERT(date, GETDATE()), DATEADD(day, 365, CONVERT(date, GETDATE())), 1
FROM (VALUES
    (N'Combo Da khỏe 3 buổi', CAST(1200000 AS decimal(18,2))),
    (N'Combo Thư giãn cuối tuần', CAST(1050000 AS decimal(18,2))),
    (N'Combo Chăm sóc toàn diện', CAST(1850000 AS decimal(18,2)))
) AS source(TenCombo, GiaCombo)
WHERE NOT EXISTS (SELECT 1 FROM dbo.COMBODICHVU combo WHERE combo.TenCombo = source.TenCombo);

INSERT dbo.CHITIETCOMBO (ComboID, DichVuID, SoLuong)
SELECT combo.ComboID, service.DichVuID, source.SoLuong
FROM (VALUES
    (N'Combo Da khỏe 3 buổi', N'Chăm sóc da mụn', 1),
    (N'Combo Da khỏe 3 buổi', N'Điện di cấp ẩm', 2),
    (N'Combo Thư giãn cuối tuần', N'Massage cổ vai gáy', 1),
    (N'Combo Thư giãn cuối tuần', N'Massage chân thư giãn', 1),
    (N'Combo Chăm sóc toàn diện', N'Làm sạch da chuyên sâu', 1),
    (N'Combo Chăm sóc toàn diện', N'Massage body đá nóng', 1),
    (N'Combo Chăm sóc toàn diện', N'Tẩy tế bào chết toàn thân', 1)
) AS source(TenCombo, TenDichVu, SoLuong)
INNER JOIN dbo.COMBODICHVU combo ON combo.TenCombo = source.TenCombo
INNER JOIN dbo.DICHVU service ON service.TenDichVu = source.TenDichVu
WHERE NOT EXISTS (SELECT 1 FROM dbo.CHITIETCOMBO detail WHERE detail.ComboID = combo.ComboID AND detail.DichVuID = service.DichVuID);

/* Staff shifts in the next several days */
INSERT dbo.LICHLAMVIEC (NhanVienID, NgayLam, GioBatDau, GioKetThuc, TrangThai)
SELECT staff.NhanVienID, DATEADD(day, dayOffsets.DayOffset, CONVERT(date, GETDATE())), '09:00', '17:00', N'HoatDong'
FROM dbo.NHANVIEN staff
CROSS JOIN (VALUES (1), (2), (3), (4), (5)) dayOffsets(DayOffset)
WHERE staff.SoDienThoai IN ('0912000001','0912000002','0912000003')
  AND NOT EXISTS (SELECT 1 FROM dbo.LICHLAMVIEC schedule WHERE schedule.NhanVienID = staff.NhanVienID AND schedule.NgayLam = DATEADD(day, dayOffsets.DayOffset, CONVERT(date, GETDATE())) AND schedule.GioBatDau = '09:00');

/* Promotion and one public plus one customer-specific voucher */
IF NOT EXISTS (SELECT 1 FROM dbo.KHUYENMAI WHERE TenKhuyenMai = N'Ưu đãi khách hàng mới - HealthBeauty Demo')
    INSERT dbo.KHUYENMAI (TenKhuyenMai, LoaiGiam, MucGiam, DieuKienApDung, NgayBatDauHieuLuc, NgayKetThucHieuLuc)
    VALUES (N'Ưu đãi khách hàng mới - HealthBeauty Demo', N'PhanTram', 10, N'Giảm tối đa theo giá trị voucher; áp dụng cho khách hàng mới.', DATEADD(day, -1, GETDATE()), DATEADD(day, 365, GETDATE()));

INSERT dbo.VOUCHER (MaCode, KhuyenMaiID, KhachHangID, GiaTriGiam, HanSuDung, TrangThai)
SELECT source.MaCode, promotion.KhuyenMaiID, customer.KhachHangID, source.GiaTriGiam, DATEADD(day, 90, GETDATE()), 1
FROM (VALUES ('WELCOME10', CAST(200000 AS decimal(18,2)), CAST(NULL AS varchar(15))), ('MAI100K', CAST(100000 AS decimal(18,2)), CAST('0901000002' AS varchar(15)))) source(MaCode, GiaTriGiam, CustomerPhone)
CROSS JOIN dbo.KHUYENMAI promotion
LEFT JOIN dbo.KHACHHANG customer ON customer.SoDienThoai = source.CustomerPhone
WHERE promotion.TenKhuyenMai = N'Ưu đãi khách hàng mới - HealthBeauty Demo'
  AND NOT EXISTS (SELECT 1 FROM dbo.VOUCHER voucher WHERE voucher.MaCode = source.MaCode);

/* Demo appointments use stable markers; dates are generated relative to run date. */
INSERT dbo.LICHHEN (KhachHangID, NhanVienID, NgayGioHen, GioKetThucDuKien, TrangThai, GhiChu)
SELECT customer.KhachHangID, staff.NhanVienID, DATEADD(hour, 10, CAST(DATEADD(day, -2, CONVERT(date, GETDATE())) AS datetime2(0))), '11:15', N'HoanThanh', N'[DEMO-SEED:APPT-PAID-001] Khách đã hoàn thành buổi chăm sóc da.'
FROM dbo.KHACHHANG customer CROSS JOIN dbo.NHANVIEN staff
WHERE customer.SoDienThoai = '0901000001' AND staff.SoDienThoai = '0912000001'
  AND NOT EXISTS (SELECT 1 FROM dbo.LICHHEN appointment WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0);

INSERT dbo.LICHHEN (KhachHangID, NhanVienID, NgayGioHen, GioKetThucDuKien, TrangThai, GhiChu)
SELECT customer.KhachHangId, staff.NhanVienID, DATEADD(hour, 14, CAST(DATEADD(day, 2, CONVERT(date, GETDATE())) AS datetime2(0))), '15:00', N'ChoXacNhan', N'[DEMO-SEED:APPT-UPCOMING-002] Lịch hẹn demo sắp tới.'
FROM dbo.KHACHHANG customer CROSS JOIN dbo.NHANVIEN staff
WHERE customer.SoDienThoai = '0901000002' AND staff.SoDienThoai = '0912000002'
  AND NOT EXISTS (SELECT 1 FROM dbo.LICHHEN appointment WHERE CHARINDEX(N'[DEMO-SEED:APPT-UPCOMING-002]', appointment.GhiChu) > 0);

INSERT dbo.LICHHEN (KhachHangID, NhanVienID, NgayGioHen, GioKetThucDuKien, TrangThai, GhiChu)
SELECT customer.KhachHangID, staff.NhanVienID, DATEADD(hour, 9, CAST(DATEADD(day, 4, CONVERT(date, GETDATE())) AS datetime2(0))), '10:00', N'ChoXacNhan', N'[DEMO-SEED:APPT-UPCOMING-003] Lịch hẹn demo dịch vụ massage.'
FROM dbo.KHACHHANG customer CROSS JOIN dbo.NHANVIEN staff
WHERE customer.SoDienThoai = '0901000003' AND staff.SoDienThoai = '0912000002'
  AND NOT EXISTS (SELECT 1 FROM dbo.LICHHEN appointment WHERE CHARINDEX(N'[DEMO-SEED:APPT-UPCOMING-003]', appointment.GhiChu) > 0);

/* Appointment details */
INSERT dbo.CHITIETLICHHEN (LichHenID, DichVuID, ComboID, ThoiLuongThucTe, GiaDuKien)
SELECT appointment.LichHenID, service.DichVuID, NULL, service.ThoiLuongPhut, service.Gia
FROM dbo.LICHHEN appointment
INNER JOIN dbo.KHACHHANG customer ON customer.KhachHangID = appointment.KhachHangID
INNER JOIN dbo.DICHVU service ON service.TenDichVu = N'Chăm sóc da mụn'
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETLICHHEN detail WHERE detail.LichHenID = appointment.LichHenID AND detail.DichVuID = service.DichVuID);

INSERT dbo.CHITIETLICHHEN (LichHenID, DichVuID, ComboID, ThoiLuongThucTe, GiaDuKien)
SELECT appointment.LichHenID, service.DichVuID, NULL, service.ThoiLuongPhut, service.Gia
FROM dbo.LICHHEN appointment CROSS JOIN dbo.DICHVU service
WHERE CHARINDEX(N'[DEMO-SEED:APPT-UPCOMING-002]', appointment.GhiChu) > 0 AND service.TenDichVu = N'Điện di cấp ẩm'
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETLICHHEN detail WHERE detail.LichHenID = appointment.LichHenID AND detail.DichVuID = service.DichVuID);

INSERT dbo.CHITIETLICHHEN (LichHenID, DichVuID, ComboID, ThoiLuongThucTe, GiaDuKien)
SELECT appointment.LichHenID, service.DichVuID, combo.ComboID, service.ThoiLuongPhut, combo.GiaCombo
FROM dbo.LICHHEN appointment CROSS JOIN dbo.DICHVU service CROSS JOIN dbo.COMBODICHVU combo
WHERE CHARINDEX(N'[DEMO-SEED:APPT-UPCOMING-003]', appointment.GhiChu) > 0 AND service.TenDichVu = N'Massage cổ vai gáy' AND combo.TenCombo = N'Combo Thư giãn cuối tuần'
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETLICHHEN detail WHERE detail.LichHenID = appointment.LichHenID AND detail.DichVuID = service.DichVuID AND detail.ComboID = combo.ComboID);

INSERT dbo.CHITIETLICHHEN (LichHenID, DichVuID, ComboID, ThoiLuongThucTe, GiaDuKien)
SELECT appointment.LichHenID, service.DichVuID, combo.ComboID, service.ThoiLuongPhut, combo.GiaCombo
FROM dbo.LICHHEN appointment CROSS JOIN dbo.DICHVU service CROSS JOIN dbo.COMBODICHVU combo
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0 AND service.TenDichVu = N'Điện di cấp ẩm' AND combo.TenCombo = N'Combo Da khỏe 3 buổi'
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETLICHHEN detail WHERE detail.LichHenID = appointment.LichHenID AND detail.DichVuID = service.DichVuID AND detail.ComboID = combo.ComboID);

/* One paid invoice and one unpaid invoice to exercise billing screens. */
INSERT dbo.HOADON (LichHenID, KhachHangID, NgayLap, TongTienTruocGiam, TongTienSauGiam, TrangThai)
SELECT appointment.LichHenID, appointment.KhachHangID, DATEADD(day, -2, GETDATE()), 1750000, 1550000, N'DaThanhToan'
FROM dbo.LICHHEN appointment WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.HOADON invoice WHERE invoice.LichHenID = appointment.LichHenID);

INSERT dbo.HOADON (LichHenID, KhachHangID, NgayLap, TongTienTruocGiam, TongTienSauGiam, TrangThai)
SELECT appointment.LichHenID, appointment.KhachHangID, GETDATE(), service.Gia, service.Gia, N'ChuaThanhToan'
FROM dbo.LICHHEN appointment CROSS JOIN dbo.DICHVU service
WHERE CHARINDEX(N'[DEMO-SEED:APPT-UPCOMING-002]', appointment.GhiChu) > 0 AND service.TenDichVu = N'Điện di cấp ẩm'
  AND NOT EXISTS (SELECT 1 FROM dbo.HOADON invoice WHERE invoice.LichHenID = appointment.LichHenID);

INSERT dbo.CHITIETHOADON (HoaDonID, DichVuID, ComboID, SoLuong, DonGia)
SELECT invoice.HoaDonID, service.DichVuID, NULL, 1, service.Gia
FROM dbo.HOADON invoice
INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID
CROSS JOIN dbo.DICHVU service
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0 AND service.TenDichVu = N'Chăm sóc da mụn'
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETHOADON line WHERE line.HoaDonID = invoice.HoaDonID AND line.DichVuID = service.DichVuID);

INSERT dbo.CHITIETHOADON (HoaDonID, DichVuID, ComboID, SoLuong, DonGia)
SELECT invoice.HoaDonID, NULL, combo.ComboID, 1, combo.GiaCombo
FROM dbo.HOADON invoice
INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID
CROSS JOIN dbo.COMBODICHVU combo
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0 AND combo.TenCombo = N'Combo Da khỏe 3 buổi'
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETHOADON line WHERE line.HoaDonID = invoice.HoaDonID AND line.ComboID = combo.ComboID);

INSERT dbo.CHITIETHOADON (HoaDonID, DichVuID, ComboID, SoLuong, DonGia)
SELECT invoice.HoaDonID, service.DichVuID, NULL, 1, service.Gia
FROM dbo.HOADON invoice
INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID
CROSS JOIN dbo.DICHVU service
WHERE CHARINDEX(N'[DEMO-SEED:APPT-UPCOMING-002]', appointment.GhiChu) > 0 AND service.TenDichVu = N'Điện di cấp ẩm'
  AND NOT EXISTS (SELECT 1 FROM dbo.CHITIETHOADON line WHERE line.HoaDonID = invoice.HoaDonID AND line.DichVuID = service.DichVuID);

INSERT dbo.THANHTOAN (HoaDonID, PhuongThuc, SoTien, NgayGioThanhToan, TrangThai)
SELECT invoice.HoaDonID, N'TienMat', invoice.TongTienSauGiam, DATEADD(day, -2, GETDATE()), N'ThanhCong'
FROM dbo.HOADON invoice INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.THANHTOAN payment WHERE payment.HoaDonID = invoice.HoaDonID AND payment.TrangThai = N'ThanhCong');

INSERT dbo.DANHGIA (HoaDonID, SoSao, BinhLuan, NgayDanhGia, TrangThai)
SELECT invoice.HoaDonID, 5, N'[DEMO] Nhân viên tư vấn nhiệt tình, dịch vụ dễ chịu.', DATEADD(day, -1, GETDATE()), N'HienThi'
FROM dbo.HOADON invoice INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.DANHGIA review WHERE review.HoaDonID = invoice.HoaDonID);

INSERT dbo.GIAODICHDIEM (KhachHangID, HoaDonID, SoDiem, LoaiGiaoDich, NgayGiaoDich, GhiChu)
SELECT invoice.KhachHangID, invoice.HoaDonID, 155, N'TichLuy', GETDATE(), N'[DEMO] Điểm thưởng từ hóa đơn mẫu.'
FROM dbo.HOADON invoice INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID
WHERE CHARINDEX(N'[DEMO-SEED:APPT-PAID-001]', appointment.GhiChu) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.GIAODICHDIEM transactionPoint WHERE transactionPoint.HoaDonID = invoice.HoaDonID AND transactionPoint.GhiChu = N'[DEMO] Điểm thưởng từ hóa đơn mẫu.');

UPDATE customer SET DiemThuong = pointTotal.TotalPoints
FROM dbo.KHACHHANG customer
CROSS APPLY (SELECT COALESCE(SUM(points.SoDiem), 0) AS TotalPoints FROM dbo.GIAODICHDIEM points WHERE points.KhachHangID = customer.KhachHangID) pointTotal
WHERE customer.SoDienThoai IN ('0901000001','0901000002','0901000003');

COMMIT TRANSACTION;
GO

/* Seed summary */
SELECT N'VaiTro' AS Bang, COUNT(*) AS SoLuong FROM dbo.VAITRO
UNION ALL SELECT N'Quyen', COUNT(*) FROM dbo.QUYEN
UNION ALL SELECT N'TaiKhoanDemo', COUNT(*) FROM dbo.TAIKHOAN WHERE Email LIKE '%@healthbeauty.local'
UNION ALL SELECT N'KhachHang', COUNT(*) FROM dbo.KHACHHANG WHERE SoDienThoai IN ('0901000001','0901000002','0901000003')
UNION ALL SELECT N'NhanVien', COUNT(*) FROM dbo.NHANVIEN WHERE SoDienThoai IN ('0912000001','0912000002','0912000003')
UNION ALL SELECT N'DichVu', COUNT(*) FROM dbo.DICHVU
UNION ALL SELECT N'ComboDichVu', COUNT(*) FROM dbo.COMBODICHVU
UNION ALL SELECT N'LichHenDemo', COUNT(*) FROM dbo.LICHHEN WHERE CHARINDEX(N'[DEMO-SEED:APPT-', GhiChu) > 0
UNION ALL SELECT N'HoaDonDemo', COUNT(*) FROM dbo.HOADON invoice INNER JOIN dbo.LICHHEN appointment ON appointment.LichHenID = invoice.LichHenID WHERE CHARINDEX(N'[DEMO-SEED:APPT-', appointment.GhiChu) > 0;
GO
