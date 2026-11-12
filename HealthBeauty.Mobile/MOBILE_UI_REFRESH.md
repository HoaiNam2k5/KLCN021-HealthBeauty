# Giao diện HealthBeauty 1.1.0+2 — 27/10/2026

Đã áp dụng vào source chính tại `D:/KhoaLuan/DEV/KLCN021_HealthBeauty/HealthBeauty.Mobile` trên nhánh `agent/mobile-ui-refresh-20261027`. Giữ các chỉnh sửa có sẵn trước phiên làm việc; chưa commit/push hoặc deploy API/Web.

## Thay đổi

- Trang chủ: logo/chào/thông báo, tìm dịch vụ thực sự truyền truy vấn sang danh mục, lịch hẹn và nhắc hóa đơn, banner, bốn lối tắt **Dịch vụ / Gói dịch vụ / Ưu đãi / Cơ sở**, danh mục nổi bật và gói đang bán từ API.
- Cơ sở: bản đồ tương tác OpenStreetMap và marker cho địa chỉ người dùng cung cấp **140 Lê Trọng Tấn, Tây Thạnh, Tân Phú, TP. Hồ Chí Minh**; chỉ đường, Google Maps và sao chép địa chỉ. Có thông báo tải bản đồ/mở liên kết thất bại. Không xin quyền vị trí thiết bị.
- KTV cuối Trang chủ: năm poster Trinh, Puu, Changg, Kiwi, Quỳnh, vuốt ngang; xem tất cả; mở ảnh đầy đủ và zoom đến4x. Ảnh giữ nội dung/tỉ lệ, mã hóa WebP1000×1333, tổng663.488byte. Chỉ giới thiệu; không tự ghép với mã nhân viên trong API.
- Thanh dưới: Trang chủ / Dịch vụ / **Đặt lịch** / Lịch hẹn / Tài khoản. Giữ nguyên chỉ số tab logic0/1/2/3/4 cho code cũ; Ưu đãi vẫn mở từ shortcut, tài khoản và banner. Đặt lịch giữ chặn đăng nhập và kiểm tra phiên.
- Dịch vụ/combo: thẻ trắng/rose, giá/thời lượng rõ; giữ rating và số lượt đặt thực; bỏ nhãn VOUCHER/Yêu thích/Hot gắn cứng. Tìm kiếm có nút xóa, lọc giá/danh mục giữ nguyên. Grid đổi1cột trên màn nhỏ hoặc chữ lớn.
- Chi tiết dịch vụ: nút đặt lịch cố định phía dưới, xử lý vùng an toàn/bàn phím. Gói: nhấn mạnh giá, thời hạn; gói đã mua có thanh tiến độ lượt đã dùng theo dữ liệu thật.
- Đặt lịch: hướng dẫn ba bước, tiêu đề tự xuống dòng, quay lại bước đã qua, khóa khi đang gửi. Vé hẹn/tab lịch/ưu đãi/tài khoản đồng bộ mô tả và khoảng cách. Không đổi quy tắc quá ngày, trạng thái nghiệp vụ hay API.
- Hóa đơn: giá và trạng thái dễ nhận biết; giữ QR, polling, liên kết và xác nhận thanh toán phía server. Auth/inputs/appbar đồng bộ theme trắng/rose.

## Kiểm chứng

- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --reporter expanded`: **191 passed**, không lỗi. Sau chỉnh màu tiêu đề viewer, chạy lại2gallerytests: **2 passed**.
- Kiểm tra mới: Home/shortcuts/navigation tại320px, chữ1.6x; ánh xạ tab và thao tác booking riêng; MapsURLs giữ đầy đủ địa chỉ; asset/gallery anonymous/viewer/swipe. Các test cũ vẫn kiểm tra lịch, đổi lịch, hóa đơn, thanh toán, gói, voucher và phiên tài khoản.
- Native release build thành công, version1.1.0+2; dùng `API_BASE_URL=https://healthbeauty.duckdns.org/api/v1`.
- Đã cài bằng `adb install -r` thành công; xem trực tiếp trên máy ảo Android các màn Home, bản đồ/marker, KTV/viewer, Services, Booking và Account. Chỉ điều hướng/đọc dữ liệu; không tạo lịch hoặc giao dịch thanh toán production mới.
- Ảnh kiểm tra và APK: `D:/KhoaLuan/GiaoDienMoi_KetQua/`; xem `index.html`.

## Build lại

```powershell
cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty\HealthBeauty.Mobile
& 'D:\KhoaLuan\.tools\flutter-3.47.7\bin\flutter.bat' pub get
& 'D:\KhoaLuan\.tools\flutter-3.47.7\bin\flutter.bat' build apk --release --dart-define=API_BASE_URL=https://healthbeauty.duckdns.org/api/v1
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`. Cài bản mới để thấy giao diện; app đã cài trước đó không tự đổi theo source. Cấu hình ký hiện có vẫn dùng debug keystore cho bản release trải nghiệm; chưa phải gói ký để phát hành store. Gradle cảnh báo plugin Kotlin cũ nhưng build thành công. Chưa kiểm tra trên điện thoại thật/iOS và chưa chạy giao dịch chuyển khoản thật trong đợt UI này.

## Nguồn kỹ thuật

- Tọa độ lấy từ map nhúng tại [website HUIT](https://huit.edu.vn/) cho địa chỉ140LêTrọngTấn; đây là vị trí cấu hình theo yêu cầu người dùng, không phải xác minh một doanh nghiệp spa đăng ký tại đó.
- [flutter_map](https://docs.fleaflet.dev/), [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/): tileHTTPS, attribution hiển thị, appUserAgent, cache mặc địnhv8.3.2. Không bulk/offline-download.
- [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started), [url_launcher](https://pub.dev/packages/url_launcher): URIhttps mã hóa địa chỉ, `api=1`, mở ứng dụng ngoài và báo lỗi khi không mở được.
