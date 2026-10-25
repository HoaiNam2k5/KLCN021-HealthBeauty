# Apply SePay SQL16 to the AWS SQL Server container

## Diagnosis and EF audit

AWS database `KLCN021_HealthBeauty` has no SePay table and the deployed API reports SQL208. This is an unapplied database schema change. Publishing API binaries or rebuilding Flutter does not execute SQL migrations.

The existing mapping is registered correctly:

- `HealthBeauty.Api/Models/SePayTransaction.cs`: `DbSet<SePayTransaction> SePayTransactions`, explicit `ToTable("SePayTransaction")` (SQL Server's standard dbo resolution).
- `HealthBeauty.Api/Models/NotificationModels.cs`: `OnModelCreatingPartial` calls `ConfigureBankTransfers`.
- `Controllers/BankTransfersController.cs`: checks the ledger before settlement, so a missing table fails before a transaction can be recorded.
- `Services/InvoiceSettlement.cs`: stages invoice/payment, customer rewards and notifications, then the controller saves atomically.

No EF production code change or API/Flutter rebuild is required for this missing-table repair.

| Column | SQL mapping | Null / special rule |
| --- | --- | --- |
| Id | bigint | NOT NULL, primary key, not IDENTITY (SePay supplies the ID) |
| InvoiceId | int | NULL, FK to dbo.HOADON(HoaDonID), NO ACTION |
| Amount | decimal(18,2) | NOT NULL |
| Gateway | nvarchar(100) | NOT NULL |
| AccountNumber | varchar(19) | NOT NULL |
| TransferType | varchar(5) | NOT NULL |
| Content | nvarchar(2000) | NOT NULL |
| ReferenceCode | nvarchar(100) | NULL |
| Outcome | varchar(30) | NOT NULL |
| ReceivedAt | datetime2(7) | NOT NULL |
| TransactionAt | datetime2(0) | NOT NULL |

Indexes: PK on Id; `UX_SePayTransaction_PaidInvoice` UNIQUE on InvoiceId filtered by `Outcome='Paid'`; `IX_SePayTransaction_ReceivedAt` on ReceivedAt.

SQL16 also checks all 46 scalar columns used by invoice/customer reads and payment/reward/notification inserts in HOADON, KHACHHANG, THANHTOAN, GIAODICHDIEM and ThongBao. Later prerequisites include HOADON.RowVersion (06), KHACHHANG.RowVersion (09), KHACHHANG.CreatedAt (12), KHACHHANG.AvatarUrl (15), GIAODICHDIEM.VoucherID (10), GIAODICHDIEM.CustomerPackageId (13), ThongBao.EventKey (08) and notification push fields (06). Missing prerequisites are reported; unrelated migrations are not run automatically.

## Files and safety behavior

Upload these three files together:

- `DB_KLCN021/16_BankTransfers.sql`: additive migration, no forced USE/database switch, no business-row DML, no DROP or column conversion.
- `DB_KLCN021/16_VerifyBankTransfers.sql`: read-only metadata and ledger-count queries.
- `DB_KLCN021/apply-bank-transfers-aws.sh`: runs both files with `sqlcmd -d KLCN021_HealthBeauty -b` in the existing sqlserver container.

SQL16 uses an explicit transaction, XACT_ABORT, TRY/CATCH rollback, bounded lock wait and a migration application lock. On compatible existing tables it adds only missing keys/indexes. Incompatible column types/nullability/identity, PK/FK/index definitions, duplicate IDs/Paid invoices or orphan references cause an error without deleting or coercing any rows. Existing rows are not reconciled or marked paid by this migration.

The wrapper does not restart containers, change volumes, change connection strings/JWT, run Compose or reference the SePay API key. It uses the SQL container's existing SA password variable via SQLCMDPASSWORD without printing it or passing it as a command-line password. If that variable is unavailable or stale, stop and use an existing administrative SQL connection; do not paste credentials into chat.

## Windows PowerShell upload

Use the EC2 key and public address from the existing SSH deployment:

```powershell
$Pem = "C:\path\ec2-key.pem"
$Ec2 = "ubuntu@EC2_PUBLIC_IP"
$Repo = "D:\KhoaLuan\DEV\KLCN021_HealthBeauty"
$Bundle = "$Repo\.local-integration\sepay-schema16-aws-20261025.tgz"
scp -i $Pem $Bundle "$Bundle.sha256" "${Ec2}:~/"
```

The local bundle contains only the three files listed above; it does not contain credentials.

## Ubuntu execution

```bash
cd ~
sha256sum -c sepay-schema16-aws-20261025.tgz.sha256
# Continue only when checksum reports OK.
mkdir -p ~/sepay-schema16
tar -xzf sepay-schema16-aws-20261025.tgz -C ~/sepay-schema16
cd ~/sepay-schema16
bash apply-bank-transfers-aws.sh
```

The wrapper chooses sqlcmd18 or17 inside the sqlserver container and explicitly uses KLCN021_HealthBeauty. `-b` exits on SQL errors; verification runs only if migration succeeds. Require both the result `SQL16 schema validation passed` with a non-null TableId and final `PASS: SQL16 and read-only verification completed; SQL container identity is unchanged.`

On MissingColumn/schema-conflict output, stop and review the reported prerequisites. Do not delete/recreate existing tables or run all historical migrations blindly. A failed SQL16 transaction rolls back only its own DDL; after a successful migration, leave the additive ledger in place when rolling back API binaries.

## Retry the already received payment

After schema verification, resend the existing transaction's webhook from SePay's delivery history. Use the original transaction ID, not a new fake ID or an additional bank transfer. For the reported case: transaction `93075366`, invoice `9`.

Run these read-only queries through the same database connection:

```sql
SELECT Id,InvoiceId,Amount,Outcome,ReceivedAt
FROM dbo.SePayTransaction WHERE Id=93075366;
SELECT HoaDonID,TongTienSauGiam,TrangThai
FROM dbo.HOADON WHERE HoaDonID=9;
```

If the webhook is received and all payment checks match, expect Outcome=Paid and TrangThai=DaThanhToan. HTTP200 alone can also mean a mismatched payment was stored for reconciliation; inspect Outcome. Do not manually mark paid or remove ledger rows to force retries. Refresh invoice status in Flutter afterward.

## Validation performed and limits

SQL16 was executed against an isolated local SQL Server test database, never existing business databases. Fresh creation, rerun with existing ledger rows, missing-index addition, incompatible-index rejection and extra-column rejection passed; original test invoice/customer rows remained unchanged. The temporary database was removed after the test. EF SQL Server metadata tests independently cover all11 ledger columns, all46 prerequisite columns, PK/FK/index definitions. AWS execution remains user-run and must be confirmed from its own sqlcmd output.
