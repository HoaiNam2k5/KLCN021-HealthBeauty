# KLCN021 HealthBeauty

Repository chứa ASP.NET Core Web API, SQL Server schema và danh mục API cho hệ thống quản lý spa HealthBeauty. Web React và ứng dụng di động dùng chung API này.

## Công nghệ

- .NET 8 / ASP.NET Core Web API
- SQL Server
- Entity Framework Core
- JWT access token và refresh token

## Yêu cầu

- .NET 8 SDK
- SQL Server (LocalDB, SQL Server Express hoặc SQL Server instance)
- SQL Server Management Studio hoặc công cụ chạy script tương đương

## Cài đặt lần đầu

1. Clone repository và mở solution:

   ```powershell
   git clone https://github.com/HoaiNam2k5/KLCN021-HealthBeauty.git
   cd KLCN021-HealthBeauty
   ```

2. Chạy script `DB_KLCN021/KLCN021_HealthBeauty.sql` trong SQL Server Management Studio. Script tạo database `KLCN021_HealthBeauty` và các bảng cần thiết.

   Để nạp dữ liệu mẫu cho giao diện và luồng nghiệp vụ, tiếp tục chạy `DB_KLCN021/02_SeedData.sql`. Script seed có thể chạy lại an toàn.

   Tài khoản demo local sau khi chạy seed:

   | Vai trò | Email | Mật khẩu |
   | --- | --- | --- |
   | Admin | `admin@healthbeauty.local` | `HealthBeauty@123` |
   | Reception | `reception@healthbeauty.local` | `HealthBeauty@123` |
   | Customer | `customer@healthbeauty.local` | `HealthBeauty@123` |

   Các tài khoản trên chỉ dùng phát triển local. Không nạp seed này vào môi trường production và phải đổi mật khẩu nếu dùng trong môi trường dùng chung.

3. Cấu hình connection string và JWT key bằng User Secrets ở project API. Ví dụ với SQL Server Express:

   ```powershell
   cd HealthBeauty.Api
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost\SQLEXPRESS;Database=KLCN021_HealthBeauty;Trusted_Connection=True;TrustServerCertificate=True;"
   dotnet user-secrets set "Jwt:Key" "<chuoi-bi-mat-ngau-nhien-it-nhat-32-ky-tu>"
   dotnet restore
   dotnet run
   ```

   Thay `localhost\SQLEXPRESS` theo SQL Server instance của máy. Không commit connection string có thông tin đăng nhập, JWT key, hoặc User Secrets.

   Có thể tạo secret ngẫu nhiên bằng PowerShell: `[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))`.

4. Mở Swagger tại `http://localhost:5230/swagger`. Nếu cổng 5230 bận, chọn cổng khác bằng:

   ```powershell
   dotnet run --urls http://localhost:5231
   ```

## Luồng làm việc Web/App

- API base URL khi chạy local: `http://localhost:5230/api/v1`.
- Web/app gọi `auth/register` hoặc `auth/login`, sau đó gửi access token trong header `Authorization: Bearer <token>` cho endpoint cần đăng nhập.
- Khi web/app chạy trên thiết bị khác, `localhost` phải được thay bằng địa chỉ IP máy chạy API; cấu hình CORS và HTTPS phù hợp trước khi triển khai dùng chung.
- Danh mục endpoint: xem Swagger hoặc file `KLCN021_API_Catalog.xlsx`.
- Lịch hẹn dùng các trạng thái `ChoXacNhan`, `DaXacNhan`, `DaDen`, `DangThucHien`, `HoanThanh`, `DaHuy`.
- Giờ trống: `GET /api/v1/appointments/availability?date=YYYY-MM-DD` (alias tương thích: `available-slots`).
- Trên Android Emulator chạy API bằng `dotnet run --launch-profile http` và dùng base URL `http://10.0.2.2:5230/api/v1`. Trên thiết bị thật dùng `dotnet run --urls http://0.0.0.0:5230` và địa chỉ IP của máy.

## Lưu ý

- Một số endpoint nghiệp vụ cần SQL Server đang chạy và database đã được tạo từ script.
- Endpoint thanh toán hiện ghi nhận trạng thái thanh toán trong hệ thống, chưa tích hợp cổng thu tiền VNPay/MoMo.
- JWT secret phải được tạo riêng cho từng môi trường; không dùng ví dụ placeholder làm secret thật.

## Flutter booking update (2026-10-13)

- Authenticated `Customer` accounts can call `GET /api/v1/staff`; modifying staff and accessing schedules still requires `Admin` or `Manager`.
- `POST /appointments`, `POST /appointments/{id}/reschedule`, and `PUT /appointments/{id}` reject overlapping appointments for either the customer or the selected staff member with HTTP 409. Intervals are `[start, end)`: a 09:00?10:00 booking blocks 09:30 but allows 10:00. Cancelled bookings are ignored, and an appointment does not conflict with itself when moved. This also checks intervals crossing midnight.
- `AppointmentItemResponse` adds `durationMinutes` (integer); `expectedPrice` remains decimal. Duration uses the saved positive duration, otherwise the current service duration, otherwise 30 minutes. The overall appointment duration is the sum of its item durations (30 minutes for legacy appointments without items).
- The affected entries in `KLCN021_API_Catalog.xlsx` have been updated. Other catalog entries still describe older/planned contracts and were outside this change.
- Run regression tests: `dotnet test KLCN021_HealthBeauty.sln`. Tests use a separate EF InMemory database per case and do not modify the local SQL Server database.

## Priority API fixes (2026-10-13)

- Appointment/staff detail responses use finite projections and retain Vietnamese property names; EF back references/account navigation are omitted.
- Only Admin/Manager/Reception may confirm payment with POST `/invoices/{id}/payments`; customers receive403. This remains a staff acknowledgement of money received, without payment gateway integration.
- Creating an invoice requires a completed appointment and an exact match of booked standalone services, complete combo components and quantities. Unit prices come from the catalog database. Customer creation/read is retained for their own invoices; staff role takes precedence over any linked customer profile.
- Reschedule and PUT require `ChoXacNhan` or `DaXacNhan`; cancellation allows those states plus `DaDen`. Invalid transitions return409.
- Assigned appointments must fit their entire duration in one non-leave working shift; Create/PUT/reschedule return400 otherwise. Unassigned appointments remain allowed; selecting staff triggers the shift check.
- Availability/available-slots accept `date`, optional `staffId`, optional `serviceId`, and `durationMinutes` (default30, service duration takes precedence). Return individual candidate slots every30minutes with `nhanVienId`, `gioBatDau`, `gioKetThuc`; subtract full busy intervals including bookings carried from a previous day, ignore cancelled bookings and past starts.
- Combo component changes return409 while an uncancelled referencing appointment awaits invoicing, so billing validation can still match its composition. Create a different combo or finish invoicing first. Catalog records edited earlier have no historical composition snapshot.

## Remaining API fixes (2026-10-13)

- JWT checks the current account status, temporary lock and role on every authenticated request. Deactivation/role changes invalidate existing access tokens immediately. Failed login attempts are logged; default5wrongpasswords lock15minutes, configurable with `Authentication:MaxFailedAttempts` and `Authentication:LockoutMinutes`. Refresh honors temporary locks; logout only revokes the caller's refresh token.
- Management APIs require both their existing role allowlist and an active database permission grant; revocation takes effect on the next request with the same JWT. Customer owned operations/public reads retain their paths. There is no Admin grant bypass. Services/combos use SERVICE.WRITE, promotions/vouchers PROMOTION.WRITE, review moderation REVIEW.MODERATE; logs use ACCOUNT.READ. Full mapping: Services/DatabasePermissionFilter.cs.
- Existing databases: run `DB_KLCN021/03_ApiPermissionGrants.sql` to add missing Reception CUSTOMER.WRITE/STAFF.READ/INVOICE.WRITE and Staff STAFF.READ grants. It inserts only missing rows and preserves explicit revocations. New seed data includes the same grants. The migration has been prepared, not executed against the group's SQL database.
- Invoice redemption deducts only whole points actually applied and links the ledger to its invoice. A zero-total invoice is completed by an authorized staff payment confirmation without a payment row or earned points; response `{invoiceId,status,amount:0,paymentRequired:false}`. Positive payments retain PaymentResponse.
- Voucher creation/update share foreign-key, duplicate normalized code, nonnegative discount and future expiry validation. Validation/billing normalize code identically; customer voucher lists respect promotion dates. Promotion types are `PhanTram` (0..100) and `SoTien` (nonnegative).
- Booking prices derive from the database; client expectedPrice is ignored. Combo composition, quantities, active status and effective dates are verified; its total is allocated across component rows with a final rounding remainder. Duplicate combo service IDs are rejected.
- Staff can call GET `/staff/me/appointments` and `/staff/me/schedules`, and see only assigned appointments in `/appointments` and its detail endpoint. Reception can list staff. Staff deletion returns409 if any schedule/appointment references it; schedule updates validate employee existence and overlap.
- Moderation queue: GET `/reviews/pending` for Admin/Manager with REVIEW.MODERATE; public GET reviews remains visible-only.
- Concurrent writes, historical catalog snapshots and invoice cancellation/refund workflows still require additional implementation and SQL integration tests.
