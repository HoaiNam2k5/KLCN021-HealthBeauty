# HealthBeauty

Một repository gồm ASP.NET Core API dùng chung, web quản trị React và ứng dụng khách hàng Flutter. Nhánh `main` tích hợp API/SQL mới nhất, web `feature/huynh-web` và mobile `feature/mobile-app`, cùng các sửa lỗi đặt lịch, hồ sơ, phân quyền và giao diện. Phạm vi nhóm không gồm kho/bán sản phẩm.

```text
HealthBeauty.Api/         API .NET 8 — cổng 5230
HealthBeauty.Api.Tests/   Kiểm thử API
DB_KLCN021/               Schema, seed và các cập nhật SQL03–15
HealthBeauty.Web/         React/TypeScript/Vite — cổng 5173
HealthBeauty.Mobile/      Flutter cho khách hàng
docs/                    Hướng dẫn tích hợp và kiểm tra
```

## Clone và yêu cầu

```powershell
git clone --branch main https://github.com/HoaiNam2k5/KLCN021-HealthBeauty.git
cd KLCN021-HealthBeauty
```

- .NET 8 SDK, SQL Server và SSMS.
- Node.js 20.19+ (nhánh20), 22.13+ (nhánh22) hoặc24+; đã kiểm tra Node24.
- Flutter tương thích **Dart ^3.13.4**; bản dùng kiểm tra mã là Flutter3.47.7/Dart3.13.5. Android cần SDK/JDK theo cấu hình Gradle của dự án.

## Database và cấu hình API

Database mới: chạy `DB_KLCN021/KLCN021_HealthBeauty.sql`, rồi `02_SeedData.sql` trong SSMS. Database đang có dữ liệu: chỉ chạy các script cập nhật còn thiếu theo thứ tự03–15, không chạy lại schema tạo mới. SQL13 là gói dịch vụ; SQL14 là OTP đăng nhập tùy chọn; **SQL15 thêm cột ảnh đại diện AvatarUrl và phải có trước khi chạy API này**. SQL15 chạy lại an toàn và không xóa dữ liệu.

Mỗi máy tự cấu hình kết nối SQL và JWT bằng User Secrets:

```powershell
cd HealthBeauty.Api
dotnet user-secrets set "ConnectionStrings:DefaultConnection" 'Server=.\SQLEXPRESS;Database=KLCN021_HealthBeauty;Trusted_Connection=True;TrustServerCertificate=True;'
$jwtBytes = New-Object byte[] 48
$jwtRng = [Security.Cryptography.RandomNumberGenerator]::Create()
$jwtRng.GetBytes($jwtBytes)
dotnet user-secrets set "Jwt:Key" ([Convert]::ToBase64String($jwtBytes))
$jwtRng.Dispose()
Remove-Variable jwtBytes, jwtRng
cd ..
```

Có thể dùng `HealthBeauty.Api/appsettings.Development.local.json` trên máy cá nhân; file này bị gitignore. Không commit mật khẩu SQL/SMTP, JWT key, Cloudinary ApiSecret hoặc Firebase service account. Cấu hình Cloudinary/SMTP/push là riêng từng máy; xem [hướng dẫn API](HealthBeauty.Api/MOBILE_AUTH_INTEGRATION.md) và [hồ sơ khách hàng](docs/HO_SO_KHACH_HANG.md).

OTP đăng nhập mật khẩu mặc định tắt; chỉ bật `Authentication:TwoFactor:Enabled` sau SQL14 và SMTP hợp lệ. Google login vẫn cần OAuth/SHA được đăng ký đúng dự án Firebase.

## Chạy API, web, Flutter

Mở các terminal riêng tại thư mục repository:

```powershell
.\CHAY_API.ps1
```

```powershell
cd HealthBeauty.Web
npm ci
cd ..
.\CHAY_WEB.ps1
```

Flutter: lấy `google-services.json` của dự án Firebase từ nhóm/Console, đặt tại `HealthBeauty.Mobile/android/app/google-services.json` (file local không đưa lên Git). Android package là `com.example.app_doancunhan`; máy tự build debug cần đăng ký SHA của chữ ký debug. `lib/firebase_options.dart` chứa cấu hình client công khai; khi dùng dự án Firebase khác phải cập nhật đồng bộ file này và OAuth client IDs phía API.

Mở Android emulator, chạy:

```powershell
.\CHAY_FLUTTER.ps1
# Thiết bị khác: .\CHAY_FLUTTER.ps1 -Device <device-id>
# Chrome: .\CHAY_FLUTTER.ps1 -Device chrome
```

Scripts dùng Flutter3.47.7 tại `../../.tools/flutter-3.47.7` nếu có, nếu không dùng Flutter trên PATH. Script chạy `flutter pub get` trước để cập nhật plugin native. Google Sign-In đang được tích hợp cho Android; chưa xác nhận luồng Google trên Chrome.

Swagger: http://localhost:5230/swagger — Web: http://localhost:5173.
Android emulator gọi `http://10.0.2.2:5230/api/v1`; Chrome dùng localhost. Điện thoại thật dùng `-ApiBaseUrl http://<IP-may-API>:5230/api/v1` và cấu hình API nghe LAN.

## Tài liệu và kiểm thử

- [Thay đổi tích hợp](REVIEWS.md)
- [Google/OTP/logout/review API](HealthBeauty.Api/MOBILE_AUTH_INTEGRATION.md)
- [Ngày còn lịch theo nhân viên](docs/LICH_TRONG_NHAN_VIEN.md)
- [Ảnh đại diện và đổi mật khẩu](docs/HO_SO_KHACH_HANG.md)
- [Lịch sử backend](HealthBeauty.Api/REVIEWS.md)

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

API kiểm thử bằng database cô lập, không tự chạy migration trên SQL thật. Kiểm tra mã/contract Flutter không thay thế kiểm thử Android thực; Google OAuth, SMTP, Cloudinary và push cần cấu hình và test dịch vụ thật trên máy thành viên.
