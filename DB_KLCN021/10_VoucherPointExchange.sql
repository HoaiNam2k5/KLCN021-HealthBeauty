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
