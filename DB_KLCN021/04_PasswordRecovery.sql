-- Password recovery persistence and immediate invalidation of old access tokens.
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
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
COMMIT TRANSACTION;
GO
