# Khách hàng đổi ảnh đại diện và mật khẩu

## Bản tích hợp trên main

API và Flutter trong repository đã có đầy đủ phần ảnh đại diện/đổi mật khẩu. Không cần script chép API riêng hoặc quyền quản trị để thay source sau khi clone/pull bản này.

Database đang có dữ liệu: chạy **DB_KLCN021/15_CustomerAvatar.sql** bằng SSMS trước khi chạy API mới. Script chỉ thêm cột nullable nếu chưa có, không chạy schema gốc tạo database mới. Cấu hình Cloudinary bằng User Secrets/local config trên máy chạy API.

Dừng/chạy lại Flutter để cập nhật plugin `image_picker`; `CHAY_FLUTTER.ps1` chạy `flutter pub get` trước. Hot reload không cập nhật plugin native. Xem [README](../README.md) để cấu hình SQL/JWT/Firebase và chạy cả dự án.

## Ảnh đại diện

- App → Tài khoản → Chỉnh sửa thông tin hồ sơ → **Đổi ảnh đại diện** → chọn ảnh từ thư viện.
- PNG/JPEG/WebP, tối đa5MB; app giới hạn kích thước ảnh chọn và kiểm tra định dạng/dung lượng. Backend kiểm tra lại nội dung và quyền.
- Upload thành công là lưu ảnh ngay; tên/số điện thoại/giới tính vẫn dùng nút Lưu thay đổi riêng. Ảnh hiển thị trên màn tài khoản và chỉnh sửa; ảnh lỗi có ký tự tên dự phòng.
- Xóa ảnh chỉ bỏ liên kết trong hồ sơ, không xóa tài nguyên Cloudinary có thể dùng chung.
- Khi Android hủy hoạt động chọn ảnh do thiếu bộ nhớ, app thu hồi kết quả gián đoạn và yêu cầu chọn lại; không tự gửi ảnh cũ cho một tài khoản khác.
- API Customer-only: POST `/api/v1/customers/me/avatar`, multipart field **File**, trả CustomerResponse200 có `avatarUrl`; DELETE cùng đường dẫn trả hồ sơ đã bỏ ảnh. GET/PUT hồ sơ thêm `avatarUrl` tùy chọn trong response; client cũ cập nhật tên không làm mất ảnh.
- Chủ sở hữu lấy từ token đăng nhập, không nhận customerId từ client. Không mở quyền upload ảnh danh mục quản trị cho Customer.
- Cần Cloudinary cấu hình local đang có. Upload thành công nhưng lưu database xung đột có thể để lại file chưa được tham chiếu trên Cloudinary; không xóa ảnh cũ theo URL người dùng cung cấp.

## Đổi mật khẩu

- App → Tài khoản → **Đổi mật khẩu** → nhập mật khẩu hiện tại, mật khẩu mới và xác nhận.
- Mật khẩu mới8–128 ký tự, khác mật khẩu cũ. Mật khẩu hiện tại tối đa4096 để hỗ trợ tài khoản cũ có mật khẩu dài; không trim giá trị mật khẩu.
- PUT `/api/v1/auth/change-password` body `{"currentPassword":"...","newPassword":"..."}`; thành công204, sai hiện tại/không hợp lệ400, xung đột409, quá giới hạn429.
- Sau thành công, server đổi SecurityStamp, thu hồi refresh token và làm access token cũ mất hiệu lực. App xóa phiên local và yêu cầu đăng nhập lại. Không lưu mật khẩu trong audit.
- Tài khoản chỉ đăng nhập Google chưa có mật khẩu biết được cần dùng **Quên mật khẩu** để đặt mật khẩu trước. Không cho đổi chỉ bằng email hoặc GoogleID do client gửi.
- Hạn mức: đổi mật khẩu10lần/10phút/IP; avatar20lần/10phút/IP. Tranh chấp đổi mật khẩu chỉ một thao tác thắng.
- Client gắn thao tác với phiên đăng nhập, không refresh/gửi lại avatar hoặc mật khẩu cũ dưới tài khoản mới; token xoay trong cùng phiên vẫn retry được multipart hợp lệ.

## SQL và kiểm chứng

- `15_CustomerAvatar.sql` thêm nullable `KHACHHANG.AvatarUrl nvarchar(2048)` nếu chưa có; chạy lại không trùng dữ liệu, không thay ảnh/điểm hiện có. Không thêm bảng mới. Bản schema gốc trong bundle cũng đã cập nhật cho database mới.
- **523/523 test API** trong worktree cô lập; HTTP xác minh upload/xóa đúng chủ, Customer không upload ảnh quản trị, sai mật khẩu, phiên cũ401, mật khẩu mới đăng nhập200, concurrency và rate limit429.
- Flutter **56 file lib/test phân tích sạch**, **12/12 kiểm tra độc lập** cho DTO/định dạng ảnh/mật khẩu. Đã thêm11 test Flutter cho provider/transport/session race nhưng chưa chạy được Flutter test/emulator vì môi trường chặn tiến trình con CreateFile5.
- Dependency `image_picker`1.2.4 đã resolve và lock; lệnh Dart pub/format kết thúc lỗi ghi telemetry ngoài workspace sau khi hoàn tất công việc. Không coi đó là Flutter build thành công.
- Chưa upload Cloudinary thật hoặc đổi mật khẩu trên dữ liệu thật; test dùng storage giả và DB InMemory. Cần áp dụng SQL/API bằng script trên rồi test thiết bị.
- Plugin chọn ảnh theo [tài liệu chính thức image_picker](https://pub.dev/packages/image_picker).

## Luồng test

1. Áp dụng script, chạy API/Flutter mới, đăng nhập khách A.
2. Chọn ảnh → tài khoản hiển thị ảnh mới; đóng/mở app hoặc đăng nhập lại vẫn có ảnh. Sửa tên không làm mất ảnh.
3. Thử file sai định dạng/quá5MB; không đổi ảnh đang có. Khách B không bị thay ảnh khi A đổi hoặc xóa.
4. Đổi mật khẩu với mật khẩu cũ sai: không đổi và không đăng xuất. Nhập đúng: app đăng xuất, mật khẩu cũ không đăng nhập được, mật khẩu mới đăng nhập được.
5. Phiên A trên thiết bị khác cần đăng nhập lại. Người dùng Google kiểm tra luồng quên mật khẩu trước.
