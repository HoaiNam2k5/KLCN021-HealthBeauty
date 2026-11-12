# Reviews and latest UI fixes — 2026-10-27

Release: 1.1.1+3. Preserves the updated glass navigation, hero and screen headers.

- Legacy production catalog responses omit review statistics. The client fetches public review summaries with a maximum of three concurrent requests; missing or failed statistics are not shown as zero reviews. Requests are shared within a catalog revision, and responses from older revisions cannot overwrite newer statistics.
- Service details now offer a direct review/comment button below the price. Failed review loads show a retry action. Completed appointment review submission refreshes catalog statistics.
- Account and review layouts wrap at narrow widths and large text sizes. Scroll views allow space for the floating navigation. Account version matches the release.
- API source supplies review and booking statistics for service list/detail, including combo services, without schema changes. This API source has not been deployed in this task; the client fallback supports the existing server.

Verification: Flutter 200 tests passed; analyzer reports no issues. Related API suite: 48 tests passed, including SQL Server query translation checks and isolated in-memory HTTP tests. No production data mutations, SQL migrations, Git push or EC2 deployment.

Backup: D:/KhoaLuan/_Backups/MobileReviews_20261027_173616/source-before-fix.zip.
Verification logs: D:/KhoaLuan/_Work/reviews-fix-tests.log, reviews-fix-analyze.log, reviews-fix-build.log, api-review-related-tests-20261027.log.

Android validation: latest APK installed successfully (versionName 1.1.1, versionCode 3); service 1 shows 5.0/1 review and its existing comment against production. Three screenshots inspected; APK ZIP integrity passed. Physical phone and creating a new production review were not tested.
