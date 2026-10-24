-- Optional customer login OTP. Run before enabling Authentication:TwoFactor:Enabled.
-- Safe to rerun; no existing account, session, or password-recovery data is changed.
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.LOGINTWOFACTORCHALLENGE', N'U') IS NULL
CREATE TABLE dbo.LOGINTWOFACTORCHALLENGE (
    TaiKhoanID int NOT NULL CONSTRAINT PK_LOGINTWOFACTORCHALLENGE PRIMARY KEY,
    ChallengeId varchar(32) NOT NULL,
    Version varchar(32) NOT NULL,
    OtpHash varchar(64) NULL,
    PasswordVerifiedAt datetime2(7) NOT NULL,
    ExpiresAt datetime2(7) NOT NULL,
    Attempts int NOT NULL,
    LastRequestedAt datetime2(7) NOT NULL,
    SendWindowStartedAt datetime2(7) NOT NULL,
    SendCount int NOT NULL,
    UsedAt datetime2(7) NULL,
    SecurityStampAtIssue varchar(32) NULL,
    CONSTRAINT FK_LOGINTWOFACTOR_TAIKHOAN FOREIGN KEY (TaiKhoanID) REFERENCES dbo.TAIKHOAN(TaiKhoanID) ON DELETE CASCADE,
    CONSTRAINT CK_LOGINTWOFACTOR_Attempts CHECK (Attempts BETWEEN 0 AND 5),
    CONSTRAINT CK_LOGINTWOFACTOR_SendCount CHECK (SendCount BETWEEN 0 AND 5),
    CONSTRAINT CK_LOGINTWOFACTOR_Expiry CHECK (ExpiresAt > PasswordVerifiedAt AND ExpiresAt <= DATEADD(minute,5,PasswordVerifiedAt))
);
COMMIT TRANSACTION;
GO
