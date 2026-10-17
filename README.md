# KLCN021 HealthBeauty

Hệ thống quản lý spa HealthBeauty gồm web quản trị React, ứng dụng Flutter cho khách hàng và một ASP.NET Core Web API dùng chung. Phạm vi hiện tại không gồm kho và bán sản phẩm.

## Clone bản tích hợp

```powershell
git clone --branch feature/healthbeauty-web-mobile-ready --single-branch https://github.com/HoaiNam2k5/KLCN021-HealthBeauty.git
cd KLCN021-HealthBeauty
```

```text
KLCN021-HealthBeauty/
├── HealthBeauty.Api/        # ASP.NET Core Web API /api/v1
├── HealthBeauty.Api.Tests/  # Kiểm thử API
├── DB_KLCN021/              # SQL Server schema, seed và cập nhật quyền
├── HealthBeauty.Web/        # React / TypeScript / Vite cho quản trị
└── HealthBeauty.Mobile/     # Flutter cho khách hàng
```

## Yêu cầu

- .NET 8 SDK và SQL Server; SSMS hoặc công cụ chạy script SQL.
- Web: Node.js `^20.19.0`, `^22.13.0` hoặc `>=24.0.0`, npm. Node 24 đã được kiểm tra.
- Mobile: Flutter >=3.38.1, Dart >=3.10 và <4.0. Android cần JDK >=17 và Android SDK; cấu hình dùng AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14.
- Cấu hình máy cá nhân, database đang dùng, JWT key, cache và file build không được đưa vào repository. Mỗi thành viên cấu hình API trên máy mình.

## 1. Database và API

Chạy lần lượt trong SSMS:

1. `DB_KLCN021/KLCN021_HealthBeauty.sql`: tạo database và 28 bảng nghiệp vụ, gồm khôi phục mật khẩu và thông báo.
2. `DB_KLCN021/02_SeedData.sql`: tạo dữ liệu demo, vai trò và quyền mặc định; có thể chạy lại.
3. `DB_KLCN021/03_ApiPermissionGrants.sql`: bổ sung các quyền còn thiếu trên database đã tồn tại, giữ các quyền đã bị thu hồi.

Trong terminal tại thư mục repo, cấu hình User Secrets. Thay SQL Server instance theo máy của thành viên:

```powershell
cd HealthBeauty.Api
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost\SQLEXPRESS;Database=KLCN021_HealthBeauty;Trusted_Connection=True;TrustServerCertificate=True;"

# Sinh khóa riêng, dùng được cả Windows PowerShell 5.1.
$jwtBytes = New-Object byte[] 48
$jwtRng = [Security.Cryptography.RandomNumberGenerator]::Create()
$jwtRng.GetBytes($jwtBytes)
$jwtKey = [Convert]::ToBase64String($jwtBytes)
$jwtRng.Dispose()
dotnet user-secrets set "Jwt:Key" $jwtKey
Remove-Variable jwtKey, jwtBytes, jwtRng

dotnet restore
dotnet run --launch-profile http
```

API: `http://localhost:5230/api/v1`. Swagger: `http://localhost:5230/swagger`.

Trong Development, có thể dùng `HealthBeauty.Api/appsettings.Development.local.json` thay cho User Secrets. File local được bỏ qua bởi Git và không đưa vào publish. Environment variables và tham số dòng lệnh có ưu tiên cao hơn.

## 2. Web quản trị

Mở terminal khác tại thư mục repo:

```powershell
cd HealthBeauty.Web
npm ci
npm run dev
```

Mở `http://localhost:5173`. Proxy Vite chuyển `/api` sang API cổng 5230; mặc định không cần tạo `.env`. Nếu cần đổi cấu hình, sao chép `.env.example` thành `.env` và sửa `VITE_API_BASE_URL`.

Tài khoản demo sau khi chạy seed:

| Vai trò | Email | Mật khẩu demo |
| --- | --- | --- |
| Admin | `admin@healthbeauty.local` | `HealthBeauty@123` |
| Reception | `reception@healthbeauty.local` | `HealthBeauty@123` |
| Customer | `customer@healthbeauty.local` | `HealthBeauty@123` |

Web dành cho Admin, Manager, Reception, Staff. Customer đăng nhập trên Flutter. Các tài khoản demo chỉ dùng phát triển local.

## 3. Flutter khách hàng

Mở terminal khác tại thư mục repo:

```powershell
cd HealthBeauty.Mobile
flutter pub get

# Android Emulator: 10.0.2.2 trỏ về máy chạy API.
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5230/api/v1
```

Kiểm tra trên Chrome với API chạy bằng profile Development:

```powershell
flutter run -d chrome --web-port=5174 --dart-define=API_BASE_URL=http://localhost:5230/api/v1
```

API Development cho phép CORS từ localhost/127.0.0.1 cổng 5173 và 5174. Khi bỏ `API_BASE_URL`, Flutter Web dùng `/api/v1` cùng origin và cần reverse proxy. Bản production cần cấu hình HTTPS, proxy/CORS theo môi trường triển khai.

Điện thoại Android thật dùng IP LAN của máy chạy API; chạy API với `dotnet run --launch-profile http --urls http://0.0.0.0:5230`, thay base URL bằng `http://<IP-LAN>:5230/api/v1` và cho phép cổng qua firewall. HTTP local được cho phép trong Android debug; release dùng HTTPS.

Repo hiện có cấu hình Android, Web và Windows; chưa có cấu hình iOS. Thông báo nhắc lịch không áp dụng trên Flutter Web.

## Tạo nhân viên và đặt lịch

- Admin hoặc vai trò được cấp `STAFF.WRITE` vào **Nhân viên → Thêm nhân viên**, nhập hồ sơ, email và mật khẩu ban đầu. API tự tạo tài khoản vai trò Staff và hồ sơ nhân viên liên kết trong một transaction. Mật khẩu được hash; email trùng trả HTTP 409.
- Khách chọn `NhanVienId` để đặt lịch. Staff đăng nhập bằng tài khoản có `TaiKhoanId` liên kết và chỉ thấy lịch được phân công; hai mã không cần bằng nhau.
- Với hồ sơ nhân viên có sẵn, Admin vào **Tài khoản → Tạo tài khoản/Gán vai trò → Staff → Liên kết nhân viên hiện có**. Hồ sơ đã thuộc tài khoản khác không được chọn. Đổi liên kết yêu cầu hồ sơ cũ chưa có lịch hẹn hoặc ca làm.
- Tạo ca làm trong tương lai ở **Lịch làm việc** trước khi khách đặt lịch. Giờ trống phải nằm trọn trong ca, đủ thời lượng dịch vụ/combo và không trùng lịch.
- Quyền quản trị được gán theo vai trò trong database. Web dùng `GET /auth/permissions` để hiện menu/nút; API tiếp tục kiểm tra quyền và quyền sở hữu dữ liệu.

## Kiểm thử và build

Chạy tại thư mục repo:

```powershell
dotnet test HealthBeauty.Api.Tests/HealthBeauty.Api.Tests.csproj
```

Trong `HealthBeauty.Web`: `npm test`, `npm run lint`, `npm run build`.

Trong `HealthBeauty.Mobile`: `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5230/api/v1`.

Nếu Vite báo `spawn EPERM` khi nạp cấu hình trên Windows, dùng `npm run dev -- --configLoader native` hoặc `npm run build -- --configLoader native` với Node hỗ trợ nạp TypeScript.

Chi tiết từng frontend: [Web README](HealthBeauty.Web/README.md), [Mobile README](HealthBeauty.Mobile/README.md). Hợp đồng API: Swagger và `KLCN021_API_Catalog.xlsx`; các dòng catalog chưa có trong Swagger được đánh dấu riêng.

## Phạm vi chức năng

API phục vụ tài khoản/phân quyền, khách hàng, nhân viên/ca làm, dịch vụ/combo, lịch hẹn, hóa đơn/ghi nhận thanh toán, khuyến mãi/voucher, điểm thưởng, đánh giá, báo cáo và nhật ký quản trị. Thanh toán hiện ghi nhận giao dịch trong hệ thống, chưa tích hợp VNPay/MoMo. Đăng nhập Google/OAuth chưa có luồng hoàn chỉnh. API quên mật khẩu đã triển khai; xem [hợp đồng và cấu hình SMTP](HealthBeauty.Api/PASSWORD_RECOVERY.md). Database có sẵn cần chạy thêm `DB_KLCN021/04_PasswordRecovery.sql` trước khi dùng API mới.

API service reviews and appointment invoice metadata: [integration contract](HealthBeauty.Api/REVIEWS.md). Existing databases must run `DB_KLCN021/05_ReviewInvoiceUniqueness.sql`.

API thông báo: xem [mục 11 hướng dẫn tích hợp](HealthBeauty.Api/REVIEWS.md#11-thông-báo-trong-ứng-dụng-và-thông-báo-đẩy-firebase). Database có sẵn chạy thêm `DB_KLCN021/06_Notifications.sql`; khóa Firebase cấu hình riêng trên server, không commit.
