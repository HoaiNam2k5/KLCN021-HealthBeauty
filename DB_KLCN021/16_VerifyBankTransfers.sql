-- Read-only verification. Select the same database used by the API.
SET NOCOUNT ON;
SELECT DB_NAME() AS DatabaseName, @@SERVERNAME AS SqlServerName,
    OBJECT_ID(N'dbo.SePayTransaction',N'U') AS SePayTransactionTableId;
IF OBJECT_ID(N'dbo.SePayTransaction',N'U') IS NULL
    THROW 51016,'SePayTransaction is still missing in this database. Do not retry payment until SQL16 succeeds here.',1;

SELECT c.column_id,c.name AS ColumnName,t.name AS SqlType,c.max_length AS MaxBytes,
    c.precision,c.scale,c.is_nullable,c.is_identity
FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id
WHERE c.object_id=OBJECT_ID(N'dbo.SePayTransaction') ORDER BY c.column_id;

SELECT i.name AS IndexName,i.is_primary_key,i.is_unique,i.is_disabled,i.filter_definition,
    c.name AS ColumnName,ic.key_ordinal,ic.is_included_column
FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
WHERE i.object_id=OBJECT_ID(N'dbo.SePayTransaction') ORDER BY i.index_id,ic.index_column_id;

SELECT f.name AS ForeignKeyName,OBJECT_SCHEMA_NAME(f.referenced_object_id) AS ReferencedSchema,
    OBJECT_NAME(f.referenced_object_id) AS ReferencedTable,
    COL_NAME(x.referenced_object_id,x.referenced_column_id) AS ReferencedColumn,
    f.is_disabled,f.is_not_trusted,f.delete_referential_action_desc
FROM sys.foreign_keys f JOIN sys.foreign_key_columns x ON x.constraint_object_id=f.object_id
WHERE f.parent_object_id=OBJECT_ID(N'dbo.SePayTransaction');

EXEC(N'SELECT COUNT_BIG(*) AS LedgerRows FROM dbo.SePayTransaction;');
GO
