# API quên mật khẩu HealthBeauty

Triển khai backend, không sửa Web/Flutter. Hai endpoint công khai; frontend không cần access token. JSON dùng camelCase.

## Hợp đồng tích hợp

### POST /api/v1/auth/forgot-password

```json
{ "email": "user@example.com" }
```

HTTP 200 luôn dùng cùng một thông báo cho email tồn tại, không tồn tại, tài khoản ngừng hoạt động hoặc yêu cầu gửi lại quá sớm:

```json
{ "message": "Nếu email thuộc tài khoản đang hoạt động, mã xác nhận sẽ được gửi đến email đó. Vui lòng kiểm tra hộp thư và thư rác." }
```

Không trả `debugOtp`, token hay trạng thái tồn tại tài khoản. HTTP 200 là tiếp nhận yêu cầu; không phải xác nhận SMTP đã giao thư. Email gửi bất đồng bộ nên lỗi gửi được ghi nhật ký vận hành, không tiết lộ tài khoản qua response. Email sai định dạng nhận 400; quá giới hạn IP nhận 429.

### POST /api/v1/auth/reset-password

```json
{ "email": "user@example.com", "otp": "012345", "newPassword": "new-password-example" }
```

OTP là chuỗi đúng 6 chữ số, giữ số 0 đầu. Mật khẩu mới 8–128 ký tự, không chỉ chứa khoảng trắng; không tự trim mật khẩu.

- 200: `{ "message": "Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới." }`.
- 400: dữ liệu không hợp lệ, OTP sai/hết hạn/đã dùng/hết lượt thử hoặc tài khoản không đủ điều kiện. Không cho biết email có tồn tại.
- 429: thử quá nhiều lần từ cùng IP; header `Retry-After: 600`.

Sau 200, frontend xóa phiên cũ và đưa về đăng nhập. API không tự đăng nhập, không cấp token mới trong response reset.

## Chính sách và lưu trữ

- Mã sinh bằng bộ tạo số ngẫu nhiên mật mã, hạn 15 phút, tối đa 5 lượt kiểm tra; chỉ dùng một lần.
- Gửi lại sau ít nhất 60 giây, tối đa 5 lần/tài khoản trong cửa sổ 1 giờ. Mã mới thay thế mã cũ.
- IP: tối đa 10 yêu cầu forgot và 20 yêu cầu reset mỗi cửa sổ 10 phút, hai bộ đếm độc lập. Chỉ dùng IP kết nối; reverse proxy cần cấu hình forwarded headers từ proxy tin cậy khi triển khai.
- Database lưu HMAC-SHA256 của OTP, ràng buộc mã tài khoản và thế hệ challenge; không lưu OTP thô. Khóa HMAC mặc định lấy `Jwt:Key` với chuỗi phân biệt mục đích, có thể tách riêng `PasswordRecovery:OtpHashKey` tối thiểu 32 ký tự. Khóa cấu hình không hợp lệ làm API dừng ngay lúc khởi động.
- Bảng `PASSWORDRESETCHALLENGE` giữ một dòng/tài khoản; Version dùng kiểm soát đồng thời. Lượt kiểm tra được ghi nhận trước khi so sánh hash để tránh đoán đồng thời vượt giới hạn.
- Đổi mật khẩu, đánh dấu OTP đã dùng, đổi SecurityStamp, thu hồi refresh token và ghi audit trong cùng transaction SQL. JWT cũ bị từ chối ngay; refresh token mang stamp cũ cũng bị từ chối, kể cả bị phát hành muộn do refresh/reset đồng thời.
- Khôi phục xóa bộ đếm đăng nhập sai và khóa tạm thời; không mở lại tài khoản đã bị ngừng hoạt động.
- Hàng đợi email giới hạn 100 thư trong RAM; SMTP bắt buộc TLS, timeout 15 giây. Chỉ SMTP nhận OTP thô; API/log không chứa OTP. Worker bỏ qua mã cũ/hết hạn/đã dùng hoặc tài khoản thay đổi. Gửi lỗi chỉ vô hiệu hóa đúng thế hệ mã tương ứng.
- Challenge đã lưu sống qua lần khởi động lại; thư còn chờ trong RAM có thể mất khi process dừng. Người dùng gửi lại sau cooldown. Khi chạy nhiều API instance, challenge/quota tài khoản dùng chung SQL, còn rate limit IP và hàng đợi là theo từng instance; dùng gateway/distributed limiter và outbox bền vững nếu cần mở rộng.

## Database

Chạy `DB_KLCN021/04_PasswordRecovery.sql` trước khi chạy API mới trên database có sẵn. Script chạy lặp an toàn, thêm bảng challenge và cột `SecurityStamp` nullable vào `TAIKHOAN`/`REFRESHTOKEN`, không thay đổi mật khẩu hoặc dữ liệu nghiệp vụ cũ. Schema gốc đã cập nhật cho database mới. Riêng cập nhật khôi phục mật khẩu đưa database lên 25 bảng nghiệp vụ; sau khi áp dụng thêm `06_Notifications.sql`, tổng là 28 bảng.

## Cấu hình SMTP

Mặc định SMTP tắt, API vẫn chạy nhưng không tạo/gửi mã. Khi thiếu cấu hình, có cảnh báo vận hành. Không đưa mật khẩu SMTP vào source hoặc Git. Mẫu không chứa bí mật: `Configuration/password-recovery.example.json` (chỉ để tham khảo, không tự nạp).

Trong thư mục `HealthBeauty.Api`, cấu hình bằng User Secrets hoặc biến môi trường:

```powershell
dotnet user-secrets set "Smtp:Enabled" "true"
dotnet user-secrets set "Smtp:Host" "smtp.gmail.com"
dotnet user-secrets set "Smtp:Port" "587"
dotnet user-secrets set "Smtp:EnableSsl" "true"
dotnet user-secrets set "Smtp:UserName" "<email-gui>"
dotnet user-secrets set "Smtp:Password" "<mat-khau-ung-dung>"
dotnet user-secrets set "Smtp:SenderEmail" "<email-gui>"
dotnet user-secrets set "Smtp:SenderName" "HealthBeauty"
```

Sau khi cấu hình SMTP, khởi động lại API để hàng đợi và worker nhận cấu hình mới. Có thể dùng `appsettings.Development.local.json` đã được Git bỏ qua. Không chép lại thông tin SMTP thật từ file mẫu của nhóm vào tài liệu công khai. Gmail cần App Password phù hợp, không dùng mật khẩu đăng nhập thông thường.

## Kiểm chứng

Kiểm thử tự động dùng email sender giả và database InMemory/SQL riêng, không gửi email thật. Chạy `dotnet test HealthBeauty.Api.Tests/HealthBeauty.Api.Tests.csproj` từ thư mục repo. Việc giao thư thật cần kiểm tra riêng sau khi cấu hình SMTP hợp lệ.

Thiết kế tham khảo [OWASP Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).
