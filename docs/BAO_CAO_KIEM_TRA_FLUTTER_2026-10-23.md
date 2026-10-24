# Kiểm tra Flutter cập nhật ngày 23/10/2026

## Bản được kiểm tra

- Đã clone riêng nhánh `feature/mobile-app` tại `.local-integration/mobile-app-review-20261023`.
- Commit: `b1bbb99cbf540a4a8e99f8cb6f39275a46e01735` (22/10/2026), nội dung reviews/notifications/profile/auth enhancements.
- So với commit mobile trước `dcc3284`: 51 file thay đổi, 9.744 dòng thêm, 1.081 dòng xóa.
- API dùng đối chiếu: worktree chính `D:/KhoaLuan/DEV/KLCN021_HealthBeauty/HealthBeauty.Api`, commit `d207c4c`, đã có gói dịch vụ/đổi điểm/thông báo. **API đi kèm nhánh mobile còn cũ; không dùng để thay API chung hiện tại.**
- Chỉ kiểm tra; không sửa source, commit/push, không tạo lịch/mua gói/thu tiền/gửi email trên dữ liệu thật. Các thay đổi web Việt hóa/STT được giữ nguyên.

## Chức năng đã có trong mã

| Nhóm | Kết quả đối chiếu |
|---|---|
| Đăng nhập/đăng ký, refresh/logout | Có luồng dùng API chung; có xử lý phản hồi trễ khi đổi phiên. Còn lỗi hủy thiết bị push khi logout. |
| Quên mật khẩu OTP | Có màn hình gửi mã, nhập mã và đổi mật khẩu; paths/body khớp forgot-password/reset-password. |
| Hồ sơ, điểm thưởng | GET/PUT /customers/me và GET /customers/me/points khớp API. |
| Danh mục/đặt lịch | Có dịch vụ/combo, tìm kiếm/lọc, đủ thành phần combo, thời lượng, availability đúng DTO và giờ địa phương. |
| Lịch hẹn | Có phân trang, hủy và form đánh giá theo lịch hẹn; cần sửa điều kiện mở đánh giá và dữ liệu chi tiết đánh giá. |
| Đánh giá dịch vụ | Có danh sách công khai, tổng hợp và phản hồi; tên trường khớp API reviews. |
| Thông báo | Có hộp thư, số chưa đọc, đánh dấu đã đọc, đăng ký thiết bị và tích hợp Firebase/local notifications. Chưa chốt chạy push thực. |
| Voucher | Có xem phiếu của tôi, kiểm tra mã và chọn đề nghị dùng khi đặt lịch. Chưa có đổi điểm lấy voucher. |
| Gói dịch vụ nhiều buổi | **Chưa tích hợp** danh mục, mua gói, gói của tôi, lượt còn lại/lịch sử và đặt lịch bằng gói. |

## Lỗi cần sửa, theo mức ưu tiên

### 1. Ưu tiên cao — Logout không hủy được thiết bị nhận push

- Mobile: `lib/providers/auth_provider.dart:276–284` xóa TokenStorage rồi mới notify; `lib/providers/notification_provider.dart:74–76,242–248` gọi DELETE /notifications/device-token sau đó.
- `lib/core/api_client.dart:32–36` gắn Bearer từ TokenStorage đã xóa, nên DELETE thiếu xác thực. Lỗi bị nuốt.
- API: `Controllers/NotificationsController.cs:12,39–43` yêu cầu đăng nhập; AuthController logout chỉ thu hồi refresh token, không tắt thiết bị. Worker vẫn chọn thiết bị active.
- Hệ quả: sau logout, thiết bị có thể tiếp tục nhận thông báo tài khoản cũ cho đến khi bị hủy hoặc được gán lại.
- Đề nghị: hủy thiết bị với thông tin xác thực hợp lệ trước khi clear session, hoặc cleanup bằng cặp thông tin phiên đã giữ lại, có xử lý access hết hạn. Test logout thành công/thất bại và chuyển tài khoản.

### 2. Google/2FA chưa khớp API

- `lib/providers/auth_provider.dart:139,159,195` gọi /auth/verify-2fa, /auth/resend-2fa và /auth/google.
- API hiện tại không có ba route này; login cũng không trả requiresTwoFactor.
- Nút Google có trên giao diện: ngay cả khi Google SDK thành công, bước trao đổi với API vẫn không thể hoàn tất. 2FA hiện là nhánh xử lý phía app chưa được backend kích hoạt.
- Các test auth mock các route đó nên không chứng minh API thật hỗ trợ.
- Đề nghị: thống nhất phạm vi với backend; tạm ẩn chức năng chưa có hợp đồng hoặc bổ sung API với xác thực Google ID token đúng quy trình.

### 3. Chưa có gói dịch vụ và đổi điểm lấy voucher

- `lib/providers/catalog_provider.dart:71–74` chỉ tải categories/services/combos/promotions; `services_screen.dart` chỉ có tab Dịch vụ/Combo.
- Toàn bộ lib không có /service-packages hoặc customerPackageId. `AppointmentProvider.create:186–208` không gửi mã gói; model lịch cũng không giữ fundingSource/customerPackageId.
- Khách đã mua gói qua web vẫn không thể chọn dùng lượt trên app.
- Chưa có /customers/me/voucher-offers hay POST /customers/me/vouchers/{id}/redeem.
- Đề nghị: đọc HUONG_DAN_GOI_DICH_VU.md ở API hiện tại; bổ sung danh mục mua, gói của tôi, lượt khả dụng và chọn gói khi đặt lịch. Thanh toán gói hiện do nhân viên xác nhận; không tự coi tạo phiếu mua là đã thanh toán.

### 4. Sai số tiền giảm voucher trên màn đặt lịch

- `lib/screens/booking_screen.dart:100–106,1577–1581,1920–1923`: lấy giá trị voucher làm tiền giảm thực tế.
- API `Controllers/InvoicesController.cs:63–66` tính cả loại/mức chương trình rồi giới hạn theo giaTriGiam và tổng hóa đơn.
- Ví dụ tổng 100.000đ, chương trình giảm 10%, voucher trần 50.000đ: app dự kiến giảm 50.000đ nhưng API chỉ giảm 10.000đ.
- Voucher và phương thức thanh toán hiện chỉ được ghi vào note (`booking_screen.dart:247–268`); không tự trừ voucher, thu tiền hoặc áp dụng giảm vào hóa đơn. Cần ghi rõ là yêu cầu cho lễ tân, hoặc có API báo giá thống nhất.

### 5. Bỏ qua ảnh Cloudinary do web quản trị cập nhật

- `lib/models/catalog.dart:23–57,77–109` không đọc imageUrl; `lib/widgets/service_tile.dart:8–35` dùng ảnh mẫu Unsplash theo tên.
- API ServiceResponse/ComboResponse hiện có imageUrl. Vì vậy đổi ảnh trên web không thay ảnh Flutter.
- Đề nghị: giữ imageUrl trong model, ưu tiên ảnh API, chỉ dùng ảnh mẫu khi thiếu/lỗi ảnh.

### 6. Đánh giá trên lịch hẹn thiếu dữ liệu và mở form quá sớm

- `lib/models/appointment.dart:78–85` đọc reviewComment/reviewedAt/reviewReply/reviewRepliedAt, nhưng AppointmentResponse hiện chỉ có hasReviewed/reviewStars.
- `lib/screens/appointments_screen.dart:368–436` dùng các field thiếu: gửi đánh giá thấy tạm trong bộ nhớ, tải lại mất bình luận/ngày; phản hồi quản trị không hiện ở chi tiết lịch hẹn này.
- `appointments_screen.dart:298–318` mở form khi lịch hoàn thành và chưa đánh giá, chưa kiểm tra invoiceId/invoiceStatus. API ReviewsController yêu cầu hóa đơn đã thanh toán, nên lịch hoàn thành nhưng chưa thu tiền vẫn mở form rồi bị từ chối.
- Đề nghị: bổ sung dữ liệu đánh giá từ API phù hợp; kiểm tra điều kiện hóa đơn và giải thích cho khách chờ thanh toán.

### 7. Tải thêm thông báo có thể bỏ mất một trang

- `lib/providers/notification_provider.dart:175–178` tăng currentPage trước khi HTTP thành công.
- Đang trang 1, tải trang 2 lỗi mạng; lần sau gọi trang 3, bỏ qua tối đa 20 thông báo.
- Đề nghị: giữ nguyên trang đã tải thành công, chỉ tăng sau thành công hoặc dùng targetPage riêng.

### 8. Đánh dấu đã đọc lỗi vẫn đổi giao diện

- `notification_provider.dart:182–215` cập nhật item/unreadCount trước PATCH; lỗi không rollback.
- Khi mất mạng, app hiện đã đọc/badge 0 nhưng server chưa ghi nhận.
- Đề nghị: rollback khi lỗi hoặc chỉ chốt trạng thái sau thành công; thêm test lỗi mạng và đổi tài khoản khi request đang chạy.

### 9. Hạng thành viên không đồng bộ và quyền lợi chưa được API áp dụng

- `lib/models/membership_tier.dart:49,65,81`: Bạc 100, Vàng 500, Kim Cương 1.000 điểm.
- Web hiện dùng Bạc 300, Vàng 1.000, Kim Cương 2.000. Ví dụ 1.000 điểm hiển thị Kim Cương trên app nhưng Vàng trên web.
- App còn hiển thị giảm tự động 5%/10%/15%, ưu đãi sinh nhật, nhân điểm... trong benefits; API hóa đơn hiện không có quy tắc tự giảm theo hạng này.
- Đề nghị: thống nhất quy tắc và cấu hình chung, bỏ mô tả quyền lợi chưa triển khai. Điểm hiện là số dư có thể tiêu nên cũng cần thống nhất cách tính hạng thay vì tự suy diễn chính sách.

## Kết quả chạy kiểm tra và giới hạn

- Clone thành công; commit đầy đủ như trên. Source checkout không bị sửa.
- Máy: Flutter 3.38.7 / Dart 3.10.7. pubspec.yaml yêu cầu Dart ^3.13.4; pubspec.lock yêu cầu Flutter >=3.44.0.
- Đã thử dependency resolution; lỗi thực tế: `The current Dart SDK version is 3.10.7. Because app_doancunhan requires SDK version ^3.13.4, version solving failed.` Có thêm lỗi quyền ghi telemetry của môi trường.
- **Chưa chạy được flutter analyze, flutter test hoặc build Android/Web**, do chưa giải được dependency với SDK hiện có. Không hạ pubspec hoặc đổi dependency để làm sai bản teammate vừa push.
- Đã chạy **6 kiểm tra model Dart cô lập**, dùng trực tiếp file model/booking helper thật và DTO tương ứng API hiện tại, không cần Flutter dependency: 6/6 đạt. Xác nhận parse thông báo và giờ local đúng; xác nhận bình luận/phản hồi null khi tải DTO lịch thật, imageUrl bị bỏ và customerPackageId bị bỏ. Đây không phải kết quả toàn bộ flutter test.
- Script chứng cứ: `.local-integration/mobile-review-model-probe-20261023.dart`.
- Chưa có google-services.json thật trong clone; chỉ có file .example. Plugin google-services đã bật và FirebaseOptions đang có giá trị mẫu cần cấu hình. Cần bàn giao cấu hình Firebase/Google theo môi trường trước khi chạy push/Google thật; không commit khóa riêng.
- Chưa kiểm thử giao dịch thật, thiết bị Android, nhận push, gửi OTP hoặc Google OAuth.

## Đề nghị gửi thành viên Flutter

Ưu tiên sửa cleanup push khi logout; thống nhất Google/2FA với API; bổ sung gói dịch vụ/đổi điểm; sửa voucher và ảnh API; hoàn thiện đánh giá/thông báo. Sau khi dùng SDK tương thích, chạy analyze/test/build và test trọn luồng trên API chung hiện tại. Không lấy backend cũ trong nhánh mobile để ghi đè backend đã cập nhật.


## Bổ sung: đã đọc Firebase_Config_Cho_Nhom ngày 23/10/2026

- Đã đọc HUONG_DAN_CHO_NHOM.txt và kiểm tra cấu trúc hai tệp cấu hình, không in khóa/định danh OAuth ra báo cáo.
- Hai bản google-services.json giống nhau; hai bản firebase_options.dart giống nhau. Cấu hình có Android/Web, không còn placeholder; project/app ID giữa JSON và Dart khớp nhau.
- Android package com.example.app_doancunhan khớp ứng dụng; Google server client ID khớp mã Flutter hiện tại.
- Đây là cấu hình ứng dụng khách, không phải service account; không có private_key. Có thể dùng để thay cấu hình mẫu Flutter theo hướng dẫn, nhưng tác vụ đọc này chưa copy/sửa source.
- Bộ tệp này KHÔNG bổ sung endpoint /auth/google cho API; lỗi thiếu endpoint vẫn còn. Cũng KHÔNG cung cấp credential máy chủ để API gửi Firebase push.
- API hiện có sender yêu cầu Firebase.Enabled và CredentialsPath/CredentialFile trỏ tới JSON service_account; bộ cấu hình vừa gửi không đáp ứng phần server đó. Chưa kiểm tra cấu hình từ User Secrets/biến môi trường hoặc Firebase Console.
- Hướng dẫn nói cả hai tệp đã gitignore là chưa đúng: google-services.json được ignore, nhưng lib/firebase_options.dart đã được Git theo dõi trong nhánh mobile. Copy đè Dart sẽ tạo thay đổi được Git nhận diện.
- Chưa xác minh trên thiết bị: SHA-1/SHA-256/OAuth Console, quyền Firebase, token nhận push hoặc việc gửi push thực.
