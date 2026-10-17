-- Notification inbox, device registration, per-account read receipts and durable push delivery.
USE [KLCN021_HealthBeauty];
GO
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
