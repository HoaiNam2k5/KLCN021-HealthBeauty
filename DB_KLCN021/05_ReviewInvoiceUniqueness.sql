-- Enforce one review per invoice, including hidden and pending reviews.
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS (SELECT HoaDonID FROM dbo.DANHGIA GROUP BY HoaDonID HAVING COUNT(*) > 1)
BEGIN
    ROLLBACK TRANSACTION;
    THROW 50001, 'Duplicate invoice reviews exist. Resolve them before applying this migration; no reviews were deleted.', 1;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DANHGIA') AND name = N'UX_DANHGIA_HoaDonID')
    CREATE UNIQUE INDEX UX_DANHGIA_HoaDonID ON dbo.DANHGIA(HoaDonID);
COMMIT TRANSACTION;
GO
