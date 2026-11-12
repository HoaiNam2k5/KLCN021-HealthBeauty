# Sửa vé hẹn và xác nhận đặt lịch

Thư mục thực hiện: `D:/KhoaLuan/DEV/KLCN021_HealthBeauty`.

## Thay đổi

- `HealthBeauty.Mobile/lib/screens/booking_screen.dart`: giữ Navigator còn tồn tại trước khi đóng các route đặt lịch; callback chuyển tab không dùng context của State đã dispose. Kiểm tra tài khoản và thế hệ phiên đăng nhập sau các thao tác bất đồng bộ; bỏ biến messenger không dùng.
- `HealthBeauty.Mobile/lib/widgets/booking_success_dialog.dart`: đóng sheet bằng context của sheet, bảo vệ callback khi phiên đăng nhập thay đổi; giới hạn chiều cao và cuộn được; mã vé tự xuống dòng, nút chính tăng chiều cao theo chữ. Nhắc hẹn ghi nhận lựa chọn, không khẳng định hệ điều hành đã lập thông báo thành công.
- `HealthBeauty.Mobile/lib/widgets/spa_boarding_pass.dart`: bố cục co giãn với màn hình nhỏ và chữ lớn; trạng thái cuối chỉ xuất hiện một lần; giữ khối lịch, màu Rose, đường đục lỗ và thao tác mở chi tiết. Icon vé thay icon QR chưa có dữ liệu để quét.
- `HealthBeauty.Mobile/lib/screens/appointments_screen.dart`: chi tiết vé có chiều cao giới hạn và cuộn; thông tin KTV, voucher, lời nhắc, giá, đánh giá và phản hồi được xuống dòng. Mã hiển thị `#LH123` thống nhất, không thêm dấu # lần nữa. Hướng dẫn xuất trình mã để lễ tân đối chiếu; không mô tả là quét QR check-in tự động.
- `HealthBeauty.Mobile/test/ui_enhancements_test.dart`: cập nhật nội dung nhắc hẹn và icon vé.
- `HealthBeauty.Mobile/test/ticket_ui_regression_test.dart`: 16 trường hợp mới kiểm tra route thực, hai đích chuyển tab, phiên hết hạn, Back, thẻ bốn trạng thái, sheet nhiều dịch vụ, màn hình 320x568 và chữ gấp đôi; mở chi tiết thực qua AppointmentsScreen để kiểm tra hóa đơn, đổi/hủy lịch và đánh giá/phản hồi.

Các hành động hóa đơn, đổi/hủy lịch, đánh giá và thông tin sử dụng gói được giữ lại. Không sửa API, database, cấu hình SePay hoặc dependency trong tác vụ này. Không push/deploy.

## Bằng chứng kiểm tra

- `flutter test --no-pub --reporter expanded`: **181 tests passed**, exit 0. Log `.local-integration/ticket-fix-full-tests.log`.
- `flutter analyze --no-pub`: **No issues found!**, exit 0. Log `.local-integration/ticket-fix-analyze.log`.
- Các test chi tiết chữ lớn ban đầu phát hiện tràn hàng tạm tính 31px; sau sửa wrap/bố cục giá, test chi tiết và bộ đầy đủ đều đạt. Log tái hiện `.local-integration/ticket-fix-detail.log`.
- `git diff --check` trên các file tracked của tác vụ: exit 0.

- `flutter build apk --release --no-pub`: **Built build/app/outputs/flutter-apk/app-release.apk (58.1MB)**, exit 0; Gradle 283.9 giây. Log `.local-integration/ticket-fix-apk.log`. Có cảnh báo plugin firebase_core/KGP và Java 8 deprecated; build vẫn thành công.
- APK: 60.888.995 bytes, SHA256 `A2521EBD9D9404ADAA5E8147B34333260DCA09CBE4711EFC02DD853F5AE6884D`.

Chưa cài APK mới lên điện thoại thật, kiểm thử đặt lịch có ghi dữ liệu trên production, thông báo hệ điều hành hay một giao dịch ngân hàng mới. Mã vé hiện phục vụ đối chiếu thủ công, chưa có chức năng scanner check-in.
