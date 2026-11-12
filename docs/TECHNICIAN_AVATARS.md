# Technician picker and shared portraits — 2026-10-27

Source scope: API, Web staff management, Flutter booking. No production database, deployment or Git push was performed.

## Behavior

- Employee profiles also exist for Reception/Admin/Manager. Customer staff lists now contain active technician accounts only. An account role takes precedence over its editable position title. Legacy accountless employees require an explicit technician title. Management keeps the complete employee list.
- Appointment creation, updates, rescheduling and availability use the same eligibility rule. Existing appointments and assignments are not rewritten.
- Flutter filters older API staff lists by explicit technician titles; newer responses provide actual role and active status. Unknown positions are excluded rather than assumed to be technicians.
- The old Web avatar input stored URLs in browser localStorage only. New Web uses the existing authenticated `/media/images` upload to Cloudinary, then sends `avatarUrl` with the employee save request. The API persists this URL on `NHANVIEN`; Flutter displays it with an initials fallback when missing, loading or invalid.
- Old browser URLs are offered when editing a record without a server portrait. Open each applicable employee and save once to attach its old URL. No bulk guessing by name or poster order. Removing the portrait clears its URL; it does not delete the original Cloudinary file.
- Upload accepts JPEG/PNG/WebP up to 5MB. Upload completion fills the form; the user must click Save to attach the URL to the employee.

## Deployment dependency

**Do not deploy the rebuilt API before applying the reviewed schema script.** New EF mapping reads `NHANVIEN.AvatarUrl`; old databases without the column will fail those queries.

1. Obtain approval to run `DB_KLCN021/17_StaffAvatar.sql` on the intended database.
2. Use the existing secure SQL Server access mechanism and explicitly select `KLCN021_HealthBeauty` with sqlcmd `-d KLCN021_HealthBeauty -b -i <script>`. Never expose database credentials in logs.
3. Script checks the exact database/table/column definition and adds only nullable `nvarchar(2048)` inside a transaction. It never drops or rewrites existing data. It is safe to rerun against the expected definition.
4. Deploy the new API, then Web. Preserve current Compose environment, SePay settings, SQL container/volumes and Caddy.
5. Save a portrait through Web and verify the same URL is returned by `/staff` to a customer and rendered by the new APK.

Rollback: restore the previous API and Web images together. Leave the added nullable column in place; old code ignores it. Do not drop columns, restore the database or delete uploaded images to roll back application code.

## Validation

- API full suite: 642 passed, including 17 focused technician/avatar tests; build zero warnings/errors. Uses isolated tests and SQL translation checks, no production writes.
- Flutter full suite: 203 passed; analyzer no issues.
- Web tests: 77 passed; production TypeScript/Vite build succeeded.
- End-to-end production upload/persistence remains pending approval of schema/deployment. Existing deployed API does not yet expose employee portraits.

Logs: `D:/KhoaLuan/_Work/technician-api-full-tests.log`, `technician-mobile-tests.log`, `technician-mobile-analyze.log`, `technician-web-tests.log`, `technician-web-build.log`.

APK: D:/KhoaLuan/GiaoDienMoi_KetQua/HealthBeauty-1.1.2-release.apk (1.1.2+4). ZIP integrity PASS; Android install Success, versionName1.1.2/versionCode4 verified. No production booking/upload was submitted.
