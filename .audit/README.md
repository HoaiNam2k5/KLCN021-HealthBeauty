# Historical diagnostic fixtures

The twelve tests record pre-fix defects and are now explicitly skipped; corrected behavior is verified by the main solution regression tests. They remain outside the main solution as historical evidence, not an active verification gate.

`dotnet test .audit/HealthBeauty.Api.Audit.csproj` should report12skipped,0failed.

The HTTP script resolves actual account roles with a read-only SQL query, then checks GET routes using temporary JWT configuration. It also expects401 for a signed token naming a missing account, and403 for customer payment confirmation before any mutation. Staff-only me routes return403 in the Admin sweep if the database has no active Staff account; isolated main tests cover those routes with Staff fixtures.

No stored secrets or existing application data are changed. Results: ../API_AUDIT_HTTP.json; current report: ../API_FOLLOWUP_FIXES.md.
