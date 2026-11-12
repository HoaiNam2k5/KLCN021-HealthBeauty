# Appointment approval layout — 2026-10-27

The appointment table expanded to its longest content, leaving the approval button outside the visible area. The appointment action column is now fixed on the right with a defined width. Names and services use two-line summaries; full content and notes remain in the existing detail drawer.

Below 768px, appointments use cards with inline actions and pagination. The shared ManagementTable only enables this behavior when its caller supplies a card renderer. Other management pages retain their existing layout.

The primary action follows the existing status workflow. Optional arrival and cancellation moved into an accessible secondary menu. Permissions, confirmation dialogs, cancellation reasons and invoice actions remain in force; arrival is still optional.

Files: `HealthBeauty.Web/src/components/ManagementTable.tsx`, `src/features/appointments/AppointmentsPage.tsx`, `src/index.css`; browser regression `tests/browser/appointment-layout.mjs`.

Verification:

- Existing Web suite: 77 passed, zero failed.
- Production TypeScript/Vite build passed. Existing large-bundle warning remains nonblocking.
- Isolated Chromium tests at 1366, 1024, 768, 390 and 320px: actions visible before horizontal scrolling; desktop actions remain fixed during scrolling; mobile cards have no document overflow; keyboard menu, approval, optional arrival, full detail content and read-only permissions passed. No runtime page errors.
- Screenshots visually inspected at 1366 and 320px. Evidence: `D:/KhoaLuan/_Work/appointment-layout-evidence/validation.json` and images in that directory.
- Browser API requests were all intercepted with synthetic data; non-local requests were blocked. No production appointments were modified.

Run after `npm run build` and `npm run preview -- --host 127.0.0.1 --port 5178 --strictPort`:

```powershell
node tests/browser/appointment-layout.mjs
```

Uses a local Playwright installation. Set `PW_MODULE` to its module directory, `PW_EXECUTABLE` to an existing Chromium executable if needed, and `LAYOUT_OUTPUT` to an evidence directory. No dependency or browser installation was added to this repository.

Initial browser launch found a cached Playwright/browser-version mismatch; verification used the already-installed Chromium executable explicitly. The first plan write/read commands used a nested working-directory path and failed before mutation; corrected to the repository root/absolute paths.

No Git push or EC2 deployment in this task. User reported SQL17 applied; it was not rerun or independently queried. No API/database changes were needed for this layout fix.
