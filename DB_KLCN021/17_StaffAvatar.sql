-- Run only after review/approval, with sqlcmd -d KLCN021_HealthBeauty -b.
-- Adds one nullable column; preserves every existing row and value. Safe to rerun.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'KLCN021_HealthBeauty'
    THROW 50001, N'Wrong database. Connect explicitly to KLCN021_HealthBeauty.', 1;
IF OBJECT_ID(N'dbo.NHANVIEN', N'U') IS NULL
    THROW 50002, N'Expected dbo.NHANVIEN does not exist. No changes were made.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    IF COL_LENGTH(N'dbo.NHANVIEN', N'AvatarUrl') IS NULL
        ALTER TABLE dbo.NHANVIEN ADD AvatarUrl nvarchar(2048) NULL;
    ELSE IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.NHANVIEN', N'U') AND name = N'AvatarUrl'
          AND system_type_id = TYPE_ID(N'nvarchar') AND max_length = 4096 AND is_nullable = 1
    )
        THROW 50003, N'Existing AvatarUrl has an unexpected definition. It was not altered.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT DB_NAME() AS DatabaseName, N'dbo.NHANVIEN.AvatarUrl' AS ColumnName,
       COL_LENGTH(N'dbo.NHANVIEN', N'AvatarUrl') AS MaximumBytes;