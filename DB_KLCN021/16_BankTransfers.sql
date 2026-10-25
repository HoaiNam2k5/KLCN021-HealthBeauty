-- Additive SePay schema migration. Run with sqlcmd -b -d <API database> or select that database in SSMS.
-- No USE, DROP, DELETE, UPDATE, reseed, backfill or ALTER COLUMN.
-- Existing incompatible data/schema is reported and left unchanged.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET LOCK_TIMEOUT 15000;
IF DB_NAME() IN (N'master',N'model',N'msdb',N'tempdb')
    THROW 51016,'Select the existing HealthBeauty API database before running SQL16.',1;
IF @@TRANCOUNT<>0 THROW 51016,'Run SQL16 standalone, without an existing transaction.',1;
PRINT N'SQL16 target database: '+QUOTENAME(DB_NAME());
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @lockResult int;
    EXEC @lockResult=sys.sp_getapplock @Resource=N'HealthBeauty.SePay.Schema16',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
    IF @lockResult<0 THROW 51016,'Another schema update is running; retry after it completes.',1;

    -- Required scalar columns for EF invoice/customer materialization and settlement inserts.
    DECLARE @required TABLE(TableName sysname,ColumnName sysname);
    INSERT @required VALUES
        (N'HOADON',N'HoaDonID'),
        (N'HOADON',N'LichHenID'),
        (N'HOADON',N'KhachHangID'),
        (N'HOADON',N'NgayLap'),
        (N'HOADON',N'TongTienTruocGiam'),
        (N'HOADON',N'TongTienSauGiam'),
        (N'HOADON',N'TrangThai'),
        (N'HOADON',N'RowVersion'),
        (N'KHACHHANG',N'KhachHangID'),
        (N'KHACHHANG',N'TaiKhoanID'),
        (N'KHACHHANG',N'HoTen'),
        (N'KHACHHANG',N'SoDienThoai'),
        (N'KHACHHANG',N'GioiTinh'),
        (N'KHACHHANG',N'DiemThuong'),
        (N'KHACHHANG',N'CreatedAt'),
        (N'KHACHHANG',N'AvatarUrl'),
        (N'KHACHHANG',N'RowVersion'),
        (N'THANHTOAN',N'ThanhToanID'),
        (N'THANHTOAN',N'HoaDonID'),
        (N'THANHTOAN',N'PhuongThuc'),
        (N'THANHTOAN',N'SoTien'),
        (N'THANHTOAN',N'NgayGioThanhToan'),
        (N'THANHTOAN',N'TrangThai'),
        (N'GIAODICHDIEM',N'GiaoDichID'),
        (N'GIAODICHDIEM',N'KhachHangID'),
        (N'GIAODICHDIEM',N'HoaDonID'),
        (N'GIAODICHDIEM',N'VoucherID'),
        (N'GIAODICHDIEM',N'CustomerPackageId'),
        (N'GIAODICHDIEM',N'SoDiem'),
        (N'GIAODICHDIEM',N'LoaiGiaoDich'),
        (N'GIAODICHDIEM',N'NgayGiaoDich'),
        (N'GIAODICHDIEM',N'GhiChu'),
        (N'ThongBao',N'ThongBaoId'),
        (N'ThongBao',N'TaiKhoanId'),
        (N'ThongBao',N'KhachHangId'),
        (N'ThongBao',N'TieuDe'),
        (N'ThongBao',N'NoiDung'),
        (N'ThongBao',N'LoaiThongBao'),
        (N'ThongBao',N'DuLieuKemTheo'),
        (N'ThongBao',N'EventKey'),
        (N'ThongBao',N'NgayTao'),
        (N'ThongBao',N'PushStatus'),
        (N'ThongBao',N'PushAttempts'),
        (N'ThongBao',N'NextPushAt'),
        (N'ThongBao',N'PushLeaseId'),
        (N'ThongBao',N'PushLeaseUntil');
    IF EXISTS(SELECT 1 FROM @required r WHERE NOT EXISTS(
        SELECT 1 FROM sys.columns c WHERE c.object_id=OBJECT_ID(N'dbo.'+QUOTENAME(r.TableName),N'U') AND c.name=r.ColumnName))
    BEGIN
        SELECT TableName,ColumnName AS MissingColumn FROM @required r WHERE NOT EXISTS(
            SELECT 1 FROM sys.columns c WHERE c.object_id=OBJECT_ID(N'dbo.'+QUOTENAME(r.TableName),N'U') AND c.name=r.ColumnName);
        THROW 51016,'Settlement prerequisites are missing. Review earlier migrations (06/08/09/10/12/13/15). No business data was changed.',1;
    END;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id IN(OBJECT_ID(N'dbo.HOADON'),OBJECT_ID(N'dbo.KHACHHANG'))
        AND name=N'RowVersion' AND(system_type_id<>189 OR max_length<>8 OR is_nullable<>0))
        THROW 51016,'HOADON/KHACHHANG RowVersion must be SQL rowversion, non-null, length8. No automatic column conversion is permitted.',1;
    IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.HOADON') AND name=N'HoaDonID' AND system_type_id=56 AND is_nullable=0)
        THROW 51016,'HOADON.HoaDonID must be a non-null int before the ledger foreign key can be added.',1;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE is_identity=0 AND(
        (object_id=OBJECT_ID(N'dbo.THANHTOAN') AND name=N'ThanhToanID') OR
        (object_id=OBJECT_ID(N'dbo.GIAODICHDIEM') AND name=N'GiaoDichID') OR
        (object_id=OBJECT_ID(N'dbo.ThongBao') AND name=N'ThongBaoId')))
        THROW 51016,'Payment/reward/notification generated IDs must be IDENTITY columns. Review base schema; no data was changed.',1;
    IF EXISTS(SELECT 1 FROM sys.objects WHERE name=N'SePayTransaction' AND schema_id<>SCHEMA_ID(N'dbo') AND type IN('U','V','SN'))
        THROW 51016,'SePayTransaction exists outside dbo. Resolve the schema explicitly; no objects will be copied or replaced.',1;
    IF OBJECT_ID(N'dbo.SePayTransaction') IS NOT NULL AND OBJECT_ID(N'dbo.SePayTransaction',N'U') IS NULL
        THROW 51016,'dbo.SePayTransaction exists but is not a user table.',1;
    IF OBJECT_ID(N'dbo.SePayTransaction',N'U') IS NULL
        EXEC(N'CREATE TABLE dbo.SePayTransaction(
            Id bigint NOT NULL CONSTRAINT PK_SePayTransaction PRIMARY KEY,
            InvoiceId int NULL,Amount decimal(18,2) NOT NULL,Gateway nvarchar(100) NOT NULL,
            AccountNumber varchar(19) NOT NULL,TransferType varchar(5) NOT NULL,
            Content nvarchar(2000) NOT NULL,ReferenceCode nvarchar(100) NULL,Outcome varchar(30) NOT NULL,
            ReceivedAt datetime2(7) NOT NULL,TransactionAt datetime2(0) NOT NULL);');

    DECLARE @tableId int=OBJECT_ID(N'dbo.SePayTransaction',N'U');
    DECLARE @expected TABLE(ColumnName sysname,TypeName sysname,MaxBytes smallint,ExpectedPrecision tinyint,ExpectedScale tinyint,Nullable bit);
    INSERT @expected VALUES
        (N'Id',N'bigint',8,19,0,0),(N'InvoiceId',N'int',4,10,0,1),(N'Amount',N'decimal',9,18,2,0),
        (N'Gateway',N'nvarchar',200,0,0,0),(N'AccountNumber',N'varchar',19,0,0,0),
        (N'TransferType',N'varchar',5,0,0,0),(N'Content',N'nvarchar',4000,0,0,0),
        (N'ReferenceCode',N'nvarchar',200,0,0,1),(N'Outcome',N'varchar',30,0,0,0),
        (N'ReceivedAt',N'datetime2',8,27,7,0),(N'TransactionAt',N'datetime2',6,19,0,0);
    IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=@tableId)<>11 OR EXISTS(
        SELECT 1 FROM @expected e LEFT JOIN sys.columns c ON c.object_id=@tableId AND c.name=e.ColumnName
        LEFT JOIN sys.types t ON t.user_type_id=c.user_type_id
        WHERE c.column_id IS NULL OR t.name<>e.TypeName OR c.max_length<>e.MaxBytes
            OR c.precision<>e.ExpectedPrecision OR c.scale<>e.ExpectedScale OR c.is_nullable<>e.Nullable
            OR c.is_identity<>0 OR c.is_computed<>0 OR c.generated_always_type<>0)
    BEGIN
        SELECT name,TYPE_NAME(user_type_id) AS SqlType,max_length,precision,scale,is_nullable,is_identity
        FROM sys.columns WHERE object_id=@tableId ORDER BY column_id;
        THROW 51016,'Existing ledger columns differ from EF mapping. No columns or rows were changed; review the reported schema.',1;
    END;

    -- Bind data/DDL statements only after validating the existing schema.
    DECLARE @bad bit=0;
    IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE parent_object_id=@tableId AND type='PK')
    BEGIN
        EXEC sys.sp_executesql N'SELECT @x=CASE WHEN EXISTS(SELECT Id FROM dbo.SePayTransaction GROUP BY Id HAVING COUNT_BIG(*)>1) THEN 1 ELSE 0 END;',N'@x bit OUTPUT',@x=@bad OUTPUT;
        IF @bad=1 THROW 51016,'Duplicate provider IDs exist. Reconcile manually; no rows were deleted.',1;
        EXEC(N'ALTER TABLE dbo.SePayTransaction ADD CONSTRAINT PK_SePayTransaction PRIMARY KEY(Id);');
    END;
    IF NOT EXISTS(SELECT 1 FROM sys.key_constraints k JOIN sys.indexes i ON i.object_id=k.parent_object_id AND i.index_id=k.unique_index_id
        WHERE k.parent_object_id=@tableId AND k.type='PK' AND i.is_disabled=0
        AND(SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id=@tableId AND x.index_id=k.unique_index_id AND x.key_ordinal>0)=1
        AND EXISTS(SELECT 1 FROM sys.index_columns x JOIN sys.columns c ON c.object_id=x.object_id AND c.column_id=x.column_id
            WHERE x.object_id=@tableId AND x.index_id=k.unique_index_id AND x.key_ordinal=1 AND c.name=N'Id'))
        THROW 51016,'Ledger Id must be the sole primary key. No existing key was replaced.',1;

    IF EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns x ON x.constraint_object_id=f.object_id
        WHERE f.parent_object_id=@tableId AND COL_NAME(x.parent_object_id,x.parent_column_id)=N'InvoiceId'
        AND(f.referenced_object_id<>OBJECT_ID(N'dbo.HOADON') OR COL_NAME(x.referenced_object_id,x.referenced_column_id)<>N'HoaDonID'
            OR f.is_disabled=1 OR f.is_not_trusted=1 OR f.delete_referential_action<>0 OR f.update_referential_action<>0
            OR(SELECT COUNT(*) FROM sys.foreign_key_columns y WHERE y.constraint_object_id=f.object_id)<>1))
        THROW 51016,'Existing InvoiceId foreign key is incompatible, disabled or untrusted. No constraint was replaced.',1;
    IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns x ON x.constraint_object_id=f.object_id
        WHERE f.parent_object_id=@tableId AND COL_NAME(x.parent_object_id,x.parent_column_id)=N'InvoiceId')
    BEGIN
        EXEC sys.sp_executesql N'SELECT @x=CASE WHEN EXISTS(SELECT 1 FROM dbo.SePayTransaction s WHERE s.InvoiceId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.HOADON h WHERE h.HoaDonID=s.InvoiceId)) THEN 1 ELSE 0 END;',N'@x bit OUTPUT',@x=@bad OUTPUT;
        IF @bad=1 THROW 51016,'Orphan invoice references exist. Reconcile manually; no ledger rows were changed.',1;
        EXEC(N'ALTER TABLE dbo.SePayTransaction WITH CHECK ADD CONSTRAINT FK_SePayTransaction_HOADON FOREIGN KEY(InvoiceId) REFERENCES dbo.HOADON(HoaDonID);');
    END;

    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@tableId AND name=N'UX_SePayTransaction_PaidInvoice')
    BEGIN
        EXEC sys.sp_executesql N'SELECT @x=CASE WHEN EXISTS(SELECT InvoiceId FROM dbo.SePayTransaction WHERE Outcome=''Paid'' GROUP BY InvoiceId HAVING COUNT_BIG(*)>1) THEN 1 ELSE 0 END;',N'@x bit OUTPUT',@x=@bad OUTPUT;
        IF @bad=1 THROW 51016,'Duplicate Paid invoice references exist. Reconcile manually; no rows were deleted.',1;
        EXEC(N'CREATE UNIQUE INDEX UX_SePayTransaction_PaidInvoice ON dbo.SePayTransaction(InvoiceId) WHERE Outcome=''Paid'';');
    END;
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@tableId AND name=N'IX_SePayTransaction_ReceivedAt')
        EXEC(N'CREATE INDEX IX_SePayTransaction_ReceivedAt ON dbo.SePayTransaction(ReceivedAt);');

    IF EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=@tableId AND i.name IN(N'UX_SePayTransaction_PaidInvoice',N'IX_SePayTransaction_ReceivedAt')
        AND(i.type<>2 OR i.is_disabled=1 OR i.is_hypothetical=1
            OR(SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id=@tableId AND x.index_id=i.index_id AND x.key_ordinal>0)<>1
            OR NOT EXISTS(SELECT 1 FROM sys.index_columns x JOIN sys.columns c ON c.object_id=x.object_id AND c.column_id=x.column_id
                WHERE x.object_id=@tableId AND x.index_id=i.index_id AND x.key_ordinal=1 AND x.is_descending_key=0
                AND c.name=CASE i.name WHEN N'UX_SePayTransaction_PaidInvoice' THEN N'InvoiceId' ELSE N'ReceivedAt' END)
            OR(i.name=N'UX_SePayTransaction_PaidInvoice' AND(i.is_unique<>1 OR i.has_filter<>1
                OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(i.filter_definition,N'[',N''),N']',N''),N' ',N''),N'(',N''),N')',N''),N'N''Paid''',N'''Paid''')<>N'Outcome=''Paid'''))
            OR(i.name=N'IX_SePayTransaction_ReceivedAt' AND(i.is_unique<>0 OR i.has_filter<>0))))
        THROW 51016,'An existing ledger index has an incompatible definition; no index was dropped or replaced.',1;

    COMMIT TRANSACTION;
    SELECT DB_NAME() AS DatabaseName,N'dbo.SePayTransaction' AS LedgerTable,
        OBJECT_ID(N'dbo.SePayTransaction',N'U') AS TableId,N'SQL16 schema validation passed' AS Result;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
