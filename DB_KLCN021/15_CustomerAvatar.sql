USE [KLCN021_HealthBeauty];
GO
-- Có thể chạy lại: chỉ bổ sung cột, không đổi dữ liệu hoặc ảnh đang có.
IF OBJECT_ID(N'dbo.KHACHHANG', N'U') IS NULL
    THROW 50000, N'Chưa có bảng KHACHHANG. Hãy tạo database/schema trước.', 1;
GO
IF COL_LENGTH(N'dbo.KHACHHANG', N'AvatarUrl') IS NULL
    ALTER TABLE dbo.KHACHHANG ADD AvatarUrl nvarchar(2048) NULL;
GO
