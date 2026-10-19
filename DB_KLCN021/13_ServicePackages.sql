USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'dbo.ServicePackage',N'U') IS NULL
CREATE TABLE dbo.ServicePackage(Id int IDENTITY PRIMARY KEY,Name nvarchar(200) NOT NULL,Price decimal(18,2) NOT NULL CHECK(Price>0 AND Price<=1000000000),ValidityDays int NOT NULL CHECK(ValidityDays BETWEEN 1 AND 3650),Active bit NOT NULL DEFAULT(1),ImageUrl nvarchar(2048) NULL,Version uniqueidentifier NOT NULL DEFAULT NEWID());
GO
IF OBJECT_ID(N'dbo.ServicePackageItem',N'U') IS NULL
CREATE TABLE dbo.ServicePackageItem(Id int IDENTITY PRIMARY KEY,ServicePackageId int NOT NULL REFERENCES dbo.ServicePackage(Id) ON DELETE CASCADE,ServiceId int NOT NULL REFERENCES dbo.DICHVU(DichVuID),Sessions int NOT NULL CHECK(Sessions BETWEEN 1 AND 10000),CONSTRAINT UX_ServicePackageItem UNIQUE(ServicePackageId,ServiceId));
GO
IF OBJECT_ID(N'dbo.CustomerPackage',N'U') IS NULL
CREATE TABLE dbo.CustomerPackage(Id int IDENTITY PRIMARY KEY,ServicePackageId int NOT NULL REFERENCES dbo.ServicePackage(Id),CustomerId int NOT NULL REFERENCES dbo.KHACHHANG(KhachHangID),Name nvarchar(200) NOT NULL,Price decimal(18,2) NOT NULL CHECK(Price>0 AND Price<=1000000000),ValidityDays int NOT NULL CHECK(ValidityDays BETWEEN 1 AND 3650),Status nvarchar(20) NOT NULL DEFAULT N'Pending' CHECK(Status IN(N'Pending',N'Paid',N'Cancelled')),CreatedAt datetime2 NOT NULL,PaidAt datetime2 NULL,ExpiresAt datetime2 NULL,PaymentMethod nvarchar(30) NULL,PaidByAccountId int NULL REFERENCES dbo.TAIKHOAN(TaiKhoanID),Version uniqueidentifier NOT NULL DEFAULT NEWID(),CONSTRAINT CK_CustomerPackage_Paid CHECK((Status=N'Paid' AND PaidAt IS NOT NULL AND ExpiresAt IS NOT NULL AND ExpiresAt>PaidAt AND PaymentMethod IS NOT NULL AND PaidByAccountId IS NOT NULL) OR (Status<>N'Paid' AND PaidAt IS NULL AND ExpiresAt IS NULL AND PaymentMethod IS NULL AND PaidByAccountId IS NULL)));
GO
IF OBJECT_ID(N'dbo.CustomerPackageItem',N'U') IS NULL
CREATE TABLE dbo.CustomerPackageItem(Id int IDENTITY PRIMARY KEY,CustomerPackageId int NOT NULL REFERENCES dbo.CustomerPackage(Id),ServiceId int NOT NULL REFERENCES dbo.DICHVU(DichVuID),ServiceName nvarchar(200) NOT NULL,Granted int NOT NULL CHECK(Granted BETWEEN 1 AND 10000),Reserved int NOT NULL DEFAULT(0),Used int NOT NULL DEFAULT(0),Version uniqueidentifier NOT NULL DEFAULT NEWID(),CONSTRAINT UX_CustomerPackageItem UNIQUE(CustomerPackageId,ServiceId),CONSTRAINT CK_CustomerPackageItem_Balance CHECK(Reserved>=0 AND Used>=0 AND Reserved+Used<=Granted));
GO
IF OBJECT_ID(N'dbo.PackageUsage',N'U') IS NULL
CREATE TABLE dbo.PackageUsage(Id int IDENTITY PRIMARY KEY,CustomerPackageItemId int NOT NULL REFERENCES dbo.CustomerPackageItem(Id),AppointmentId int NOT NULL REFERENCES dbo.LICHHEN(LichHenID),Quantity int NOT NULL CHECK(Quantity BETWEEN 1 AND 10000),Status nvarchar(20) NOT NULL CHECK(Status IN(N'Reserved',N'Consumed',N'Released')),CreatedAt datetime2 NOT NULL,SettledAt datetime2 NULL,CONSTRAINT UX_PackageUsage UNIQUE(AppointmentId,CustomerPackageItemId),CONSTRAINT CK_PackageUsage_Settled CHECK((Status=N'Reserved' AND SettledAt IS NULL) OR (Status<>N'Reserved' AND SettledAt IS NOT NULL)));
GO
IF COL_LENGTH(N'dbo.LICHHEN',N'CustomerPackageId') IS NULL ALTER TABLE dbo.LICHHEN ADD CustomerPackageId int NULL;
IF COL_LENGTH(N'dbo.GIAODICHDIEM',N'CustomerPackageId') IS NULL ALTER TABLE dbo.GIAODICHDIEM ADD CustomerPackageId int NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_LICHHEN_CustomerPackage') ALTER TABLE dbo.LICHHEN ADD CONSTRAINT FK_LICHHEN_CustomerPackage FOREIGN KEY(CustomerPackageId) REFERENCES dbo.CustomerPackage(Id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_GIAODICHDIEM_CustomerPackage') ALTER TABLE dbo.GIAODICHDIEM ADD CONSTRAINT FK_GIAODICHDIEM_CustomerPackage FOREIGN KEY(CustomerPackageId) REFERENCES dbo.CustomerPackage(Id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CustomerPackage') AND name=N'IX_CustomerPackage_CustomerId_CreatedAt') CREATE INDEX IX_CustomerPackage_CustomerId_CreatedAt ON dbo.CustomerPackage(CustomerId,CreatedAt);
GO
