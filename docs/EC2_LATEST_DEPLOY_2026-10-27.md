# Latest API/Web and schema deployment — 2026-10-27

Release `20261027-ktv-reviews-approval` is active at `https://healthbeauty.duckdns.org` on EC2 `3.107.209.148`.

## Source and images

An immutable, secret-scanned snapshot of 213 current Local source files was uploaded directly, including uncommitted API/Web changes. No GitHub push was performed. The canonical server checkout and its three locally customized Docker/nginx files were retained.

- Source: `/home/ubuntu/demo-api/releases/20261027-ktv-reviews-approval/source`.
- Source archive SHA256: `629def2df545292bcb3d156394656e9711cf0c910acd2da2ba253571b9b677b7`.
- API image: `healthbeauty-api:lifecycle-20261027155110`, container `d7ff3eb06818`.
- Web image: `healthbeauty-web:lifecycle-20261027155110`, container `2bceba0979a5`.
- SQL Server container `76010c7d5135` and Caddy `41d1609bf828` unchanged.

Both Linux source builds passed. Only API/Web were recreated after preparation. Existing runtime images were inherited to preserve appsettings/nginx. Exact environment, startup, configuration hashes and the previous nine Compose files were checked; SePay, Cloudinary, JWT and connection settings remained unchanged. Source Docker/nginx hashes also remained unchanged.

Active image override appended to the entire existing Compose chain:
`/home/ubuntu/demo-api/compose.release.20261027-ktv-reviews-approval.yaml`.
Future rollouts must preserve this complete chain, including SePay and Cloudinary overrides. Do not use only the base Compose file to recreate services.

## Database

The production audit found `NHANVIEN.AvatarUrl` missing despite the user's earlier SQL17 run elsewhere. All other mapped schema requirements were present. A COPY_ONLY database backup with CHECKSUM was created and passed RESTORE VERIFYONLY (no database restore):

`sqlserver:/var/opt/mssql/backup/healthbeauty-20261027-ktv-reviews-approval.bak` (12,701,696 bytes).

Only reviewed `DB_KLCN021/17_StaffAvatar.sql` was applied, adding nullable `nvarchar(2048)`. Afterward all 269 source-derived mapped columns and five critical indexes passed presence checks, and the exact new column definition passed. No base/seed/historical migration replay, Local data import, database recreation or volume deletion occurred.

## Verification

- Linux release preservation tests: 12/12 passed. The initial Windows test attempt had two temporary-directory permission errors; Linux verification passed before deployment.
- HTTPS home/assets: 200; public HTML and running API DLL hashes match the built release.
- `/api/v1/services`: 200, 12 services; SQL read succeeds and all services expose the new rating/review/booking statistics. Service detail also exposes review statistics.
- Anonymous staff/invoice requests: 401.
- SePay: no key returns401; current key with an invalid transaction date returns400 before ledger access. No financial transaction was created or replayed.
- Cloudinary authenticated read-only ping: 200/status ok. No portrait upload or customer profile mutation was performed.
- All four containers running, restart count0.
- Actual deployed Web assets passed isolated Chromium checks at1366/1024/768/390/320px: fixed approval column, mobile cards, confirmation, optional arrival, keyboard menu, full detail and read-only permissions. API calls in those browser checks were mocked; no real appointment was changed. No page errors. Screenshots inspected.

Evidence: `D:/KhoaLuan/_Work/ec2-latest-verification.json`, `ec2-latest-preservation-result.json`, `ec2-latest-browser-evidence/validation.json`. Restricted preparation/build/config/SQL backup logs reside under the release's `private` directory on EC2; do not commit or print private snapshots.

Initial read-only schema audit used an invalid SQL Server CTE VALUES form; corrected before any schema change. An auxiliary SSH log-status command had quoting errors; replaced by script-based checks. These did not modify production data/configuration.

## Rollback, if needed

Run on EC2:

```bash
HEALTHBEAUTY_RELEASE_ID=20261027-ktv-reviews-approval \
python3 /home/ubuntu/demo-api/releases/20261027-ktv-reviews-approval/source/deploy/aws/release.py rollback
```

This restores the immediately previous API/Web image pair using the full saved Compose chain. SQL/Caddy and runtime settings remain unchanged. Keep the added nullable avatar column; old code ignores it. No database restore or column deletion is required. If rolled back, use `compose.rollback.20261027-ktv-reviews-approval.yaml` as the final image override for subsequent operations.

Users can refresh Web with Ctrl+F5. To attach an existing browser-only employee portrait, open that employee on the same browser and Save; new uploads go through Cloudinary and the saved URL is shared with Mobile1.1.2. Actual end-to-end portrait upload and a new real bank transfer were deliberately not executed during deployment verification.
