# Khắc phục tải ảnh trên AWS

## Nguyên nhân đã xác nhận

App báo: “Dịch vụ tải ảnh chưa được cấu hình. Vui lòng liên hệ Spa.” Đây là thông báo ánh xạ từ HTTP 503 của API, không phải lỗi quyền chọn ảnh.

API dùng chung Cloudinary cho ảnh đại diện khách hàng (`POST /api/v1/customers/me/avatar`) và ảnh danh mục trên web (`POST /api/v1/media/images`). `CloudinaryOptions.IsConfigured` cần Enabled, CloudName, ApiKey, ApiSecret và Folder hợp lệ.

Cấu hình chỉ có trong `HealthBeauty.Api/appsettings.Development.local.json`, là file riêng được Git ignore và chỉ đọc khi chạy Development. Container production không có biến môi trường Cloudinary hoặc section Cloudinary trong appsettings. Vì vậy cả hai endpoint đều từ chối upload. Không đưa file cấu hình local chứa các mục khác lên production để sửa lỗi này.

Kiểm tra read-only từ EC2 tới Cloudinary bằng bộ thông tin hiện có trả HTTP 200, status ok. Không in API Key/Secret.

## Đã áp dụng trên EC2 sau khi chủ dự án đồng ý

- Release: `/home/ubuntu/demo-api/releases/20261027-cloudinary`.
- Thêm đúng năm biến: `Cloudinary__Enabled`, `Cloudinary__CloudName`, `Cloudinary__ApiKey`, `Cloudinary__ApiSecret`, `Cloudinary__Folder`.
- Secret ở file `private/.env.cloudinary`, quyền 600; thư mục private quyền 700. Không commit các file này.
- Compose bổ sung: `/home/ubuntu/demo-api/compose.release.20261027-cloudinary.yaml`, nối sau toàn bộ chuỗi Compose đang chạy (chọn chuỗi dài nhất từ nhãn API/web).
- Chỉ recreate API, không build/pull image: `up -d --no-deps --no-build --pull never --force-recreate <API service>`.
- Container API mới: `6d913086550e`; image giữ nguyên `healthbeauty-api:lifecycle-20261026173717`, đối chiếu cả image ID.
- Web `b789bf78f32f`, SQL Server `76010c7d5135`, Caddy `41d1609bf828` giữ nguyên container.
- Đã đối chiếu toàn bộ biến môi trường ngoài Cloudinary, mount, HostConfig, command, user, working directory và các file Compose cũ/Dockerfile/nginx. Không ghi đè JWT, connection string, SePay hoặc các file cấu hình cũ. Không chạy SQL/migration/restore, không xóa volume.
- Các lần triển khai tiếp theo cần giữ override Cloudinary mới trong chuỗi Compose. Helper release hiện có hỗ trợ chọn chuỗi dài nhất khi hai chuỗi có quan hệ tiền tố.

## Sửa bổ sung trong Flutter DEV

- `HealthBeauty.Mobile/lib/providers/profile_provider.dart`: riêng request POST ảnh đại diện dùng sendTimeout 60 giây, receiveTimeout 45 giây, đủ chờ API có deadline Cloudinary 30 giây. Các request thông thường và DELETE ảnh giữ timeout cũ.
- `HealthBeauty.Mobile/test/customer_self_service_test.dart`: thêm test ngân sách timeout và ba trường hợp 503/502/504; giữ ảnh hiện tại và bỏ trạng thái bận khi lỗi.
- Không sửa code web/API trong tác vụ này; nguyên nhân chung được xử lý bằng cấu hình runtime.

## Kiểm chứng

- Cloudinary ping từ EC2: HTTP 200, status ok.
- Compose dry run: chỉ thêm năm biến Cloudinary; image, cấu hình khác và container không thay đổi trước khi áp dụng.
- Sau áp dụng: HTTPS web 200, `/api/v1/services` 200 (đọc SQL qua API), `/api/v1/customers/me` 401 khi thiếu đăng nhập; API restart count 0, bốn container running.
- SePay webhook: payload đủ trường nhưng ngày không hợp lệ trả 401 khi thiếu key, 400 khi dùng key hiện tại; dừng trước truy cập ledger, không tạo giao dịch hay thanh toán.
- Flutter: **185/185 test đạt**, analyzer **No issues found**. Test timeout mới thất bại trước sửa và đạt sau sửa.
- API Cloudinary: **24/24 test đạt**, không dùng provider thật trong unit/HTTP test.
- APK release: build thành công 73.5 giây; 60.888.995 bytes. SHA256 `41FA52E221D50B0E32B4D2E1AA2B7E9555CE4BF6FEE56DC3B25732D0AB4CE238`.
- APK: `HealthBeauty.Mobile/build/app/outputs/flutter-apk/app-release.apk`. Bản app đang cài có thể thử lại ngay sau sửa server; APK mới bổ sung thời gian chờ khi mạng/storage chậm.
- Chưa upload ảnh người dùng thật hoặc thay ảnh hồ sơ khách trên production. Chủ dự án cần thử ảnh PNG/JPG/WebP dưới 5 MB trên app/web để xác nhận thao tác cuối cùng.

Web hiện có nút upload máy tính ở dịch vụ/combo/gói. Ảnh nhân viên hiện là trường URL lưu ở trình duyệt, chưa có chức năng upload/persist ảnh nhân viên qua backend; đây là phạm vi riêng nếu cần bổ sung.

## Rollback đã chuẩn bị

Snapshot private ghi image/container/environment trước thay đổi và cấu hình rollback chỉ API. Nếu cần:

```bash
python3 /home/ubuntu/demo-api/releases/20261027-cloudinary/private/apply.py rollback
```

Script dùng chuỗi Compose trước thay đổi với image ID cũ, recreate riêng API, rồi đối chiếu môi trường và các container khác. Chưa cần chạy rollback.

Log và script hỗ trợ nằm ở `.local-integration/`, được Git ignore. Không có push GitHub trong tác vụ này.
