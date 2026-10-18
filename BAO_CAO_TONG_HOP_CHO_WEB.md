# BÁO CÁO TỔNG HỢP CHO THÀNH VIÊN WEB — HEALTHBEAUTY

Cập nhật: 18/10/2026. Nhánh nhận code: **`feature/huynh-web`**.
Đợt này bổ sung API, SQL, kiểm thử và tài liệu; giữ nguyên mã Web/Flutter của thành viên.

## 1. Pull và chuẩn bị chạy

```powershell
git switch feature/huynh-web
git pull origin feature/huynh-web
```

- Database đã tồn tại: chạy các migration còn thiếu theo thứ tự **04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12** trong `DB_KLCN021`. Không cần chạy lại SQL gốc để nâng cấp.
- Database mới: dùng `DB_KLCN021/KLCN021_HealthBeauty.sql`, đã tích hợp các migration.
- SQL09 dừng nếu dữ liệu cũ có nhiều hóa đơn cho cùng lịch hẹn; cần kiểm tra thủ công, script không xóa dữ liệu.
- **Máy anh Nam đã chạy đến SQL11; SQL12 chưa áp dụng do lỗi xác thực Windows SSPI trong môi trường kiểm thử.** Thành viên vẫn phải chạy migration còn thiếu trên máy mình trước khi khởi động API mới. Chưa xác minh SQL12 trên SQL Server thật.
- Chạy API: vào `HealthBeauty.Api`, dùng `dotnet run --launch-profile http`. Swagger: `http://localhost:5230/swagger`; tiền tố API: `/api/v1`.
- Chạy Web: vào `HealthBeauty.Web`, dùng `npm ci` rồi `npm run dev`.
- JWT/SQL/SMTP/Cloudinary/Firebase là cấu hình riêng từng máy, không đưa vào Git. `Configuration/cloudinary.example.json` chỉ là mẫu, không tự được nạp. Đặt cấu hình trong file `HealthBeauty.Api/appsettings.Development.local.json` hoặc User Secrets/biến môi trường.

## 2. Việc Web cần làm, theo thứ tự ưu tiên

| Ưu tiên | Hạng mục | Việc cần sửa/bổ sung |
|---|---|---|
| P1 | Đọc đánh giá | `GET /reviews` trả `{averageRating,totalReviews,items}`. Adapter hiện bỏ qua `items`, gây danh sách rỗng; không tính trung bình lại từ 200 dòng gần nhất. |
| P1 | Ảnh dịch vụ/combo | Thay ảnh localStorage bằng upload API; lưu `imageUrl` trong DTO dịch vụ/combo và đọc lại từ API. |
| P1 | Phản hồi/kiểm duyệt | Thay phản hồi localStorage bằng API; thêm xem đánh giá đã ẩn, bộ lọc dịch vụ/ngày/sao, xóa mềm. |
| P1 | Thống kê | Dùng các API tổng hợp mới; không dựng doanh thu từ `/invoices` chỉ lấy 100 bản ghi, không lấy độ dài danh sách khách tối đa 200 làm tổng khách. |
| P2 | Điểm/voucher | Thêm cấu hình `pointsCost`, lịch sử điểm và hướng dẫn hai cách dùng điểm; không gán miễn phí voucher cần đổi điểm. |
| P2 | Quên mật khẩu | Thêm hai màn hình yêu cầu OTP và đặt lại mật khẩu; xử lý thời hạn, giới hạn gửi lại và 429. |
| P2 | Thông báo | Web quản trị chỉ kích hoạt nghiệp vụ; backend tự tạo thông báo, không gửi trùng. Inbox/FCM bên dưới dành cho tài khoản có hồ sơ khách, chưa có inbox Admin riêng. |
| P2 | Xuất báo cáo | Nút hiện tại xuất CSV; chuyển tải XLSX từ API bằng `responseType: 'blob'`. In trình duyệt vẫn có thể lưu PDF; chưa có API PDF. |

## 3. Ảnh dịch vụ và combo

- `POST /media/images`: Bearer token, `multipart/form-data`, trường `file`, PNG/JPEG/WebP tối đa 5 MiB. Axios không ép `Content-Type: application/json`; để trình duyệt tạo multipart boundary.
- Thành công **201**: `{imageUrl,publicId}`. Gửi `imageUrl` vào request tạo/sửa dịch vụ hoặc combo; URL được lưu trong SQL.
- Khi sửa: bỏ qua/null giữ ảnh cũ; chuỗi rỗng xóa liên kết. Bỏ liên kết chưa xóa file vật lý trên Cloudinary.
- Cần vai trò Admin/Manager/Reception và quyền `SERVICE.WRITE`; 401 cần đăng nhập, 403 thiếu quyền, 503 chưa cấu hình lưu ảnh.
- Phạm vi hiện tại là ảnh dịch vụ/combo; chưa có upload avatar, bộ sưu tập nhiều ảnh hoặc quản lý sản phẩm/kho.

## 4. Đánh giá dịch vụ

- `GET /reviews/management?serviceId=1&from=2026-10-01T00:00:00&to=2026-10-18T23:59:59&stars=5&status=An&page=1&pageSize=20`.
- Bộ lọc tùy chọn; `status=HienThi|ChoDuyet|An`, bỏ status lấy tất cả chưa xóa. Kết quả `{items,totalCount,averageRating,page,pageSize}`; có tên khách và dịch vụ/combo, không cần tải thêm toàn bộ khách/hóa đơn để ghép tên.
- `PATCH /reviews/{id}/moderation?visible=true|false`: duyệt/ẩn.
- `PUT /reviews/{id}/reply`, JSON `{ "reply": "Cảm ơn anh/chị" }`: lưu/thay phản hồi, 1–2000 ký tự không chỉ khoảng trắng.
- `DELETE /reviews/{id}`: xóa mềm; không giải phóng hóa đơn để khách gửi đánh giá lặp lại.
- Các lệnh thành công 204; 404 không tồn tại/đã xóa; 409 tải lại dữ liệu. Cần `REVIEW.MODERATE` và vai trò Admin/Manager/Reception.
- Trang khách đọc `reply/repliedAt` từ danh sách công khai, tên người trả lời hiển thị HealthBeauty. Phản hồi chưa phát push/email.
- Đánh giá hợp lệ mới vẫn hiển thị ngay theo hợp đồng cũ; trang Web không ghi rằng mọi đánh giá bắt buộc chờ duyệt.
- **Ngày lọc đánh giá bao gồm cả mốc `to`; khác báo cáo thống kê bên dưới.**

## 5. Điểm thưởng và voucher

- Request quản lý voucher thêm `pointsCost` (0–1.000.000). 0 là voucher tặng/khuyến mãi cũ; >0 là voucher đổi điểm, tạo chưa gán khách.
- Mỗi mã voucher là một suất đổi một lần; muốn nhiều suất cần tạo nhiều mã. Không gán trực tiếp voucher có giá điểm để bỏ qua bước thu điểm.
- API phía khách: `GET /customers/me/voucher-offers`; `POST /customers/me/vouchers/{id}/redeem` không body, trả `{voucherId,code,pointsSpent,remainingPoints}`.
- Web quản trị cấu hình giá điểm; thao tác đổi do khách thực hiện bằng tài khoản khách, không dùng Admin đổi thay.
- `GET /customers/{id}/points?page=1&pageSize=20`: lịch sử quản trị, cần `CUSTOMER.READ`; kết quả `{customerId,diemThuong,transactions,totalCount,page,pageSize}`.
- Thanh toán cộng `floor(tiền thực trả/10.000)` điểm. `pointsToRedeem` trên hóa đơn là đổi trực tiếp **1 điểm = 1đ**, trừ khi lập hóa đơn.
- Đổi voucher trừ `pointsCost` đúng lúc đổi; dùng voucher đã đổi không thu lại giá điểm lần hai. 409: tải lại số dư/trạng thái trước khi thử lại.
- Combo hiện tại là nhóm dịch vụ; chưa phải gói liệu trình trả trước theo nhiều buổi.

## 6. Thống kê và báo cáo

Tất cả API sau cần Admin/Manager/Reception và `REPORT.READ`:

| API | Mục đích |
|---|---|
| `GET /reports/appointment-summary?groupBy=day|week|month|status` | Số lịch hẹn theo kỳ và trạng thái |
| `GET /reports/orders?page=1&pageSize=20` | Danh sách hóa đơn có tìm kiếm, phân trang và tổng toàn bộ kết quả |
| `GET /reports/order-summary?groupBy=day|week|month|quarter|year` | Số hóa đơn và doanh thu đã thanh toán theo kỳ |
| `GET /reports/order-breakdown?groupBy=service|combo|staff|category` | Phân nhóm theo dịch vụ/combo/nhân viên/nhóm dịch vụ |
| `GET /reports/new-customers?groupBy=day|week|month|quarter|year` | Khách mới và số khách cũ chưa biết ngày tạo |
| `GET /reports/export?report=orders&groupBy=month` | XLSX; report nhận appointments/orders/breakdown/new-customers |

- Bộ lọc: `from`, `to`, `status`, `staffId`, `serviceId`, `comboId`, `categoryId`, `search` theo tên/SĐT khách. Khách mới chỉ dùng from/to/groupBy/search. `pageSize` tối đa 100.
- Thống kê dùng **`from` bao gồm, `to` loại trừ**; chọn hết ngày 18/10 thì gửi `to=2026-10-19T00:00:00`. Tuần bắt đầu thứ Hai; ngày theo giờ máy chủ hiện hành.
- Kết quả tổng hợp thường là `{totalCount,items,...}`; không có dữ liệu không tự sinh dòng 0. Web tự thêm điểm 0 nếu biểu đồ cần.
- Doanh thu tính hóa đơn `DaThanhToan`, theo `NgayLap` (ngày lập, chưa phải báo cáo ngày thực thu). `paidRevenue` là số tiền sau giảm.
- Phân nhóm nhân viên tính hóa đơn một lần; nhóm dịch vụ/combo/loại trả `grossAmount` trước giảm theo dòng hàng. Không cộng `grossAmount` với `paidRevenue`.
- Combo theo nhóm dịch vụ nằm mục `comboUnallocated`, chưa phân bổ doanh số giả cho các dịch vụ con. Lọc service/category chỉ xét dịch vụ trực tiếp; tổng hóa đơn là tổng cả hóa đơn có dòng khớp.
- Khách cũ không có ngày tạo giữ NULL và báo riêng `unknownHistoricalCount`; không coi họ là khách mới ngày nâng cấp.
- Export nhận cùng bộ lọc, tối đa 10.000 dòng gồm metadata; quá giới hạn trả 400 để thu hẹp bộ lọc. `report=orders` xuất tổng hợp theo kỳ, không phải danh sách hóa đơn chi tiết.

## 7. Quên mật khẩu, thông báo và phân quyền

- `POST /auth/forgot-password`, JSON `{email}`: thông báo thành công chung, không trả OTP; Web không suy luận email có tồn tại.
- `POST /auth/reset-password`, JSON `{email,otp,newPassword}`: OTP chuỗi 6 số giữ số 0 đầu; mật khẩu 8–128 ký tự. Thành công yêu cầu đăng nhập lại, không tự đăng nhập. 429 hiển thị thời gian chờ.
- OTP hết hạn sau 15 phút, tối đa 5 lần thử; gửi lại cách tối thiểu 60 giây. Gửi email thật cần SMTP riêng của máy chạy API.
- Các API thông báo sau dành cho tài khoản có hồ sơ khách hàng (thường là Flutter/Web khách), không phải inbox Admin; tài khoản quản trị không có hồ sơ khách sẽ nhận 403. Thông báo: `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/{id}/read`, `PATCH /notifications/read-all`.
- Đăng ký thiết bị push: `POST /notifications/device-token`; bỏ thiết bị: `DELETE /notifications/device-token?token=...`. Hợp đồng body/FCM xem `HealthBeauty.Api/REVIEWS.md` mục thông báo.
- Nhắc lịch đã xác nhận được backend tạo trước giờ hẹn, có chống trùng; không cần Web gọi gửi nhắc. Thông báo thay đổi lịch/thanh toán/khuyến mãi đã có hook backend.
- Khi đăng nhập, lấy `GET /auth/permissions` để hiện menu/nút. API kiểm tra quyền hiện tại trong DB; không dựa vào tên role đơn thuần. 401 đăng nhập lại; 403 thông báo thiếu quyền.

## 8. Kiểm tra trước khi bàn giao Web

- [ ] Upload ảnh và lưu dịch vụ/combo; tải lại hoặc mở trình duyệt khác vẫn thấy ảnh.
- [ ] Hiện danh sách đánh giá, lọc, ẩn/hiện, phản hồi, xóa; kiểm tra khách thấy đúng phản hồi.
- [ ] Quyền bị thu hồi không còn dùng được API, nút/menu tương ứng được ẩn.
- [ ] Voucher giá điểm và lịch sử điểm đúng; không trừ hai lần.
- [ ] Báo cáo tuần/quý/năm, bộ lọc và tổng không phụ thuộc trang; tải XLSX mở đúng.
- [ ] Khách cũ chưa có ngày tạo được giải thích, không hiển thị số liệu giả.
- [ ] Quên mật khẩu/OTP và thông báo dùng API thật; không báo gửi thành công khi chỉ lưu localStorage.

Kiểm chứng backend: **403/403 test đạt**, build 0 lỗi/cảnh báo; XLSX đã đọc độc lập bằng openpyxl. Các migration 07–11 từng được kiểm tra trên SQL local; riêng SQL12 và các truy vấn báo cáo SQL thực **chưa kiểm chứng** do SSPI. Không có khóa Cloudinary/SMTP/JWT/Firebase trong tài liệu hoặc commit.
Chi tiết: `HealthBeauty.Api/REVIEWS.md` và `KLCN021_API_Catalog.xlsx`; ba báo cáo từng module vẫn giữ để tra cứu.
