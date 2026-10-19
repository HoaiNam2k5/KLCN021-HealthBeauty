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
