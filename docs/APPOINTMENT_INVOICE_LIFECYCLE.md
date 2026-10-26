# Appointment, invoice and payment lifecycle

## Resulting business behavior

1. A customer books services. Reception/Admin/Manager uses action buttons: confirm -> start service -> complete service. ChoXacNhan -> DaXacNhan -> DangThucHien -> HoanThanh is supported. DaDen (customer arrival) remains an optional check-in between confirmation and start. No invoice is created on confirmation, check-in, service start or cancellation.
2. On ordinary appointment completion, the backend stages exactly one invoice with status ChuaThanhToan and a private INVOICE notification, in the same SaveChanges as the appointment transition and completion notice. Existing invoice uniqueness and rowversions protect concurrent requests. Repeated terminal transitions return409 and do not create a second invoice or notice.
3. Invoice lines use booked GiaDuKien snapshots. Later catalog price changes do not change the bill. Ordinary services are grouped by service and booked unit price. Combo quantity is inferred from complete booked component counts; a historical changed/inconsistent combo definition falls back to one aggregate combo line while preserving the exact booked total.
4. Pending notices carry type=INVOICE, appointmentId and status. They intentionally omit invoiceId because SQL generates the new ID during SaveChanges. The app resolves the invoice through the owner-scoped appointmentId filter; no invoiceId0 or postcommit non-atomic outbox write is used.
5. The app shows a pending-payment reminder, refreshes on foreground/resume/FCM and periodically while foregrounded (15seconds). Opening the reminder or notification leads to the invoice. Background/closed-app delivery depends on configured server Firebase credentials, device token and OS notification permission. The persistent notification inbox remains authoritative if push is unavailable.
6. The customer transfers the exact amount/reference from server-generated bank instructions. The verified SePay webhook saves payment, invoice status DaThanhToan, earned rewards and paid notification atomically. Duplicate provider transaction IDs are acknowledged without applying rewards/payment twice. No client action self-confirms a transfer.
7. Web billing refreshes every5seconds while visible and refreshes its selected invoice/receipt from current query data. Appointment changes invalidate invoices. Paid invoices remain in database/history; printing remains the existing web action, not a new automatic print or separate duplicate invoice.

## No-charge cases

Package-funded completion keeps the existing zero-value DaThanhToan receipt and consumes the reserved package session; no extra bank charge is requested. Ordinary zero-priced bookings auto-complete their zero invoice as paid, without a payment record or earned points. Legacy ordinary appointments with no detail rows likewise receive an empty zero-paid receipt and no payment reminder; new booking APIs already require nonempty validated services. No historical appointments are backfilled automatically.

## Clerk discounts preserved after automatic creation

POST /api/v1/invoices/{id}/discounts accepts {voucherCode?:string,pointsToRedeem?:int}. It is restricted to Admin/Manager/Reception and INVOICE.WRITE. A discount may be applied only once to an unpaid positive undiscounted invoice with no successful payment or previous redeemed points. Lines and booked prices are immutable. Voucher ownership/expiry/promotion and point balance are validated server-side, and only the actual clamped points are deducted. A no-effect request fails without consuming anything. Repeated, already-discounted/paid or package-funded requests return409.

A100% discount settles the zero total immediately without creating a money transaction or earned points. Other adjustments send an updated pending notice. Apply discounts before customer transfer; an already displayed QR may contain the old amount. Fresh app detail drops stale instructions, and webhook amount matching refuses mismatched transfers for reconciliation rather than confirming an incorrect amount. Invoice/customer/voucher rowversions guard a race with SePay/manual settlement; the failed SaveChanges does not consume voucher/points.

The legacy POST /invoices endpoint remains available for completed historical appointments without an invoice, including its existing voucher/point rules. It now stages a pending invoice notice. Existing duplicates remain409.

## Additional query contract

GET /api/v1/invoices preserves the existing array response, offset and limit. Optional status accepts ChuaThanhToan, DaThanhToan or DaHuy; optional appointmentId must be positive. Customer filters are always combined with ownership and cannot reveal another customer's invoice. Management read permissions remain INVOICE.READ.

## Roles and rollout

The existing management roles continue to confirm/finish appointments. Technician Staff is not newly granted completion privileges by this task; customer cancellation rules remain unchanged. No schema migration, JWT configuration, database connection or SePay key change is needed. Deploy the updated API, Web and Mobile; a successful local build does not update EC2 by itself. Do not rerun SQL16 or alter paid historical invoices for this feature.

## Manual acceptance after deployment

- The appointment table shows a status tag and an appropriate primary action instead of a status dropdown. Both table and detail show the actions. Completed appointments can open their exact invoice through `/billing?invoiceId=...`.
- Completion confirmation shows the booked service lines and total; package appointments explain that no second charge is required.
- Reception/Admin/Manager cancellation through the status endpoint requires a nonblank reason of at most1000characters. Cancellation while in progress remains prohibited. Existing customer cancellation behavior remains compatible.
- Successful status transitions stage the actor, time, previous/new status and cancellation reason in existing AUDITLOG in the same save as the status, invoice and notifications. This needs no database schema change. Existing Staff/customer permissions are unchanged.
- Appointment responses include customer/staff names scoped to the authorized appointment list. The UI does not require access to the full customer directory to display those names.

- Book as CustomerA; confirm/check-in/start as Reception. Verify no invoice yet and confirmation notice private to CustomerA.
- Finish once: exactly one pending invoice with the booked total appears; CustomerA sees a reminder and can open it. CustomerB cannot read it.
- Repeat completion/create:409 and still one invoice. Cancel another appointment: no invoice.
- If required, apply a clerk voucher/points once before bank transfer. Refresh QR after amount changes.
- Complete a package appointment: zero-paid receipt, no second charge and no unpaid reminder.
- Transfer an ordinary pending invoice using SePay. Observe paid state on app and web, one payment/reward award, persisted history. Replay the same provider delivery: no second award.
- Return from background/reopen invoice: refresh current server status. Keep a web invoice drawer/receipt open while payment completes: it updates without a manual page reload.

Local validation uses isolated EF InMemory databases and actual local HTTP/JWT/API-key requests. It is not a live AWS SePay transfer or SQL Server concurrency stress test. No production data was changed.
