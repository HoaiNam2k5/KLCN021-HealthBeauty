# Logo Web và App

Ảnh gốc: `D:/KhoaLuan/logo.png`, giữ nguyên thiết kế và chữ trong ảnh; chỉ tạo các kích thước cần dùng, không đổi tên sản phẩm hay vẽ lại logo.

## Đã cập nhật tại DEV

- Web: sidebar desktop/mobile, đăng nhập, đầu phiếu in; favicon PNG32/ICO nhiều kích thước, SVG cũ cũng trỏ ảnh mới; Apple touch180; manifest và ảnh192/512; thông tin ảnh chia sẻ trang.
- Flutter: widget AppLogo hiển thị toàn ảnh, màn đăng nhập/đăng ký, đầu trang chủ và dấu thương hiệu trên thẻ thành viên. Giữ nguyên avatar và icon chức năng.
- Android: launcher48/72/96/144/192, adaptive icon có khoảng an toàn và roundIcon; màn mở App cũ và Android12+ sáng/tối.
- Flutter Web: favicon, icon thường/maskable192/512, tên/manifest theo HealthBeauty.
- Windows: thay resource `app_icon.ico` nhiều kích thước; chưa build Windows.
- Ảnh cho cửa hàng: `HealthBeauty.Mobile/branding/play-store-icon.png`512 và `app-store-icon.png`1024. Đây là ảnh chuẩn bị, chưa đăng lên Google Play/App Store. Repo hiện không có native target iOS/macOS để cập nhật/build launcher tương ứng.

## Kiểm tra

- 19 file PNG kiểm tra kích thước,2 ICO kiểm tra cấu trúc nhiều kích thước, JSON manifest/XML Android parse đạt.
- Flutter tại DEV:39 kiểm thử liên quan đạt; analyzer không lỗi. Bản branding port vào worktree phát hành thêm35 kiểm thử auth/widget đạt.
- APK debug build thành công36,4giây; kiểm tra APK chứa đúng logo asset và cả launcher thường/adaptive; `adb install -r` lên emulator-5554 thành công, không gỡ ứng dụng/xóa dữ liệu. Đã quan sát logo màn khởi động trong emulator; chưa kiểm tra launcher trên điện thoại thật.
- Web76/76, lint sạch, production build3847modules đạt; vẫn có cảnh báo bundle lớn từ trước.
- Công cụ deploy bổ sung Web-only, giữ API/SQL/Caddy và đọc chuỗi Compose dài nhất khi hai container có nhãn khác nhau sau deploy riêng lẻ;12/12 guard tests đạt (fixture trong workspace do systemtemp bị hạn chế quyền).

APK mới: `HealthBeauty.Mobile/build/app/outputs/flutter-apk/app-debug.apk`,189912696bytes. Điện thoại cần cài APK mới hoặc chạy lại Flutter để thay icon; cập nhật server không tự cập nhật App đã cài.

## Website đã triển khai

Commit`baba941`45files đã push lên main và EC2 pull fast-forward. Release`20261027-branding` chỉ build/recreate Web; giữ nguyên API`59765e30b818`, SQL`76010c7d5135`, Caddy`41d1609bf828`. Web mới`2a71158d8115`, image`healthbeauty-web:lifecycle-20261026183136`,running0restarts.

Đã kiểm tra HTTPS và SHA256 của8logo/favicon/manifest public khớp file phát hành; HTML hiện tham chiếu favicon mới. API SQL-read probes đạt; môi trường/appsettings/nginx/3Docker-nginx riêng/all6Compose cũ không đổi. Không cập nhật SQL/SePay/JWT/domain/HTTPS, không ghi giao dịch tài chính.

Chuỗi Compose mới có7file:6file trước đó cộng`compose.release.20261027-branding.yaml`. Các lần deploy sau phải dùng đủ chuỗi; helper tự chọn chuỗi dài hơn từ API/Web khi chuỗi kia là tiền tố.

Rollback Web đã chuẩn bị, chưa cần chạy:

```bash
HEALTHBEAUTY_RELEASE_ID=20261027-branding python3 /home/ubuntu/demo-api/source/deploy/aws/release.py rollback
```

Sau rollback dùng override rollback tương ứng. Bản sao lưu cấu hình/state riêng nằm ngoàiGit tại `/home/ubuntu/demo-api/releases/20261027-branding`.

Mở lại tab hoặc Ctrl+F5 nếu trình duyệt còn cache icon. Logo trong kết quả tìm kiếm hoặc cửa hàng ứng dụng phụ thuộc cache/cấu hình của các nền tảng đó, không được coi là đã phát hành trong đợt này.
