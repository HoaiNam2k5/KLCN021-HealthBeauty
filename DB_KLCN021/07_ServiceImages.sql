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
