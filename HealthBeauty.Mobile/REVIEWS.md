# Ghi nhận thay đổi Flutter

## 23/10/2026 — Đồng bộ ảnh dịch vụ/combo với web quản trị

Nguyên nhân: API đã trả imageUrl nhưng Service/Combo bỏ qua field này; thẻ danh mục tự chọn ảnh Unsplash theo tên. Vì vậy ảnh trên app có thể khác ảnh quản trị lưu.

Đã sửa:
- lib/models/catalog.dart: đọc và giữ imageUrl, tương thích dữ liệu cũ chưa có ảnh.
- lib/widgets/catalog_image.dart: widget dùng đúng URL API; placeholder tiếng Việt khi thiếu/đang tải/lỗi ảnh, không thay bằng ảnh dịch vụ khác.
- lib/widgets/service_tile.dart: dùng ảnh API cho cả dịch vụ/combo, bỏ toàn bộ URL Unsplash tự đoán.
- lib/screens/service_detail_screen.dart: hiện cùng ảnh trên trang chi tiết, đọc bản dịch vụ/combo mới nhất từ danh mục khi rebuild.
- lib/screens/services_screen.dart: kéo làm mới được cả khi danh sách ít/chưa có mục.
- Không đổi API, pubspec, Firebase config, thông tin đăng nhập hoặc phiên bản SDK.

Kiểm chứng:
- test/catalog_images_contract_check.dart: 6/6 kiểm tra API imageUrl đạt (dịch vụ/combo, URL đổi sau tải lại, trim, DTO cũ không có ảnh).
- Phân tích tĩnh bằng analysis_server_aot của Dart3.13.5: 6file thay đổi không có lỗi/cảnh báo/lint. Kết quả ở ../catalog-image-static-results.json.
- API local GET /services trả200, 12dịch vụ,10imageUrl; chưa có URL Cloudinary trong danh sách hiện tại. Chưa xác minh ảnh upload mới đã được Lưu vào dịch vụ.
- flutter analyze qua CLI bị Windows chặn tạo tiến trình con (CreateFile5); đã dùng trực tiếp analyzer entrypoint để kiểm tra. Chưa chạy toàn bộ flutter test hoặc kiểm tra giao diện trên thiết bị.

Cách thử: trên web Sửa dịch vụ/combo → Tải ảnh → bấm Lưu; trong terminal Flutter nhấn R để hot restart lần đầu sau sửa model, rồi kéo xuống tải lại trang Dịch vụ. Mở chi tiết phải cùng ảnh với danh sách. Khi đổi ảnh trên web, kéo làm mới để nhận imageUrl mới. Chưa commit/push.


## 23/10/2026 — Google chọn tài khoản rồi không phản hồi

Đã đối chiếu APK cài trên emulator với APK local, xác minh debugSHA1 máy anh khác OAuth Android certificate_hash trong google-services.json nhóm. API /auth/google có thật; emulator log AccountReauthFragment lỗi8. Chưa xem Console nên chưa kết luận chỉ một nguyên nhân.

Sửa AuthProvider: không nuốt initialize/canceled, init SDK một lần, chặn IDtoken thiếu trước API, chặn bấm lặp, bỏ kết quả muộn sau đổi phiên/dispose. LoginScreen có tiến trình/thông báo; helper lỗi tiếng Việt lib/core/google_login_error.dart. Thêm5test hồi quy vào auth_profile_test.dart (chưa chạy Fluttertest trong môi trườngagent).

Hướng dẫn fingerprint và bước Firebase/Google Console trong GOOGLE_LOGIN_ANDROID.md. Không tự sửa JSON để giả đăng ký SHA. Cần người có quyền Console thêm fingerprint và tải lại cấu hình, rebuildAndroid. Không thay private keys/tài khoản Google của ai; không đổi API/SDK/pubspec.

Kiểm chứng Googlefix: 5/5 kiểm tra thông báo lỗi thuần Dart đạt; analyzer trực tiếp trên4file thay đổi có0diagnostics; diffcheck sạch. Chưa chạy5test Flutter mới hoặc xác minh GoogleOAuth thật.
# 24/10/2026 — Chọn ngày còn giờ theo nhân viên

## Khách hàng đổi ảnh đại diện và mật khẩu

- Thêm `image_picker`1.2.4, chọn PNG/JPEG/WebP tối đa5MB; upload/xóa avatar qua `/customers/me/avatar`, response Customer có `avatarUrl`. Ảnh cập nhật ngay trên tài khoản/chỉnh sửa; cập nhật hồ sơ vẫn giữ ảnh.
- Thêm menu/màn đổi mật khẩu hiện tại/mới/xác nhận, gọi PUT `/auth/change-password`; backend204 thì xóa phiên local và yêu cầu đăng nhập lại.
- Refresh token hỗ trợ gửi lại multipart, nhưng chỉ trong cùng phiên: đổi tài khoản vô hiệu request/response cũ. Không tự tải ảnh gián đoạn vào tài khoản khác.
- `CHAY_FLUTTER.ps1` chạy pub get trước khi run để đăng ký plugin; cần dừng/chạy lại app.
- **Chờ API/SQL15 áp dụng về gốc** bằng script quản trị: [Hướng dẫn](../docs/HO_SO_KHACH_HANG.md). UI đã sửa nhưng endpoint root chưa có đến khi áp dụng.

## Nhân viên mới chưa xuất hiện

- API `/staff` trả toàn bộ nhân viên, không lọc theo ca làm; app trước đây chỉ tải danh sách lúc khởi tạo/đăng nhập nên có thể giữ danh sách cũ.
- Đã thêm tải lại khi vào bước chọn nhân viên; có nút **Cập nhật danh sách nhân viên**, trạng thái đang tải và lỗi/retry để không im lặng khi gọi API thất bại.
- Thêm nhân viên làm họ xuất hiện trong danh sách; muốn có giờ đặt vẫn phải tạo ca làm trên web. Không đổi API/CSDL hay hành vi xóa dữ liệu nhân viên khi đổi tài khoản.

- Bước đặt lịch đánh dấu ngày còn giờ, chỉ cho chọn ngày phù hợp trong hôm nay đến 60 ngày sau.
- Nút **Lịch trống gần nhất** chuyển tới ngày sớm nhất còn giờ; khách chọn giờ rồi xác nhận như trước. Có nút cập nhật lịch và thông báo khi không có ngày phù hợp.
- Tải lại theo nhân viên/dịch vụ, bỏ phản hồi cũ; lọc thêm giờ trùng lịch khách và ngày combo không còn hiệu lực.
- Dùng API `/appointments/availability/days`; cần chạy bản API mới trong thư mục gốc. Không cần SQL.
- Chi tiết: [Luồng và cách test](../docs/LICH_TRONG_NHAN_VIEN.md).
- Kiểm chứng: 50 file lib/test phân tích trực tiếp không diagnostic, logic lịch độc lập6/6; Flutter test5trường hợp đã thêm nhưng chưa chạy do Windows CreateFile5 khi gọi vswhere. Chưa kiểm tra giao diện trên emulator; cần khởi động lại API/Flutter để test thủ công.


## Phát hành main 24/10/2026

API ảnh đại diện/đổi mật khẩu đã tích hợp cùng Flutter trên main. Các trạng thái chờ apply ở lịch sử trên không còn áp dụng cho bản clone main; cần chạy SQL15 trên database có sẵn và cấu hình Cloudinary/Firebase riêng.
