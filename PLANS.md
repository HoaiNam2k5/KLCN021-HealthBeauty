# Fix Flutter feedback, lines 108?224 (2026-10-13)
- Active repo / allowed writes / Git scope: D:/KhoaLuan/DEV/KLCN021_HealthBeauty.
- Related repos: none. Branch fix/appointment-api-contract; preserve existing local commit; no push.
- Scope: customer access to GET staff, interval overlap in Create/Reschedule, durationMinutes response. Also guard PUT update against the same overlap bypass.
- [x] Read corrected line range and trace causes.
- [x] Add regression tests: baseline 11 failed / 6 passed.
- [x] Implement shared overlap/duration calculation and customer list access.
- [x] Update API catalog affected rows, build/test and read-only review.
- No Swagger refactor or changes to old feedback. Existing proposed patch failed before mutation; placeholder file removed.
- MCP memory/navigation unavailable; onboarding script missing.

- Reviewer found cycle risk in tracked navigation loading and lost accents. Fixed with separate AsNoTracking duration reads and escaped Unicode; serialization assertion added. Current tests 17/17 pass.

## Final verification
- dotnet test: 17 passed, 0 failed; baseline was 11 failed/6 passed.
- dotnet build --no-restore: 0 warnings, 0 errors.
- Catalog XLSX ZIP/readback and staff/create/list/update/reschedule entries: PASS.
- HTTP: Swagger 200, durationMinutes integer; anonymous GET staff 401; Customer schedules 403; Customer GET staff 200 with explicit local SQL Server configuration.
- Initial live check failed because Windows PowerShell uses older RNG API; corrected using supported RNG instance. Default-config staff request timed out; overriding connection only for test process to local SQLEXPRESS made it pass. Persistent configuration was not edited.
- Review: JSON-cycle loading risk and damaged Unicode corrected; reviewer found no remaining concrete issue in scope.
- Runtime booking mutations tested with isolated EF InMemory databases, not against existing SQL data. Concurrent booking requests not tested.
- Files modified: AppointmentContracts.cs, AppointmentsController.cs, CustomersController.cs, SupplementControllers.cs, KLCN021_API_Catalog.xlsx, KLCN021_HealthBeauty.sln, README.md.
- Files added: Services/AppointmentTiming.cs, HealthBeauty.Api.Tests/HealthBeauty.Api.Tests.csproj, HealthBeauty.Api.Tests/AppointmentRegressionTests.cs, PLANS.md.
- No commit/push. User feedback file left untouched.

## Full API audit excluding inventory/product sales (2026-10-13)
- Active repo/Git scope: D:/KhoaLuan/DEV/KLCN021_HealthBeauty.
- Related documents: D:/KhoaLuan/DeCuong.docx and KLCN021_HK1.docx (read-only).
- Write scope: audit report/planning and temporary isolated tests only. Preserve all existing source changes; no commit/push.
- [x] Inventory implemented routes and inspect every controller.
- [x] Independent auth/finance and booking/catalog audits.
- [x] Read-only HTTP checks with local SQL and isolated mutation reproductions.
- [x] Prioritized report distinguishing reproduced bugs, code findings and missing APIs.

- Audit result: 71 implemented operations; 31 GET tested on SQL: 28 HTTP200, 2 HTTP500, 1 test-ID HTTP404. Both 500s reproduced as JSON reference cycles.
- 12 isolated evidence tests confirm undesired behavior (not tests claiming bugs fixed).
- Findings/missing APIs/priorities: API_REVIEW.md; evidence: API_AUDIT_HTTP.json, API_AUDIT_ROUTES.json, .audit/.
- No production source edits in audit, no SQL mutation, no commit/push.

## Priority API fixes (2026-10-13)
- Active repo / allowed writes / Git scope: D:/KhoaLuan/DEV/KLCN021_HealthBeauty. Related repos: none.
- Shared branch: agent/priority-api-fixes. Preserve prior edits; no commit/push.
- Scope: detail JSON cycles; staff-only payment confirmation; completed/matching invoices; appointment terminal states; duration-aware slots and shift containment. Exclude warehouse/product sales.
- [x] Implement booking/detail fixes with regressions.
- [x] Finance worker implements invoice/payment restrictions with regressions.
- [x] Build/test, read-only HTTP sweep, independent review, update documentation.

- Final:59/59 main regressions; build0warnings/0errors;31GET with30HTTP200/1test-ID404/0HTTP500;Customer payment403. Diagnostics5remaining defects reproduced/7historical skipped.
- Review findings: fixed staff/customer profile precedence and protected combo component edits pending invoice. Remaining limits explicitly listed in API_PRIORITY_FIXES.md.
- No commit/push or existing SQL data mutation.

## Remaining API fixes (2026-10-13)
- Active repo / allowed writes / Git scope:D:/KhoaLuan/DEV/KLCN021_HealthBeauty; related repos:none. Branch agent/api-followup-fixes. No commit/push or existingSQLmutations.
- [x] Auth worker:account-awareJWT,loginfailurelogs/lockout,refresh/logoutguards.
- [x] Main:pointsclamp/invoiceledger,zeroamountsettlement,vouchervalidation.
- [x] Booking worker:combo/pricevalidation,staffshiftFK/overlapchecks,ownStaffreads.
- [x] Main:dynamicpermissionfilter,currentDBgrants,idempotentseed/catalogalignment.
- [x] Regression/build/HTTP/review/docs.
- Root causes already established:tokenmiddleware ignores account;pointsdeduct request rather than actualdiscount;SQLpaymentrequires>0;permissiontable unused;voucherUpdate lacks createvalidations.

- Test-stage errors:permissionfixture omitted requiredNhomQuyen (fixed); mappingcoverage caught Services actions namedCreateService/UpdateService/DeactivateService (correctedtoactualnames).

- Final main146/146pass; build0warnings/0errors; actualisolatedHTTPsameJWT revoke403/accountlock401/restore200. SQL34GET31success/1testID404/2expectedAdmin-on-Staff403/zero500. Signedmissingaccount401,Customerpay403.
- Review foundlegacydiscounttypewhitespace mismatch; normalizedfinancialcalculationandregressionadded.
- Agent tool contexts couldcreate tests butdeniedproductionwrites; mainappliedprepared scopedpatcheswithauthorizedtools, noACLchanges. TemporarypatchJSON removedafterapplication.
- Prepared03permissionmigration,notrunSQL; seed/docs/catalogaligned. Remainingconcurrency/history/voucherrefundworkflowinAPI_FOLLOWUP_FIXES.md. No commit/push.

## Publish all changes to main (2026-10-13)
- User explicitly authorized committing/pushing all repo changes to main. Active/write/Git scope:D:/KhoaLuan/DEV/KLCN021_HealthBeauty; related repos:none.
- Include source/tests/docs/catalog/SQL migration and user feedback file. Exclude generated bin/obj and temporary audit logs via gitignore.
- Main and working branches share base3012ecd; preserve that existing local commit. Ordinary push only, no force.
- Fetch attempted:GitHub unreachable through127.0.0.1:9 proxy; prepare local commit then attempt push.
