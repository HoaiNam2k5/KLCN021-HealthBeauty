# Healthbeauty Mobile

Ứng dụng Flutter cho **khách hàng**, dùng chung `HealthBeauty.Api` và đường dẫn `api/v1` trong cùng repository với web quản trị. Tài khoản Admin/Reception/Staff sử dụng web quản trị.

## Yêu cầu và chạy

Flutter >= 3.38.1, Dart >= 3.10 và < 4.0. Cấu hình Android dùng AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14; cần JDK 17 trở lên và Android SDK.

Chạy các lệnh trong thư mục `HealthBeauty.Mobile`:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5230/api/v1
```

`10.0.2.2` là địa chỉ máy chạy API khi dùng Android Emulator. Với điện thoại thật, thay bằng IP LAN của máy chủ; API phải lắng nghe trên giao diện LAN và cổng tương ứng. Endpoint đã gồm `/api/v1`, không thêm dấu `/` cuối. API triển khai dùng HTTPS.

Flutter Web mặc định gọi `/api/v1` cùng origin; máy chủ web cần proxy đường dẫn này sang backend. Nếu truyền địa chỉ API khác origin bằng `--dart-define`, backend phải cho phép CORS cho origin của web. Web chỉ dùng để kiểm tra giao diện/API; nhắc lịch qua thông báo cục bộ dùng trên Android; repo chưa có cấu hình iOS.

```sh
flutter build web
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5230/api/v1
```

HTTP được cho phép trong bản Android debug để kết nối API local. Bản release sử dụng HTTPS.

## Clone và chạy trên Chrome

Repo có cấu hình Android, Web và Windows; chưa có thư mục iOS. Sau khi clone, `flutter pub get` và `flutter build apk` tự sinh cấu hình SDK local và Gradle wrapper theo máy. Không commit `android/local.properties`, cache Gradle hay thư mục build. Cấu hình SDK/JDK của mỗi thành viên phải sẵn sàng trước khi build Android.

Để thử Chrome với API chạy ở Development:

```sh
flutter run -d chrome --web-port=5174 --dart-define=API_BASE_URL=http://localhost:5230/api/v1
```

API Development cho phép CORS từ localhost/127.0.0.1 cổng 5173 và 5174. Nếu bỏ `API_BASE_URL`, Flutter Web dùng `/api/v1` cùng origin và cần reverse proxy. Hướng dẫn database, JWT và tài khoản demo nằm trong README gốc.


## Quy ước API

- Login/register lưu `accessToken`, `refreshToken`, `account`; refresh đồng thời dùng chung một request, logout xóa phiên và thu hồi refresh token của chính tài khoản.
- Hồ sơ, điểm và voucher cá nhân gọi `/customers/me`, `/customers/me/points`, `/customers/me/vouchers`; dữ liệu riêng được xóa khi đổi tài khoản.
- Combo gửi đủ từng dịch vụ theo số lượng cấu hình. Tổng thời lượng dùng để lấy giờ trống từ `/appointments/availability`; thời gian đặt lịch gửi theo giờ địa phương.
- Khung giờ trống phụ thuộc ca làm của nhân viên. Không có ca làm phù hợp thì màn đặt lịch hiển thị không có giờ trống.
- Voucher áp dụng khi lập hóa đơn, không trừ vào giá tạm tính khi đặt lịch. Giá cuối do backend tính.
- Lịch hẹn tải toàn bộ trang và cho phép hủy theo trạng thái backend. Không bao gồm kho/bán sản phẩm.

Đăng nhập Google và quên mật khẩu chưa có luồng API trong ứng dụng hiện tại. Cần bổ sung chức năng backend tương ứng trước khi triển khai các luồng này.
