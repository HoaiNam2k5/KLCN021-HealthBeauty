# Khách hàng đổi ảnh đại diện và mật khẩu

## Trạng thái áp dụng trên máy anh

Flutter đã sửa trực tiếp tại `HealthBeauty.Mobile`. Backend hoàn chỉnh đã kiểm thử **523/523 test**, nhưng **chưa áp dụng vào API gốc**: Windows từ chối ghi 4 file hiện có. Không chép dở các file còn lại để tránh API lỗi biên dịch. SQL15 có trong thư mục DB nhưng **chưa chạy**; thử kiểm tra SQL bị lỗi kết nối/encryption của môi trường agent trước khi thực thi.

Backend đóng gói tại `D:/KhoaLuan/_Updates/customer-self-service-20261024`, gồm đúng 15 file source/SQL/test và manifest SHA256, không chứa cấu hình bí mật. Bản làm việc kiểm thử: `D:/KhoaLuan/_Work/customer-self-service-api`, nhánh `agent/customer-self-service-20261024`. Chưa commit/push.

## Anh áp dụng bằng một lệnh

Dừng API/Flutter đang chạy. Mở **PowerShell bằng Run as administrator** rồi chạy:

```powershell
& "D:\KhoaLuan\AP_DUNG_HO_SO_KHACH_HANG.ps1" -ApplySql
```

Script kiểm tra toàn bộ hash/phiên bản file trước, kiểm tra quyền ghi, chạy **riêng SQL15** vào database cấu hình local, sao lưu và chép 15 file, xác minh hash và chạy lại test tại dự án gốc. Giữ nguyên Web/Flutter/local credentials. Nếu phát hiện code có sửa thêm hoặc file còn bị khóa thì dừng trước khi thay API. Không chạy schema gốc tạo database mới.

Nếu SQLCMD không kết nối được, chạy `DB_KLCN021/15_CustomerAvatar.sql` bằng SSMS trên đúng database, sau đó:

```powershell
& "D:\KhoaLuan\AP_DUNG_HO_SO_KHACH_HANG.ps1" -SqlAlreadyApplied
```

`-SqlAlreadyApplied` là xác nhận của người chạy rằng đã thực thi SQL15 thành công. Có thể xem preflight chỉ đọc bằng `-CheckOnly`.

Chạy lại API và Flutter từ dự án chung. `CHAY_FLUTTER.ps1` giờ chạy `flutter pub get` trước để đăng ký plugin chọn ảnh mới; cần dừng/chạy lại app, hot reload không cập nhật plugin native.

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
