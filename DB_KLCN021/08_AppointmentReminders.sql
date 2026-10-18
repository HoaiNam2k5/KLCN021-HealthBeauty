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
