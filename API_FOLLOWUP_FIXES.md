# Sửa lỗi API còn lại — 13/10/2026

Repo/Git/write scope: `D:/KhoaLuan/DEV/KLCN021_HealthBeauty`; không sửa repo khác. Branch `agent/api-followup-fixes`. Giữ nguyên các sửa trước, không commit/push, không xử lý kho/bán sản phẩm.

## Đã sửa

| Nhóm | Kết quả |
|---|---|
| Access token | Mỗi request xác thực kiểm tra tài khoản tồn tại, đang hoạt động, không khóa tạm, role đúng với DB. Khóa/đổi role có hiệu lực với token đang dùng; token có role giả/thừa hoặc identity sai bị từ chối401. |
| Login/refresh/logout | Login thất bại tăng bộ đếm và ghi log. Mặc định5 lần sai khóa15phút; cấu hình Authentication:MaxFailedAttempts/LockoutMinutes. Hết khóa bắt đầu lại bộ đếm; thành công xóa khóa. Refresh tôn trọng khóa; logout chỉ thu hồi refresh token của chính người gọi. |
| Quyền động | Filter toàn cục yêu cầu grant hiện tại DuocCap=true và Quyen.TrangThai=true bên cạnh role allowlist. Thu hồi quyền áp dụng ở request tiếp theo, không có bypass Admin. Tách đường khách tự phục vụ theo ownership khỏi đường quản lý. Coverage test kiểm tra mọi action hiện có role restriction được ánh xạ. |
| Điểm/hóa đơn0 | Chỉ trừ điểm nguyên thực sự giảm tiền, ledger có HoaDonID. Hóa đơn0 được nhân viên có quyền hoàn tất không tạo Thanhtoan amount0 và không cộng điểm. Lặp lại quyết toán trả409. |
| Voucher/khuyến mãi | Mã normalize trim+uppercase thống nhất validate/lập hóa đơn. Create/update voucher kiểm tra FK, mã trùng, hạn và số tiền. Khuyến mãi chỉ nhận PhanTram0..100 hoặc SoTien>=0; chuẩn hóa cả dữ liệu cũ khi tính. Danh sách voucher khách tôn trọng ngày và cấu hình giảm hợp lệ. Xóa khuyến mãi có voucher tham chiếu trả409, kể cả voucher đã khóa/dùng. |
| Booking/combo | Bỏ giá client, dùng DB. Kiểm tra combo tồn tại, hoạt động, đúng hiệu lực ngày hiện tại và ngày đặt, đầy đủ thành phần và số lượng. Giá combo phân bổ các dòng có bù phần làm tròn cuối để tổng chính xác. Create/update combo từ chối serviceId trùng. |
| Staff/ca làm | Reception được list nhân viên. Staff chỉ xem lịch được gán, kể cả tài khoản đồng thời có hồ sơ khách. Thêm me/appointments và me/schedules. PUT ca làm kiểm tra nhân viên, trùng ca và loại trừ ca đang sửa. DELETE staff chặn mọi lịch/ca tham chiếu, kể cả lịch hủy để tránh FK500. |
| Review | Thêm GET /reviews/pending cho Admin/Manager có REVIEW.MODERATE; lấy tối đa200 đánh giá chờ duyệt cũ nhất. Public GET reviews vẫn chỉ hiển thị đánh giá đã duyệt. |

## Cần áp dụng cho database đang có

Script `DB_KLCN021/03_ApiPermissionGrants.sql` thêm những grant còn thiếu:
- Reception: CUSTOMER.WRITE, STAFF.READ, INVOICE.WRITE.
- Staff: STAFF.READ.

Script chỉ INSERT nếu chưa có, không ghi đè DuocCap=false. Seed02 cũng cập nhật cùng quyền cho DB mới. **Chưa chạy migration này vào database của nhóm**; DB cũ thiếu grant sẽ nhận403 ở các thao tác tương ứng cho đến khi áp dụng. Không cần chạy lại toàn bộ seed để bổ sung grant.

## Thay đổi contract cần frontend biết

- Booking `expectedPrice` gửi lên không còn quyết định giá lưu.
- Staff GET `/api/v1/staff/me/appointments`, `/api/v1/staff/me/schedules?from=YYYY-MM-DD&to=YYYY-MM-DD`; đều Staff-only và lọc theo hồ sơ nhân viên, thiếu hồ sơ trả[]. Staff cũng dùng GET appointments và detail với phạm vi được gán.
- Quyết toán invoice amount0 trả `{invoiceId,status:"DaThanhToan",amount:0,paymentRequired:false}`; amount>0 giữ PaymentResponse như trước. Khách luôn bị403 khi xác nhận.
- Voucher update trả projection scalar tránh EF back references, giữ tên trường chính. Promo types hợp lệ: PhanTram, SoTien.
- Permission filter dùng service/code cụ thể. Role có quyền trên giao diện nhưng grant bị thu hồi vẫn403. Mã grant chi tiết trong `Services/DatabasePermissionFilter.cs`; catalog đã đồng bộ các mục liên quan.

## File sửa/thêm

- Source sửa: Program.cs, Controllers/AuthController.cs, AppointmentsController.cs, CustomersController.cs, SupplementControllers.cs, CombosController.cs, InvoicesController.cs, PromotionsController.cs.
- Service thêm: AccountTokenValidation.cs, DatabasePermissionFilter.cs, VoucherRules.cs.
- Test thêm: AuthSecurityRegressionTests.cs, BookingValidationRegressionTests.cs, FinanceFollowupTests.cs, PermissionRegressionTests.cs, AuthorizationHttpTests.cs.
- SQL: cập nhật02_SeedData.sql; thêm03_ApiPermissionGrants.sql.
- Tài liệu: README.md, PLANS.md, KLCN021_API_Catalog.xlsx, API_REVIEW.md, API_PRIORITY_FIXES.md, API_AUDIT_HTTP.json, API_AUDIT_ROUTES.json và .audit hướng dẫn/script. Không sửa file góp ý của anh.

## Kiểm chứng

- Baseline tài chính:11failed/2passed; auth4failed; booking17failed/4passed. Sau sửa, bộ test chính **146passed,0failed,0skipped** (59 trước +87 trường hợp mới).
- Test HTTP thật bằng Kestrel và DB InMemory tách biệt: cùng JWT, cập nhật dịch vụ200 → thu hồi grant403 → khóa account401 → khóa tạm401 → mở lại200; public reads vẫn200 khi revoke grant.
- Test JWT thật tạo bằng TokenService, xác minh chữ ký/lifetime và claim mapping; không chỉ dùng principal giả.
- Build: **0warning,0error**.
- Swagger: **74 thao tác** (34GET,17POST,11PUT,4PATCH,8DELETE).
- SQL local HTTP sweep: **34GET:31HTTP200,1HTTP404,2HTTP403,0HTTP500**.404 do roleId1 không tồn tại;2HTTP403 là hai route me Staff-only thử bằng Admin vì SQL local chưa có account Staff hoạt động. Happy-path Staff đã có regression trên DB tách biệt; chưa thử với Staff thật trên SQL.
- Signed JWT chứa account không tồn tại:HTTP401. Customer payment confirmation:HTTP403 trước action, không ghi giao dịch vào SQL.
- Diff whitespace, đọc lại XLSX/UTF-8:PASS. Review source không thấy blocker; lỗi loại giảm có khoảng trắng do reviewer phát hiện đã sửa và có regression.
-12test audit cũ nay historical/skip, không tính vào146test chính. Mọi sửa dữ liệu trong test chạy DB tách biệt. Không thay stored secrets hay ghi dữ liệu nghiệp vụ SQL hiện có.

## Còn tồn tại

- Concurrency: yêu cầu đồng thời đặt lịch/lập hóa đơn/thanh toán/dùng voucher/điểm hoặc logincounter vẫn cần transaction/concurrency protection và test SQL race. Không khẳng định test tuần tự giải quyết race.
- Lịch sử: chưa có snapshot bất biến cho giá/thành phần combo; catalog sửa/ngừng trước khi lập hóa đơn hoặc combo đã bị chỉnh trước bản vá còn cần chính sách dữ liệu lịch sử.
- Voucher/điểm vẫn tiêu thụ lúc lập bill; chưa có workflow hủy bill/hoàn quyền lợi, liên kết voucher với bill và hoàn tiền. Điều kiện khuyến mãi dạng text chưa tự diễn giải thành điều kiện máy kiểm tra.
- Chưa có quan hệ chuyên môn nhân viên/dịch vụ; booking chưa chọn nhân viên vẫn chưa kiểm tra ca làm. Các API chưa triển khai được liệt kê riêng trong audit cũ, không tự coi là lỗi đã sửa.
- Luồng ghi chưa chạy trên SQL thật; migration quyền chưa áp dụng vào SQL. Bước tiếp theo: áp dụng script quyền, thử luồng nghiệp vụ với tài khoản Staff/Reception thật, rồi xử lý concurrency và vòng đời bill/voucher.
