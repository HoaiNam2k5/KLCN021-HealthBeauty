/* KLCN021 - Database generated from the design class diagram.
   Run in SQL Server Management Studio. Existing tables are preserved. */
IF DB_ID(N'KLCN021_HealthBeauty') IS NULL
    CREATE DATABASE [KLCN021_HealthBeauty];
GO
USE [KLCN021_HealthBeauty];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.VAITRO',N'U') IS NULL
CREATE TABLE dbo.VAITRO (
    VaiTroID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_VAITRO PRIMARY KEY,
    TenVaiTro nvarchar(50) NOT NULL,
    MoTa nvarchar(255) NULL
);
IF OBJECT_ID(N'dbo.TAIKHOAN',N'U') IS NULL
CREATE TABLE dbo.TAIKHOAN (
    TaiKhoanID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_TAIKHOAN PRIMARY KEY,
    VaiTroID int NOT NULL,
    TenTaiKhoan nvarchar(100) NULL,
    MatKhauHash varchar(255) NOT NULL,
    Email varchar(255) NOT NULL CONSTRAINT UQ_TAIKHOAN_Email UNIQUE,
    TrangThai bit NOT NULL CONSTRAINT DF_TAIKHOAN_TrangThai DEFAULT 1,
    NgayTao datetime2(0) NOT NULL CONSTRAINT DF_TAIKHOAN_NgayTao DEFAULT SYSDATETIME(),
    CONSTRAINT FK_TAIKHOAN_VAITRO FOREIGN KEY (VaiTroID) REFERENCES dbo.VAITRO(VaiTroID)
);

/* Authentication, detailed authorization and security auditing */
IF COL_LENGTH(N'dbo.TAIKHOAN', N'SoLanDangNhapSai') IS NULL
    ALTER TABLE dbo.TAIKHOAN ADD SoLanDangNhapSai int NOT NULL CONSTRAINT DF_TAIKHOAN_SoLanSai DEFAULT 0;
IF COL_LENGTH(N'dbo.TAIKHOAN', N'KhoaDen') IS NULL
    ALTER TABLE dbo.TAIKHOAN ADD KhoaDen datetime2(0) NULL;
IF COL_LENGTH(N'dbo.TAIKHOAN', N'LanDangNhapCuoi') IS NULL
    ALTER TABLE dbo.TAIKHOAN ADD LanDangNhapCuoi datetime2(0) NULL;

IF OBJECT_ID(N'dbo.QUYEN',N'U') IS NULL
CREATE TABLE dbo.QUYEN (
    QuyenID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_QUYEN PRIMARY KEY,
    MaQuyen varchar(100) NOT NULL CONSTRAINT UQ_QUYEN_Ma UNIQUE,
    TenQuyen nvarchar(150) NOT NULL,
    NhomQuyen varchar(50) NOT NULL,
    MoTa nvarchar(500) NULL,
    TrangThai bit NOT NULL CONSTRAINT DF_QUYEN_TrangThai DEFAULT 1
);
IF OBJECT_ID(N'dbo.VAITRO_QUYEN',N'U') IS NULL
CREATE TABLE dbo.VAITRO_QUYEN (
    VaiTroID int NOT NULL,
    QuyenID int NOT NULL,
    DuocCap bit NOT NULL CONSTRAINT DF_VAITROQUYEN_DuocCap DEFAULT 1,
    NgayGan datetime2(0) NOT NULL CONSTRAINT DF_VAITROQUYEN_NgayGan DEFAULT SYSDATETIME(),
    CONSTRAINT PK_VAITRO_QUYEN PRIMARY KEY (VaiTroID, QuyenID),
    CONSTRAINT FK_VAITROQUYEN_VAITRO FOREIGN KEY (VaiTroID) REFERENCES dbo.VAITRO(VaiTroID),
    CONSTRAINT FK_VAITROQUYEN_QUYEN FOREIGN KEY (QuyenID) REFERENCES dbo.QUYEN(QuyenID)
);
IF OBJECT_ID(N'dbo.REFRESHTOKEN',N'U') IS NULL
CREATE TABLE dbo.REFRESHTOKEN (
    RefreshTokenID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_REFRESHTOKEN PRIMARY KEY,
    TaiKhoanID int NOT NULL,
    TokenHash varchar(255) NOT NULL CONSTRAINT UQ_REFRESHTOKEN_Hash UNIQUE,
    ExpiresAt datetime2(0) NOT NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_REFRESHTOKEN_Created DEFAULT SYSDATETIME(),
    RevokedAt datetime2(0) NULL,
    ReplacedByTokenHash varchar(255) NULL,
    CreatedByIp varchar(45) NULL,
    RevokedByIp varchar(45) NULL,
    CONSTRAINT FK_REFRESHTOKEN_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID),
    CONSTRAINT CK_REFRESHTOKEN_Expiry CHECK (ExpiresAt > CreatedAt)
);
IF OBJECT_ID(N'dbo.EXTERNALLOGIN',N'U') IS NULL
CREATE TABLE dbo.EXTERNALLOGIN (
    ExternalLoginID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_EXTERNALLOGIN PRIMARY KEY,
    TaiKhoanID int NOT NULL,
    Provider varchar(30) NOT NULL,
    ProviderUserID varchar(255) NOT NULL,
    Email varchar(255) NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_EXTERNALLOGIN_Created DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_EXTERNALLOGIN_ProviderUser UNIQUE (Provider, ProviderUserID),
    CONSTRAINT FK_EXTERNALLOGIN_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID)
);
IF OBJECT_ID(N'dbo.DANGNHAPLOG',N'U') IS NULL
CREATE TABLE dbo.DANGNHAPLOG (
    DangNhapLogID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DANGNHAPLOG PRIMARY KEY,
    TaiKhoanID int NULL,
    Email varchar(255) NULL,
    ThanhCong bit NOT NULL,
    LyDoThatBai varchar(100) NULL,
    IpAddress varchar(45) NULL,
    UserAgent nvarchar(500) NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_DANGNHAPLOG_Created DEFAULT SYSDATETIME(),
    CONSTRAINT FK_DANGNHAPLOG_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID)
);
IF OBJECT_ID(N'dbo.AUDITLOG',N'U') IS NULL
CREATE TABLE dbo.AUDITLOG (
    AuditLogID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AUDITLOG PRIMARY KEY,
    TaiKhoanID int NULL,
    ActionName varchar(100) NOT NULL,
    EntityName varchar(100) NULL,
    EntityID varchar(100) NULL,
    OldValues nvarchar(max) NULL,
    NewValues nvarchar(max) NULL,
    IpAddress varchar(45) NULL,
    UserAgent nvarchar(500) NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_AUDITLOG_Created DEFAULT SYSDATETIME(),
    CONSTRAINT FK_AUDITLOG_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID)
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.QUYEN WHERE MaQuyen = 'ACCOUNT.READ')
    INSERT dbo.QUYEN (MaQuyen,TenQuyen,NhomQuyen,MoTa) VALUES
    ('ACCOUNT.READ',N'Xem tài khoản','ACCOUNT',N'Xem thông tin tài khoản'),
    ('ACCOUNT.WRITE',N'Quản lý tài khoản','ACCOUNT',N'Tạo và cập nhật tài khoản'),
    ('ROLE.READ',N'Xem vai trò và quyền','AUTHORIZATION',N'Tra cứu vai trò, quyền'),
    ('ROLE.WRITE',N'Quản lý vai trò và quyền','AUTHORIZATION',N'Gán hoặc thu hồi quyền'),
    ('CUSTOMER.READ',N'Xem khách hàng','CUSTOMER',N'Tra cứu hồ sơ khách hàng'),
    ('CUSTOMER.WRITE',N'Quản lý khách hàng','CUSTOMER',N'Tạo, sửa hồ sơ khách hàng'),
    ('STAFF.READ',N'Xem nhân viên','STAFF',N'Tra cứu nhân viên'),
    ('STAFF.WRITE',N'Quản lý nhân viên','STAFF',N'Tạo, sửa, khóa nhân viên'),
    ('SERVICE.READ',N'Xem dịch vụ','SERVICE',N'Tra cứu dịch vụ và combo'),
    ('SERVICE.WRITE',N'Quản lý dịch vụ','SERVICE',N'Tạo, sửa, ngừng dịch vụ'),
    ('APPOINTMENT.READ',N'Xem lịch hẹn','APPOINTMENT',N'Tra cứu lịch hẹn'),
    ('APPOINTMENT.WRITE',N'Quản lý lịch hẹn','APPOINTMENT',N'Tạo, sửa, phân công, hủy lịch'),
    ('INVOICE.READ',N'Xem hóa đơn','BILLING',N'Tra cứu hóa đơn'),
    ('INVOICE.WRITE',N'Quản lý hóa đơn','BILLING',N'Lập và cập nhật hóa đơn'),
    ('PAYMENT.WRITE',N'Xử lý thanh toán','BILLING',N'Ghi nhận, xác nhận, hủy thanh toán'),
    ('PROMOTION.WRITE',N'Quản lý khuyến mãi','PROMOTION',N'Quản lý chương trình và voucher'),
    ('REVIEW.MODERATE',N'Duyệt đánh giá','REVIEW',N'Duyệt, ẩn hoặc xóa đánh giá'),
    ('REPORT.READ',N'Xem báo cáo','REPORT',N'Xem và xuất báo cáo');
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_REFRESHTOKEN_Account' AND object_id = OBJECT_ID(N'dbo.REFRESHTOKEN'))
    CREATE INDEX IX_REFRESHTOKEN_Account ON dbo.REFRESHTOKEN(TaiKhoanID, RevokedAt, ExpiresAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_DANGNHAPLOG_EmailTime' AND object_id = OBJECT_ID(N'dbo.DANGNHAPLOG'))
    CREATE INDEX IX_DANGNHAPLOG_EmailTime ON dbo.DANGNHAPLOG(Email, CreatedAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_AUDITLOG_AccountTime' AND object_id = OBJECT_ID(N'dbo.AUDITLOG'))
    CREATE INDEX IX_AUDITLOG_AccountTime ON dbo.AUDITLOG(TaiKhoanID, CreatedAt);
GO
IF OBJECT_ID(N'dbo.KHACHHANG',N'U') IS NULL
CREATE TABLE dbo.KHACHHANG (
    KhachHangID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_KHACHHANG PRIMARY KEY,
    TaiKhoanID int NULL,
    HoTen nvarchar(100) NOT NULL, SoDienThoai varchar(15) NULL,
    GioiTinh nvarchar(20) NULL, DiemThuong int NOT NULL CONSTRAINT DF_KHACHHANG_Diem DEFAULT 0,
    CONSTRAINT FK_KHACHHANG_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID)
);
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_KHACHHANG_TaiKhoan' AND parent_object_id = OBJECT_ID(N'dbo.KHACHHANG'))
    ALTER TABLE dbo.KHACHHANG DROP CONSTRAINT UQ_KHACHHANG_TaiKhoan;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_KHACHHANG_TaiKhoan' AND object_id = OBJECT_ID(N'dbo.KHACHHANG'))
    CREATE UNIQUE INDEX UQ_KHACHHANG_TaiKhoan ON dbo.KHACHHANG(TaiKhoanID) WHERE TaiKhoanID IS NOT NULL;

IF OBJECT_ID(N'dbo.NHANVIEN',N'U') IS NULL
CREATE TABLE dbo.NHANVIEN (
    NhanVienID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_NHANVIEN PRIMARY KEY,
    TaiKhoanID int NULL,
    HoTen nvarchar(100) NOT NULL, ChucVu nvarchar(50) NULL, ChuyenMon nvarchar(255) NULL,
    SoDienThoai varchar(15) NULL, NgayVaoLam date NULL,
    CONSTRAINT FK_NHANVIEN_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID)
);
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_NHANVIEN_TaiKhoan' AND parent_object_id = OBJECT_ID(N'dbo.NHANVIEN'))
    ALTER TABLE dbo.NHANVIEN DROP CONSTRAINT UQ_NHANVIEN_TaiKhoan;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_NHANVIEN_TaiKhoan' AND object_id = OBJECT_ID(N'dbo.NHANVIEN'))
    CREATE UNIQUE INDEX UQ_NHANVIEN_TaiKhoan ON dbo.NHANVIEN(TaiKhoanID) WHERE TaiKhoanID IS NOT NULL;
IF OBJECT_ID(N'dbo.LICHLAMVIEC',N'U') IS NULL
CREATE TABLE dbo.LICHLAMVIEC (
    LichLamViecID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_LICHLAMVIEC PRIMARY KEY,
    NhanVienID int NOT NULL, NgayLam date NOT NULL, GioBatDau time(0) NOT NULL, GioKetThuc time(0) NOT NULL,
    TrangThai nvarchar(30) NULL,
    CONSTRAINT FK_LICHLAMVIEC_NHANVIEN FOREIGN KEY (NhanVienID) REFERENCES dbo.NHANVIEN(NhanVienID),
    CONSTRAINT CK_LICHLAMVIEC_Gio CHECK (GioKetThuc > GioBatDau)
);
IF OBJECT_ID(N'dbo.LOAIDICHVU',N'U') IS NULL
CREATE TABLE dbo.LOAIDICHVU (
    LoaiDichVuID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_LOAIDICHVU PRIMARY KEY,
    TenLoai nvarchar(100) NOT NULL, MoTa nvarchar(255) NULL, TrangThai bit NOT NULL DEFAULT 1
);
IF OBJECT_ID(N'dbo.DICHVU',N'U') IS NULL
CREATE TABLE dbo.DICHVU (
    DichVuID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DICHVU PRIMARY KEY,
    LoaiDichVuID int NOT NULL, TenDichVu nvarchar(150) NOT NULL, Gia decimal(18,2) NOT NULL,
    ThoiLuongPhut int NOT NULL, MoTa nvarchar(1000) NULL, TrangThai bit NOT NULL DEFAULT 1,
    CONSTRAINT FK_DICHVU_LOAI FOREIGN KEY (LoaiDichVuID) REFERENCES dbo.LOAIDICHVU(LoaiDichVuID),
    CONSTRAINT CK_DICHVU_Gia CHECK (Gia >= 0), CONSTRAINT CK_DICHVU_ThoiLuong CHECK (ThoiLuongPhut > 0)
);
IF OBJECT_ID(N'dbo.COMBODICHVU',N'U') IS NULL
CREATE TABLE dbo.COMBODICHVU (
    ComboID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_COMBODICHVU PRIMARY KEY,
    TenCombo nvarchar(150) NOT NULL, GiaCombo decimal(18,2) NOT NULL,
    NgayBatDauHieuLuc date NULL, NgayKetThucHieuLuc date NULL, TrangThai bit NOT NULL DEFAULT 1,
    CONSTRAINT CK_COMBO_Gia CHECK (GiaCombo >= 0),
    CONSTRAINT CK_COMBO_Ngay CHECK (NgayKetThucHieuLuc IS NULL OR NgayBatDauHieuLuc IS NULL OR NgayKetThucHieuLuc >= NgayBatDauHieuLuc)
);
IF OBJECT_ID(N'dbo.CHITIETCOMBO',N'U') IS NULL
CREATE TABLE dbo.CHITIETCOMBO (
    ComboChiTietID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CHITIETCOMBO PRIMARY KEY,
    ComboID int NOT NULL, DichVuID int NOT NULL, SoLuong int NOT NULL DEFAULT 1,
    CONSTRAINT UQ_CHITIETCOMBO UNIQUE (ComboID,DichVuID),
    CONSTRAINT FK_CTCOMBO_COMBO FOREIGN KEY (ComboID) REFERENCES dbo.COMBODICHVU(ComboID),
    CONSTRAINT FK_CTCOMBO_DICHVU FOREIGN KEY (DichVuID) REFERENCES dbo.DICHVU(DichVuID),
    CONSTRAINT CK_CTCOMBO_SoLuong CHECK (SoLuong > 0)
);
IF OBJECT_ID(N'dbo.LICHHEN',N'U') IS NULL
CREATE TABLE dbo.LICHHEN (
    LichHenID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_LICHHEN PRIMARY KEY,
    KhachHangID int NOT NULL, NhanVienID int NULL, NgayGioHen datetime2(0) NOT NULL,
    GioKetThucDuKien time(0) NULL, TrangThai nvarchar(30) NOT NULL DEFAULT N'ChoXacNhan', GhiChu nvarchar(1000) NULL,
    CONSTRAINT FK_LICHHEN_KHACH FOREIGN KEY (KhachHangID) REFERENCES dbo.KHACHHANG(KhachHangID),
    CONSTRAINT FK_LICHHEN_NHANVIEN FOREIGN KEY (NhanVienID) REFERENCES dbo.NHANVIEN(NhanVienID)
);
IF OBJECT_ID(N'dbo.CHITIETLICHHEN',N'U') IS NULL
CREATE TABLE dbo.CHITIETLICHHEN (
    ChiTietLichHenID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CHITIETLICHHEN PRIMARY KEY,
    LichHenID int NOT NULL, DichVuID int NOT NULL, ComboID int NULL,
    ThoiLuongThucTe int NULL, GiaDuKien decimal(18,2) NOT NULL,
    CONSTRAINT FK_CTLICH_LICHHEN FOREIGN KEY (LichHenID) REFERENCES dbo.LICHHEN(LichHenID),
    CONSTRAINT FK_CTLICH_DICHVU FOREIGN KEY (DichVuID) REFERENCES dbo.DICHVU(DichVuID),
    CONSTRAINT FK_CTLICH_COMBO FOREIGN KEY (ComboID) REFERENCES dbo.COMBODICHVU(ComboID)
);
IF OBJECT_ID(N'dbo.KHUYENMAI',N'U') IS NULL
CREATE TABLE dbo.KHUYENMAI (
    KhuyenMaiID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_KHUYENMAI PRIMARY KEY,
    TenKhuyenMai nvarchar(150) NOT NULL, LoaiGiam nvarchar(30) NOT NULL, MucGiam decimal(18,2) NOT NULL,
    DieuKienApDung nvarchar(1000) NULL, NgayBatDauHieuLuc datetime2(0) NULL, NgayKetThucHieuLuc datetime2(0) NULL,
    CONSTRAINT CK_KM_MucGiam CHECK (MucGiam >= 0)
);
IF OBJECT_ID(N'dbo.VOUCHER',N'U') IS NULL
CREATE TABLE dbo.VOUCHER (
    VoucherID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_VOUCHER PRIMARY KEY,
    MaCode varchar(30) NOT NULL CONSTRAINT UQ_VOUCHER_MaCode UNIQUE, KhuyenMaiID int NOT NULL, KhachHangID int NULL,
    GiaTriGiam decimal(18,2) NOT NULL, HanSuDung datetime2(0) NOT NULL, TrangThai bit NOT NULL DEFAULT 1,
    CONSTRAINT FK_VOUCHER_KM FOREIGN KEY (KhuyenMaiID) REFERENCES dbo.KHUYENMAI(KhuyenMaiID),
    CONSTRAINT FK_VOUCHER_KHACH FOREIGN KEY (KhachHangID) REFERENCES dbo.KHACHHANG(KhachHangID)
);
IF OBJECT_ID(N'dbo.HOADON',N'U') IS NULL
CREATE TABLE dbo.HOADON (
    HoaDonID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_HOADON PRIMARY KEY,
    LichHenID int NOT NULL, KhachHangID int NOT NULL, NgayLap datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
    TongTienTruocGiam decimal(18,2) NOT NULL DEFAULT 0, TongTienSauGiam decimal(18,2) NOT NULL DEFAULT 0,
    TrangThai nvarchar(30) NOT NULL DEFAULT N'ChuaThanhToan',
    CONSTRAINT FK_HOADON_LICHHEN FOREIGN KEY (LichHenID) REFERENCES dbo.LICHHEN(LichHenID),
    CONSTRAINT FK_HOADON_KHACH FOREIGN KEY (KhachHangID) REFERENCES dbo.KHACHHANG(KhachHangID)
);
IF OBJECT_ID(N'dbo.CHITIETHOADON',N'U') IS NULL
CREATE TABLE dbo.CHITIETHOADON (
    HoaDonChiTietID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CHITIETHOADON PRIMARY KEY,
    HoaDonID int NOT NULL, DichVuID int NULL, ComboID int NULL, SoLuong int NOT NULL DEFAULT 1, DonGia decimal(18,2) NOT NULL,
    CONSTRAINT FK_CTHD_HOADON FOREIGN KEY (HoaDonID) REFERENCES dbo.HOADON(HoaDonID),
    CONSTRAINT FK_CTHD_DICHVU FOREIGN KEY (DichVuID) REFERENCES dbo.DICHVU(DichVuID),
    CONSTRAINT FK_CTHD_COMBO FOREIGN KEY (ComboID) REFERENCES dbo.COMBODICHVU(ComboID),
    CONSTRAINT CK_CTHD_MotLoai CHECK ((DichVuID IS NOT NULL AND ComboID IS NULL) OR (DichVuID IS NULL AND ComboID IS NOT NULL))
);
IF OBJECT_ID(N'dbo.THANHTOAN',N'U') IS NULL
CREATE TABLE dbo.THANHTOAN (
    ThanhToanID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_THANHTOAN PRIMARY KEY,
    HoaDonID int NOT NULL, PhuongThuc nvarchar(30) NOT NULL, SoTien decimal(18,2) NOT NULL,
    NgayGioThanhToan datetime2(0) NULL, TrangThai nvarchar(30) NOT NULL DEFAULT N'ChoXuLy',
    CONSTRAINT FK_THANHTOAN_HOADON FOREIGN KEY (HoaDonID) REFERENCES dbo.HOADON(HoaDonID), CONSTRAINT CK_TT_SoTien CHECK (SoTien > 0)
);
IF OBJECT_ID(N'dbo.DANHGIA',N'U') IS NULL
CREATE TABLE dbo.DANHGIA (
    DanhGiaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DANHGIA PRIMARY KEY,
    HoaDonID int NOT NULL, SoSao tinyint NOT NULL, BinhLuan nvarchar(1000) NULL, NgayDanhGia datetime2(0) NOT NULL DEFAULT SYSDATETIME(), TrangThai nvarchar(30) NOT NULL DEFAULT N'ChoDuyet',
    CONSTRAINT FK_DANHGIA_HOADON FOREIGN KEY (HoaDonID) REFERENCES dbo.HOADON(HoaDonID), CONSTRAINT CK_DG_SoSao CHECK (SoSao BETWEEN 1 AND 5)
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DANHGIA') AND name = N'UX_DANHGIA_HoaDonID')
    CREATE UNIQUE INDEX UX_DANHGIA_HoaDonID ON dbo.DANHGIA(HoaDonID);
IF OBJECT_ID(N'dbo.GIAODICHDIEM',N'U') IS NULL
CREATE TABLE dbo.GIAODICHDIEM (
    GiaoDichID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_GIAODICHDIEM PRIMARY KEY,
    KhachHangID int NOT NULL, HoaDonID int NULL, SoDiem int NOT NULL, LoaiGiaoDich nvarchar(20) NOT NULL,
    NgayGiaoDich datetime2(0) NOT NULL DEFAULT SYSDATETIME(), GhiChu nvarchar(500) NULL,
    CONSTRAINT FK_GD_DIEM_KHACH FOREIGN KEY (KhachHangID) REFERENCES dbo.KHACHHANG(KhachHangID),
    CONSTRAINT FK_GD_DIEM_HOADON FOREIGN KEY (HoaDonID) REFERENCES dbo.HOADON(HoaDonID)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_LICHHEN_NgayGio' AND object_id = OBJECT_ID(N'dbo.LICHHEN'))
    CREATE INDEX IX_LICHHEN_NgayGio ON dbo.LICHHEN(NgayGioHen,TrangThai);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_HOADON_NgayLap' AND object_id = OBJECT_ID(N'dbo.HOADON'))
    CREATE INDEX IX_HOADON_NgayLap ON dbo.HOADON(NgayLap,TrangThai);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_DICHVU_Loai' AND object_id = OBJECT_ID(N'dbo.DICHVU'))
    CREATE INDEX IX_DICHVU_Loai ON dbo.DICHVU(LoaiDichVuID,TrangThai);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_GD_DIEM_Khach' AND object_id = OBJECT_ID(N'dbo.GIAODICHDIEM'))
    CREATE INDEX IX_GD_DIEM_Khach ON dbo.GIAODICHDIEM(KhachHangID,NgayGiaoDich);
GO


IF COL_LENGTH(N'dbo.TAIKHOAN', N'SecurityStamp') IS NULL
    ALTER TABLE dbo.TAIKHOAN ADD SecurityStamp varchar(32) NULL;
IF COL_LENGTH(N'dbo.REFRESHTOKEN', N'SecurityStamp') IS NULL
    ALTER TABLE dbo.REFRESHTOKEN ADD SecurityStamp varchar(32) NULL;
IF OBJECT_ID(N'dbo.PASSWORDRESETCHALLENGE', N'U') IS NULL
CREATE TABLE dbo.PASSWORDRESETCHALLENGE (
    TaiKhoanID int NOT NULL CONSTRAINT PK_PASSWORDRESETCHALLENGE PRIMARY KEY,
    ChallengeId varchar(32) NOT NULL,
    Version varchar(32) NOT NULL,
    OtpHash varchar(64) NULL,
    ExpiresAt datetime2(7) NOT NULL,
    Attempts int NOT NULL,
    LastRequestedAt datetime2(7) NOT NULL,
    SendWindowStartedAt datetime2(7) NOT NULL,
    SendCount int NOT NULL,
    UsedAt datetime2(7) NULL,
    SecurityStampAtIssue varchar(32) NULL,
    CONSTRAINT FK_PASSWORDRESET_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID) ON DELETE CASCADE,
    CONSTRAINT CK_PASSWORDRESET_Attempts CHECK (Attempts BETWEEN 0 AND 5),
    CONSTRAINT CK_PASSWORDRESET_SendCount CHECK (SendCount BETWEEN 0 AND 5)
);
GO

GO
-- Notifications upgrade (also safe on an existing database).
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.ThietBiKhachHang', N'U') IS NULL
CREATE TABLE dbo.ThietBiKhachHang (
    Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ThietBiKhachHang PRIMARY KEY,
    TaiKhoanId int NOT NULL, KhachHangId int NULL,
    FcmToken nvarchar(500) COLLATE Latin1_General_100_BIN2 NOT NULL,
    LoaiThietBi nvarchar(50) NULL,
    NgayCapNhat datetime2(7) NOT NULL CONSTRAINT DF_ThietBi_CapNhat DEFAULT SYSUTCDATETIME(),
    TrangThai bit NOT NULL CONSTRAINT DF_ThietBi_TrangThai DEFAULT 1,
    CONSTRAINT FK_ThietBi_TaiKhoan FOREIGN KEY(TaiKhoanId) REFERENCES dbo.TAIKHOAN(TaiKhoanID),
    CONSTRAINT FK_ThietBi_KhachHang FOREIGN KEY(KhachHangId) REFERENCES dbo.KHACHHANG(KhachHangID)
);
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ThietBiKhachHang') AND name=N'FcmToken' AND collation_name <> N'Latin1_General_100_BIN2')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThietBiKhachHang') AND name=N'IX_ThietBi_Token')
        DROP INDEX IX_ThietBi_Token ON dbo.ThietBiKhachHang;
    ALTER TABLE dbo.ThietBiKhachHang ALTER COLUMN FcmToken nvarchar(500) COLLATE Latin1_General_100_BIN2 NOT NULL;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThietBiKhachHang') AND name=N'IX_ThietBi_Token')
    CREATE UNIQUE INDEX IX_ThietBi_Token ON dbo.ThietBiKhachHang(FcmToken);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThietBiKhachHang') AND name=N'IX_ThietBi_TaiKhoan')
    CREATE INDEX IX_ThietBi_TaiKhoan ON dbo.ThietBiKhachHang(TaiKhoanId);

IF OBJECT_ID(N'dbo.ThongBao', N'U') IS NULL
CREATE TABLE dbo.ThongBao (
    ThongBaoId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ThongBao PRIMARY KEY,
    TaiKhoanId int NULL, KhachHangId int NULL,
    TieuDe nvarchar(250) NOT NULL, NoiDung nvarchar(1000) NOT NULL,
    LoaiThongBao nvarchar(50) NOT NULL, DuLieuKemTheo nvarchar(max) NULL,
    NgayTao datetime2(7) NOT NULL CONSTRAINT DF_ThongBao_NgayTao DEFAULT SYSUTCDATETIME(),
    PushStatus varchar(20) NOT NULL CONSTRAINT DF_ThongBao_PushStatus DEFAULT 'Pending',
    PushAttempts int NOT NULL CONSTRAINT DF_ThongBao_PushAttempts DEFAULT 0,
    NextPushAt datetime2(7) NOT NULL CONSTRAINT DF_ThongBao_NextPushAt DEFAULT SYSUTCDATETIME(),
    PushLeaseId varchar(32) NULL, PushLeaseUntil datetime2(7) NULL,
    CONSTRAINT FK_ThongBao_TaiKhoan FOREIGN KEY(TaiKhoanId) REFERENCES dbo.TAIKHOAN(TaiKhoanID),
    CONSTRAINT FK_ThongBao_KhachHang FOREIGN KEY(KhachHangId) REFERENCES dbo.KHACHHANG(KhachHangID)
);
-- Upgrade an existing copy of the proposal's schema without re-pushing old inbox entries.
IF COL_LENGTH(N'dbo.ThongBao', N'PushStatus') IS NULL
BEGIN
    ALTER TABLE dbo.ThongBao ADD PushStatus varchar(20) NOT NULL CONSTRAINT DF_ThongBao_PushStatus DEFAULT 'Skipped' WITH VALUES;
    ALTER TABLE dbo.ThongBao DROP CONSTRAINT DF_ThongBao_PushStatus;
    ALTER TABLE dbo.ThongBao ADD CONSTRAINT DF_ThongBao_PushStatus DEFAULT 'Pending' FOR PushStatus;
END;
IF COL_LENGTH(N'dbo.ThongBao', N'PushAttempts') IS NULL
    ALTER TABLE dbo.ThongBao ADD PushAttempts int NOT NULL CONSTRAINT DF_ThongBao_PushAttempts DEFAULT 0;
IF COL_LENGTH(N'dbo.ThongBao', N'NextPushAt') IS NULL
    ALTER TABLE dbo.ThongBao ADD NextPushAt datetime2(7) NOT NULL CONSTRAINT DF_ThongBao_NextPushAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'dbo.ThongBao', N'PushLeaseId') IS NULL
    ALTER TABLE dbo.ThongBao ADD PushLeaseId varchar(32) NULL;
IF COL_LENGTH(N'dbo.ThongBao', N'PushLeaseUntil') IS NULL
    ALTER TABLE dbo.ThongBao ADD PushLeaseUntil datetime2(7) NULL;
-- Dynamic SQL compiles after new columns have been added on existing databases.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThongBao') AND name=N'IX_ThongBao_Push')
    EXEC(N'CREATE INDEX IX_ThongBao_Push ON dbo.ThongBao(PushStatus, NextPushAt)');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThongBao') AND name=N'IX_ThongBao_TaiKhoan')
    CREATE INDEX IX_ThongBao_TaiKhoan ON dbo.ThongBao(TaiKhoanId, NgayTao DESC);

IF OBJECT_ID(N'dbo.ThongBaoDaDoc', N'U') IS NULL
CREATE TABLE dbo.ThongBaoDaDoc (
    ThongBaoId int NOT NULL, TaiKhoanId int NOT NULL,
    NgayDoc datetime2(7) NOT NULL CONSTRAINT DF_ThongBaoDaDoc_NgayDoc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ThongBaoDaDoc PRIMARY KEY(ThongBaoId, TaiKhoanId),
    CONSTRAINT FK_ThongBaoDaDoc_ThongBao FOREIGN KEY(ThongBaoId) REFERENCES dbo.ThongBao(ThongBaoId) ON DELETE CASCADE,
    CONSTRAINT FK_ThongBaoDaDoc_TaiKhoan FOREIGN KEY(TaiKhoanId) REFERENCES dbo.TAIKHOAN(TaiKhoanID)
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThongBaoDaDoc') AND name=N'IX_ThongBaoDaDoc_TaiKhoan')
    CREATE INDEX IX_ThongBaoDaDoc_TaiKhoan ON dbo.ThongBaoDaDoc(TaiKhoanId, ThongBaoId);
-- Preserve legacy private read flags. A broadcast flag is not a per-account receipt.
IF COL_LENGTH(N'dbo.ThongBao', N'DaDoc') IS NOT NULL
    EXEC(N'INSERT dbo.ThongBaoDaDoc(ThongBaoId,TaiKhoanId,NgayDoc)
        SELECT n.ThongBaoId,n.TaiKhoanId,SYSUTCDATETIME() FROM dbo.ThongBao n
        WHERE n.DaDoc=1 AND n.TaiKhoanId IS NOT NULL
        AND NOT EXISTS(SELECT 1 FROM dbo.ThongBaoDaDoc r WHERE r.ThongBaoId=n.ThongBaoId AND r.TaiKhoanId=n.TaiKhoanId)');
-- Optimistic concurrency keeps one committed business change and its notification together.
IF COL_LENGTH(N'dbo.LICHHEN', N'RowVersion') IS NULL
    ALTER TABLE dbo.LICHHEN ADD RowVersion rowversion NOT NULL;
IF COL_LENGTH(N'dbo.HOADON', N'RowVersion') IS NULL
    ALTER TABLE dbo.HOADON ADD RowVersion rowversion NOT NULL;
COMMIT TRANSACTION;
GO

-- Integrated migration: 07_ServiceImages.sql
USE [KLCN021_HealthBeauty];
GO
-- Anh minh hoa dich vu/combo. Chay lai an toan; khong sua du lieu hien co.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'dbo.DICHVU', N'ImageUrl') IS NULL
    ALTER TABLE dbo.DICHVU ADD ImageUrl nvarchar(2048) NULL;
IF COL_LENGTH(N'dbo.COMBODICHVU', N'ImageUrl') IS NULL
    ALTER TABLE dbo.COMBODICHVU ADD ImageUrl nvarchar(2048) NULL;
COMMIT TRANSACTION;

GO

-- Integrated migration: 08_AppointmentReminders.sql
-- Nhắc lịch tự động: khóa sự kiện chống trùng khi chạy lại/nhiều worker.
-- Chạy sau 06_Notifications.sql; không chèn hoặc xóa dữ liệu nghiệp vụ.
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.ThongBao', N'U') IS NULL
    THROW 51000, 'Run 06_Notifications.sql first.', 1;
IF COL_LENGTH(N'dbo.ThongBao', N'EventKey') IS NULL
    ALTER TABLE dbo.ThongBao ADD EventKey varchar(150) NULL;
-- Dynamic SQL allows first-time column addition and index creation in the same batch.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ThongBao') AND name=N'UX_ThongBao_EventKey')
    EXEC(N'CREATE UNIQUE INDEX UX_ThongBao_EventKey ON dbo.ThongBao(EventKey) WHERE EventKey IS NOT NULL');
COMMIT TRANSACTION;
GO

-- Integrated migration: 09_LoyaltyConsistency.sql
USE [KLCN021_HealthBeauty];
GO
-- Reward balance, voucher and invoice concurrency safety. Repeatable migration.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS (SELECT LichHenID FROM dbo.HOADON GROUP BY LichHenID HAVING COUNT(*) > 1)
BEGIN
    ROLLBACK TRANSACTION;
    THROW 51009, N'Duplicate appointment invoices exist. Reconcile manually; no historical data was deleted.', 1;
END;
IF COL_LENGTH(N'dbo.KHACHHANG', N'RowVersion') IS NULL
    ALTER TABLE dbo.KHACHHANG ADD RowVersion rowversion NOT NULL;
IF COL_LENGTH(N'dbo.VOUCHER', N'RowVersion') IS NULL
    ALTER TABLE dbo.VOUCHER ADD RowVersion rowversion NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.HOADON') AND name = N'UX_HOADON_LichHenID')
    CREATE UNIQUE INDEX UX_HOADON_LichHenID ON dbo.HOADON(LichHenID);
COMMIT TRANSACTION;
GO

-- Integrated migration: 10_VoucherPointExchange.sql
USE [KLCN021_HealthBeauty];
GO
-- Configurable point cost for one-use voucher codes. Existing vouchers remain free.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'dbo.VOUCHER', N'PointsCost') IS NULL
    ALTER TABLE dbo.VOUCHER ADD PointsCost int NOT NULL CONSTRAINT DF_VOUCHER_PointsCost DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.VOUCHER', N'RedeemedAt') IS NULL
    ALTER TABLE dbo.VOUCHER ADD RedeemedAt datetime2(0) NULL;
IF COL_LENGTH(N'dbo.VOUCHER', N'UsedAt') IS NULL
    ALTER TABLE dbo.VOUCHER ADD UsedAt datetime2(0) NULL;
IF COL_LENGTH(N'dbo.GIAODICHDIEM', N'VoucherID') IS NULL
    ALTER TABLE dbo.GIAODICHDIEM ADD VoucherID int NULL;
COMMIT TRANSACTION;
GO
-- New columns must be compiled after the preceding batch.
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.GIAODICHDIEM') AND name = N'FK_GD_DIEM_VOUCHER')
    ALTER TABLE dbo.GIAODICHDIEM WITH CHECK ADD CONSTRAINT FK_GD_DIEM_VOUCHER FOREIGN KEY (VoucherID) REFERENCES dbo.VOUCHER(VoucherID);

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.VOUCHER') AND name = N'CK_VOUCHER_PointsCost')
    ALTER TABLE dbo.VOUCHER WITH CHECK ADD CONSTRAINT CK_VOUCHER_PointsCost CHECK (PointsCost BETWEEN 0 AND 1000000);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.VOUCHER') AND name = N'CK_VOUCHER_PointOwnership')
    ALTER TABLE dbo.VOUCHER WITH CHECK ADD CONSTRAINT CK_VOUCHER_PointOwnership CHECK
        (PointsCost = 0 OR (KhachHangID IS NULL AND RedeemedAt IS NULL) OR (KhachHangID IS NOT NULL AND RedeemedAt IS NOT NULL));
GO

-- Integrated migration: 11_ReviewManagement.sql
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'dbo.DANHGIA', N'IsDeleted') IS NULL
    ALTER TABLE dbo.DANHGIA ADD IsDeleted bit NOT NULL CONSTRAINT DF_DANHGIA_IsDeleted DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.DANHGIA', N'Reply') IS NULL
    ALTER TABLE dbo.DANHGIA ADD Reply nvarchar(2000) NULL;
IF COL_LENGTH(N'dbo.DANHGIA', N'ReplyAccountId') IS NULL
    ALTER TABLE dbo.DANHGIA ADD ReplyAccountId int NULL;
IF COL_LENGTH(N'dbo.DANHGIA', N'RepliedAt') IS NULL
    ALTER TABLE dbo.DANHGIA ADD RepliedAt datetime2(0) NULL;
IF COL_LENGTH(N'dbo.DANHGIA', N'Version') IS NULL
    ALTER TABLE dbo.DANHGIA ADD Version uniqueidentifier NOT NULL CONSTRAINT DF_DANHGIA_Version DEFAULT (NEWID()) WITH VALUES;
COMMIT TRANSACTION;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.DANHGIA') AND name = N'FK_DANHGIA_ReplyAccount')
    ALTER TABLE dbo.DANHGIA WITH CHECK ADD CONSTRAINT FK_DANHGIA_ReplyAccount FOREIGN KEY (ReplyAccountId) REFERENCES dbo.TAIKHOAN(TaiKhoanID);
GO

-- Integrated migration: 12_ReportingCustomerCreatedAt.sql
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
-- No WITH VALUES: historical customers retain NULL, not fabricated creation dates.
IF COL_LENGTH(N'dbo.KHACHHANG', N'CreatedAt') IS NULL
    ALTER TABLE dbo.KHACHHANG ADD CreatedAt datetime2(0) NULL CONSTRAINT DF_KHACHHANG_CreatedAt DEFAULT (SYSDATETIME());
COMMIT TRANSACTION;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.KHACHHANG') AND name = N'IX_KHACHHANG_CreatedAt')
    CREATE INDEX IX_KHACHHANG_CreatedAt ON dbo.KHACHHANG(CreatedAt);
GO
