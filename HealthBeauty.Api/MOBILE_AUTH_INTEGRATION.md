# API tích hợp Flutter: Google, OTP đăng nhập, đánh giá và push

Cập nhật 23/10/2026. Bản tích hợp hiện nằm tại worktree `.local-integration/mobile-api-integration`, nhánh `feature/mobile-api-integration`, dựa trên API `d207c4c`. Chưa commit/push. Thư mục API gốc bị từ chối ghi vào các file sẵn có; bản gốc, ReportingWorkbook.cs đang sửa và web/Flutter được giữ nguyên.

## 1. Đăng nhập Google

`POST /api/v1/auth/google` không yêu cầu Bearer.

```json
{"idToken":"<Google ID token>","email":"<email từ SDK>","googleId":"<Google subject>","fullName":"Tên khách","photoUrl":null}
```

- Bắt buộc idToken; các field còn lại chỉ để tương thích app. Server lấy danh tính từ token đã kiểm tra chữ ký, issuer, audience, hạn dùng và email_verified; không tin email/googleId/fullName riêng trong request.
- Audience allowlist `Authentication:Google:ClientIds` đã được lấy từ OAuth web/server client ID trong bộ Firebase_Config_Cho_Nhom anh cung cấp. Đây là ID công khai; không sao chép khóa riêng/service account.
- Chỉ phục vụ khách hàng. Không mở khóa tài khoản đang khóa hoặc đổi vai trò Admin/Manager/Reception/Staff thành Customer.
- Khách mới: tạo tài khoản Customer + hồ sơ khách + EXTERNALLOGIN Google, mật khẩu ngẫu nhiên được hash; không lấy Google ID làm mật khẩu.
- Khách có liên kết: tìm bằng Google subject ổn định. Khách có email cũ chưa liên kết: chỉ tự liên kết khi email do Google quản lý (Gmail hoặc Workspace có hostedDomain). Email bên thứ ba trùng tài khoản cũ nhận 409 và cần đăng nhập mật khẩu; không tự chiếm tài khoản chỉ bằng email_verified.
- Trả AuthResponse giống login: accessToken, refreshToken, accessTokenExpiresAt, account. Token thiếu/sai:400/401; tài khoản vai trò không phù hợp:403; trùng/race liên kết:409; thiếu cấu hình/lỗi kết nối Google:503.
- Không cần service account Firebase để xác minh Google ID token. Cấu hình Firebase phía Flutter và SHA/OAuth Console vẫn do thành viên app hoàn thiện.

Tài liệu xác minh: https://developers.google.com/identity/sign-in/web/backend-auth . SDK GoogleJsonWebSignature dùng thư viện Google.Apis.Auth đã có trong dependency FirebaseAdmin.

## 2. OTP cho đăng nhập bằng mật khẩu của khách hàng

Mặc định **tắt** để tương thích database/client hiện tại. Web quản trị/nhân viên giữ AuthResponse cũ. Google login là phương thức độc lập dựa trên Google ID token, không đi qua OTP email của mật khẩu.

Sau khi chạy SQL14 và có SMTP hợp lệ, bật cấu hình:

```powershell
$env:Authentication__TwoFactor__Enabled="true"
```

- `POST /auth/login` body email/password giữ nguyên. Mật khẩu đúng và Customer cần OTP: trả HTTP200 `{"requiresTwoFactor":true,"email":"...","message":"..."}`; chưa trả JWT/refresh token. App hiện tại đã nhận đúng dạng này.
- `POST /auth/verify-2fa`: `{"email":"...","otp":"123456"}`. Thành công trả AuthResponse; mã sai/hết hạn/đã dùng:400.
- `POST /auth/resend-2fa`: `{"email":"..."}`. Luôn trả thông báo chung200; chỉ thực sự gửi lại cho challenge còn hiệu lực sau bước mật khẩu đúng. Không tạo challenge mới chỉ từ email.
- Mã 6 số, hạn 5 phút từ bước xác minh mật khẩu ban đầu; resend không kéo dài hạn. Tối đa 5 lần đoán trong cửa sổ này, giữ nguyên số lần sai qua resend; đợi 60 giây giữa lần gửi và tối đa5lần/giờ/tài khoản.
- Lưu HMAC hash theo mục đích đăng nhập, tách hẳn OTP quên mật khẩu. Khóa `Authentication:TwoFactor:OtpHashKey` tùy chọn, mặc định dùng Jwt:Key; phải ít nhất32ký tự.
- Bounded email queue, worker SMTP riêng dùng chung SmtpOptions; mã đã thay/hết hạn/phiên đổi security stamp không được gửi hoặc dùng lại. SMTP chưa cấu hình hoặc queue lỗi: không bỏ qua OTP để cấp JWT.
- Không bật OTP trước khi database có bảng mới. Nếu tắt, login không truy vấn bảng OTP mới và giữ hợp đồng cũ.

## 3. Database

- Google sử dụng TAIKHOAN/KHACHHANG/EXTERNALLOGIN đã có; không cần bảng Google mới.
- `DB_KLCN021/14_LoginTwoFactor.sql` thêm bảng LOGINTWOFACTORCHALLENGE (một dòng/tài khoản), FK, ràng buộc và token concurrency. Script có IF NOT EXISTS, chạy lại không chèn trùng; không xóa dữ liệu cũ.
- Database tạo mới có schema tương ứng trong KLCN021_HealthBeauty.sql. Database đang dùng chỉ chạy SQL14, không chạy lại script tạo toàn bộ database.
- Chưa áp dụng SQL14 lên database thật: công cụ trực tiếp bị SqlException Number20 ở bước kết nối. Chưa xác minh chạy lại script hay tranh chấp đồng thời trên SQL Server thật. Chạy SQL14 bằng SSMS/phiên PowerShell có kết nối phù hợp trước khi bật OTP.

## 4. Chi tiết đánh giá trong lịch hẹn

AppointmentResponse bổ sung `reviewComment`, `reviewedAt`, `reviewReply`, `reviewRepliedAt`, giữ nguyên invoiceId/invoiceStatus/hasReviewed/reviewStars/customerPackageId/fundingSource.

- Đọc từ đánh giá của hóa đơn trong lịch, nên bình luận/phản hồi còn sau khi reload app.
- Giữ nguyên phạm vi chủ lịch/nhân viên được phân công/quyền quản lý. Không sửa API đánh giá công khai.
- Đánh giá xóa mềm vẫn hasReviewed=true để chặn gửi trùng; không trả nội dung/sao/ngày/phản hồi đã xóa.
- Flutter vẫn cần khóa nút đánh giá khi hóa đơn chưa thanh toán; API hiện có đã kiểm tra điều kiện này.

## 5. Logout và thiết bị push

`POST /auth/logout` vẫn nhận refreshToken và Bearer như trước; bổ sung optional deviceToken.

- refreshToken phải thuộc tài khoản đang xác thực và chưa thu hồi mới được tắt thiết bị.
- Có deviceToken: chỉ tắt token thuộc tài khoản đó. Không có (app hiện tại): tắt toàn bộ đăng ký push của tài khoản; thiết bị khác phải đăng ký/sync lại khi đăng nhập. Đây là chính sách tương thích vì app cũ xóa local session trước DELETE device-token.
- Câu UPDATE SQL giữ owner predicate tại thời điểm cập nhật, tránh logout tài khoản A tắt nhầm token vừa chuyển sang B. Thu hồi refresh và tắt thiết bị trong cùng transaction.
- Không dùng yêu cầu thiếu Bearer làm bằng chứng logout. Không vô hiệu hóa thiết bị tài khoản khác.
- Push thực vẫn cần cấu hình Firebase server/service account; bộ cấu hình ứng dụng khách không thay thế credential server.

## 6. Chạy bản tích hợp trên máy

```powershell
cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty\.local-integration\mobile-api-integration\HealthBeauty.Api
dotnet run --launch-profile http
```

Cổng mặc định5230, cần dừng API cũ cùng cổng trước khi chạy. Cấu hình máy-local đã được sao chép vào file local bị gitignore, không đưa mật khẩu/khóa vào tài liệu. OTP vẫn tắt cho đến khi anh chạy SQL14 và bật biến môi trường như trên. Các tiến trình API đang chạy trước đó không tự nhận code mới.

## 7. Kiểm chứng

- 487/487 test toàn bộ đạt sau lượt sửa owner-predicate cuối (0fail/0skip); build0warning/0error. Gồm Google verifier, controller, OTP service, đánh giá và HTTP.
- Build API đạt0warning/0error.
- 11/11 probe trên API thật chạy tạm cổng5263 đạt: Swagger có3route/4field mới, request Google thiếu/sai token bị400/401, OTP/email sai định dạng bị400. Tắt reminders/push trong probe; không đăng nhập thật/thu tiền/mua gói/gửi email.
- HTTP test thành công dùng database in-memory và Google verifier giả kiểm soát được. Chưa có Google ID token thật để kiểm thử OAuth hoàn chỉnh; chưa gửi OTP email thật hoặc nhận push trên điện thoại.
- Không sửa Flutter/Web. Các phần app chưa có gói dịch vụ/đổi điểm, ảnh API, voucher ước tính, phân trang/rollback thông báo và hạng thành viên vẫn cần thành viên Flutter làm tiếp.
