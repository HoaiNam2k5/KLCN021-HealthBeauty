# HealthBeauty

Flutter đã có danh mục gói dịch vụ, gói của tôi/số lượt/lịch sử và đặt lịch dùng gói: [hướng dẫn](docs/GOI_DICH_VU_FLUTTER.md). Dùng API/SQL13 hiện có; khách đăng ký mua, quản trị xác nhận thu tiền.

Ảnh đại diện/đổi mật khẩu khách hàng: Flutter đã sửa, **API gốc còn chờ áp dụng bằng PowerShell quản trị** do 4 file không cho ghi; xem [hướng dẫn API/SQL15 và cách test](docs/HO_SO_KHACH_HANG.md).

Đặt lịch theo nhân viên: xem [ngày còn lịch trống và cách test](docs/LICH_TRONG_NHAN_VIEN.md). API và Flutter đã bổ sung đánh dấu ngày còn giờ và nút tìm ngày gần nhất; không cần SQL mới.

Dự án chung gồm **một API**, một web quản trị và một ứng dụng Flutter. Bản hợp nhất local ngày 24/10/2026 giữ API mới nhất đã áp dụng, web từ `feature/huynh-web` (2ca4f83), Flutter từ `feature/mobile-app` (b1bbb99) và toàn bộ sửa đổi local liên quan. Chưa commit/push bản hợp nhất.

```text
KLCN021_HealthBeauty/
├── HealthBeauty.Api/         # ASP.NET Core .NET 8, cổng 5230
├── HealthBeauty.Api.Tests/   # Kiểm thử API
├── DB_KLCN021/               # Schema, seed, migration 03–14
├── HealthBeauty.Web/         # React/TypeScript/Vite, cổng 5173
├── HealthBeauty.Mobile/      # Flutter, dùng chung API
├── CHAY_API.ps1
├── CHAY_WEB.ps1
└── CHAY_FLUTTER.ps1
```

## Chạy trên máy anh

Mở ba terminal PowerShell tại thư mục dự án này, chạy lần lượt:

```powershell
.\CHAY_API.ps1
```

```powershell
cd HealthBeauty.Web
npm ci
cd ..
.\CHAY_WEB.ps1
```

Mở Android emulator trước, sau đó:

```powershell
.\CHAY_FLUTTER.ps1
# Thiết bị khác: .\CHAY_FLUTTER.ps1 -Device <id>
# Chrome: .\CHAY_FLUTTER.ps1 -Device chrome
```

Swagger: http://localhost:5230/swagger. Web: http://localhost:5173.
Android emulator gọi API qua `http://10.0.2.2:5230/api/v1`; Chrome dùng `http://localhost:5230/api/v1`. Điện thoại thật dùng `-ApiBaseUrl http://<IP-may-chay-API>:5230/api/v1` và phải cấu hình API nghe địa chỉ LAN.

## SDK và cấu hình

- .NET 8 SDK, SQL Server; cấu hình ConnectionStrings/Jwt bằng User Secrets hoặc appsettings.Development.local.json (không commit).
- Node.js 20.19+, 22.13+ hoặc 24+; máy hiện tại dùng Node 24.
- Flutter hiện tại yêu cầu **Dart ^3.13.4**; máy anh đã có Flutter **3.47.7 / Dart 3.13.5** trong `D:/KhoaLuan/.tools/flutter-3.47.7`. Script tự chọn SDK này nếu tồn tại; máy khác cần cài SDK tương thích.
- Cấu hình Firebase đã đặt tại `HealthBeauty.Mobile/lib/firebase_options.dart` và `HealthBeauty.Mobile/android/app/google-services.json`. Cần thay file JSON mới sau khi đăng ký SHA trên Firebase; không sửa certificate_hash local để thay đăng ký Console.
- [Hướng dẫn Google Android](HealthBeauty.Mobile/GOOGLE_LOGIN_ANDROID.md).

## Database

Database đang chạy được giữ nguyên, không tự chạy SQL khi hợp nhất. Database mới dùng schema gốc và seed; database đã có dữ liệu chỉ chạy các migration còn thiếu theo thứ tự trong `DB_KLCN021`. Không chạy lại schema tạo mới trên database đang dùng.

SQL13 là gói dịch vụ. SQL14 bổ sung OTP đăng nhập; chưa xác nhận SQL14 được áp dụng trên máy anh, nên `Authentication:TwoFactor:Enabled` vẫn để false. Chỉ bật sau khi đã chạy SQL14 và cấu hình SMTP.

## Bàn giao và kiểm thử

- [Tổng hợp thay đổi](REVIEWS.md)
- [API: Google/OTP/logout/review](HealthBeauty.Api/MOBILE_AUTH_INTEGRATION.md)
- [API: lịch sử thay đổi](HealthBeauty.Api/REVIEWS.md)
- [Flutter: ảnh dịch vụ và Google](HealthBeauty.Mobile/REVIEWS.md)
- [Gói dịch vụ](HUONG_DAN_GOI_DICH_VU.md)
- [Báo cáo cho thành viên web](BAO_CAO_TONG_HOP_CHO_WEB.md)
- [Kết quả hợp nhất](docs/HOP_NHAT_2026-10-24.md)

```powershell
dotnet test .\KLCN021_HealthBeauty.sln
cd HealthBeauty.Web
npm test
npm run build -- --configLoader native
cd ..\HealthBeauty.Mobile
flutter pub get
flutter analyze
flutter test
```

Google OAuth/SMTP/push thật cần cấu hình dịch vụ tương ứng; việc gom source không tự hoàn tất các bước cấu hình ngoài dự án. Không có module kho/bán sản phẩm trong phạm vi nhóm.
