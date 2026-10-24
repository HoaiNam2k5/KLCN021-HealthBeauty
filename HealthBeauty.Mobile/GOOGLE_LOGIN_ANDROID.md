# Sửa đăng nhập Google trên Android Emulator

## Kết quả kiểm tra máy anh

- Emulator: emulator-5554, ứng dụng com.example.app_doancunhan.
- Đã xác minh APK đang cài giống APK debug local bằng SHA256 của toàn tệp.
- Chứng chỉ ký APK/debug.keystore của máy:

SHA-1:
`4C:DB:41:09:A4:DB:50:57:5B:C4:E3:16:BC:41:26:6A:0C:A7:EB:51`

SHA-256:
`DF:54:92:6B:24:F1:7A:9F:BD:64:78:E3:C6:A4:AE:78:66:8D:97:C7:99:30:04:46:20:0A:A9:BB:2B:D8:2E:31`

- google-services.json hiện chỉ có một OAuth Android certificate_hash khác (d4e807...); chưa có SHA-1 máy anh trong bộ cấu hình local được cung cấp. Chưa truy cập được Console để xác nhận danh sách SHA phía server, nên không kết luận đây là nguyên nhân duy nhất.
- Log emulator: AccountReauthFragment lỗi8 Unknown error sau chọn tài khoản. API hiện tại có /auth/google.
- Plugin Google Sign-In Android có thể trả canceled sau chọn tài khoản khi cấu hình chưa đúng. Code app trước đó bỏ qua canceled nên không hiện lỗi nào.

## Anh/thành viên có quyền Firebase cần làm

1. Mở Firebase Console → chọn đúng dự án của bộ cấu hình nhóm.
2. Project settings (biểu tượng bánh răng) → General → Your apps → Android com.example.app_doancunhan.
3. Trong SHA certificate fingerprints, thêm SHA-1 máy anh ở trên; thêm SHA-256 tương ứng. **Giữ nguyên SHA của thành viên khác**.
4. Lưu. Kiểm tra OAuth Android client trong Google Cloud cùng dự án có đúng package và SHA-1 này; serverClientId phải là OAuth Web client của cùng dự án.
5. Tải lại google-services.json, thay file tại HealthBeauty.Mobile/android/app/google-services.json của dự án chung KLCN021_HealthBeauty.
6. Dừng app hiện tại, chạy lại bản Android để cấu hình native mới được đóng gói (hot reload không thay cấu hình native):

```powershell
cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty\HealthBeauty.Mobile
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5230/api/v1
```

Không chỉ sửa chuỗi certificate_hash trong JSON ở máy: phải đăng ký fingerprint trên Console. File JSON local không thể tự thay cấu hình OAuth trên server.

## Code đã sửa

- AuthProvider không nuốt lỗi initialize/canceled, khởi tạo Google SDK một lần, kiểm tra có ID token trước gọi API, có trạng thái đang đăng nhập và ngăn bấm lặp/phản hồi muộn.
- LoginScreen hiện tiến trình và thông báo tiếng Việt thay vì quay lại im lặng.
- Các thay đổi chỉ ở Flutter clone đang chạy; không đổi Google/Firebase credentials, backend hoặc cấu hình SDK.

## Giới hạn

Chưa đăng nhập Google thật thành công sau thay SHA vì bước Console cần thành viên có quyền thực hiện. Nếu đã có đúng fingerprint phía server mà còn lỗi, đối chiếu Google Play Services/phiên bản emulator/tài khoản OAuth test và log mới; không đoán nguyên nhân từ canceled đơn thuần.

Nguồn plugin: https://pub.dev/packages/google_sign_in_android (Troubleshooting).
