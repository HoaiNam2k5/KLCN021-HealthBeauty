> **Cập nhật mới nhất:** các lỗi token/khóa đăng nhập, quyền động, điểm/hóa đơn0, voucher, combo và Staff đã được sửa tiếp. Kết quả146test pass và trạng thái còn tồn tại hiện tại xem `API_FOLLOWUP_FIXES.md`. Nội dung đợt trước bên dưới là lịch sử, không phải trạng thái mới nhất.

# API ưu tiên đã sửa — 13/10/2026

Repo: `D:/KhoaLuan/DEV/KLCN021_HealthBeauty`.
Branch: `agent/priority-api-fixes`. Chưa commit/push. Giữ nguyên các thay đổi trước và file góp ý của anh. Không xử lý kho/bán sản phẩm.

## Kết quả

| API | Hành vi sau sửa |
|---|---|
| GET appointments/{id}, staff/{id} | Trả projection hữu hạn, giữ tên trường chính, không trả navigation ngược gây vòng JSON. HTTP thực tế200 thay cho500. Khách chỉ xem lịch của mình; nhân viên có quyền xem theo role. |
| POST invoices/{id}/payments | Chỉ Admin/Manager/Reception được xác nhận. Customer403 ngay ở authorization, không cộng điểm hoặc cập nhật hóa đơn. Đây vẫn là xác nhận thủ công của nhân viên, chưa tích hợp cổng thu tiền. |
| POST invoices | Chỉ lịch HoanThanh; phải khớp đầy đủ dịch vụ/combo/số lượng đã đặt. Combo thiếu/sai thành phần bị từ chối. Giá tính từ DB; không chấp nhận đổi dịch vụ rẻ hơn hoặc bỏ dòng. Khách vẫn tạo/xem hóa đơn của mình. |
| DELETE appointments/{id} | Chỉ ChoXacNhan/DaXacNhan/DaDen được hủy; trạng thái khác409, giữ nguyên dữ liệu. |
| PUT appointments/{id}, POST reschedule | Chỉ ChoXacNhan/DaXacNhan được đổi; kiểm tra va chạm và toàn bộ thời lượng nằm trong ca nhân viên. |
| POST appointments | Khi chỉ định nhân viên, toàn bộ thời lượng phải nằm trong một ca không nghỉ phép; ngoài ca400. Lịch chưa phân công nhân viên vẫn được tạo. |
| GET availability, available-slots | Các slot ứng viên cách nhau30phút; tính thời lượng dịch vụ và giao nhau với cả lịch từ hôm trước, giữ khoảng trống còn lại, bỏ lịch hủy và giờ đã qua. |
| PUT combos/{id} | Không đổi thành phần khi có lịch chưa hủy tham chiếu combo và chưa lập hóa đơn; trả409 để tránh làm lịch hợp lệ không còn xuất được hóa đơn. |

Nhân viên có hồ sơ khách hàng vẫn được tạo/xem/xác nhận hóa đơn của khách khác theo role. Khách hàng thường vẫn bị giới hạn quyền sở hữu.

## Frontend cần dùng

- Availability: `GET /api/v1/appointments/availability?date=YYYY-MM-DD&staffId=1&serviceId=2`. Có thể dùng `durationMinutes` thay serviceId khi cần tổng thời lượng nhiều dịch vụ; mặc định30. Nếu có serviceId thì thời lượng service được ưu tiên.
- Response availability vẫn là mảng `{nhanVienId,gioBatDau,gioKetThuc}`, nhưng mỗi phần tử là một slot có thể đặt, thay vì nguyên ca làm.
- Khách không dùng POST payments để tự đánh dấu đã thanh toán; nhân viên xác nhận sau khi thu tiền.
- Hóa đơn dùng `appointmentId`, `items[{serviceId hoặc comboId,quantity}]`; phải khớp dịch vụ thực hiện. Lịch cần chuyển HoanThanh trước.
- Catalog XLSX cập nhật các dòng API bị ảnh hưởng. Các mục kế hoạch ngoài phạm vi trong catalog vẫn cần rà riêng.

## File thay đổi trong đợt này

- Source: Controllers/AppointmentsController.cs, SupplementControllers.cs, InvoicesController.cs, CombosController.cs; Services/AppointmentTiming.cs; thêm Services/AppointmentViews.cs.
- Regression: cập nhật AppointmentRegressionTests.cs để fixture có ca làm; thêm PriorityAppointmentTests.cs và InvoiceRegressionTests.cs.
- Tài liệu/bằng chứng: README.md, PLANS.md, KLCN021_API_Catalog.xlsx, API_REVIEW.md, API_AUDIT_HTTP.json và thư mục .audit. Báo cáo audit cũ được giữ dưới thông báo trạng thái; các test tái hiện lỗi đã sửa được đánh dấu historical/skip.

## Kiểm chứng

- `dotnet test KLCN021_HealthBeauty.sln --no-restore`: **59 passed,0 failed,0 skipped**. Bao gồm17 test trước và42 trường hợp mới.
- `dotnet build KLCN021_HealthBeauty.sln --no-restore`: **0 warnings,0 errors**.
- HTTP SQL local: **31 GET:30 HTTP200,1 HTTP404,0 HTTP500**. HTTP404 là roleId1 không tồn tại, như audit trước.
- POST payments bằng Customer: **HTTP403** trước action; không ghi giao dịch vào SQL.
- `.audit` diagnostics: **5 passed,7 skipped**. Năm test pass xác nhận các lỗi còn tồn tại; không phải khẳng định năm lỗi này đã sửa.
- `git diff --check`, kiểm tra đọc lại XLSX và UTF-8: PASS. Review source độc lập không còn blocker trong phạm vi.
- Các thao tác thay đổi dữ liệu được thử trong EF InMemory tách biệt; chưa kiểm tra đường ghi trên SQL thật, transaction/constraint và yêu cầu đồng thời. HTTP local dùng cấu hình JWT/connection tạm thời, không sửa secret lưu trên máy.

## Còn tồn tại / bước tiếp theo

- Access token của tài khoản bị khóa chưa bị vô hiệu ngay; quyền động trong bảng quyền chưa được thực thi tại endpoint.
- Điểm bị trừ vượt phần giảm thực tế; hóa đơn0 có thể cố ghi thanh toán0 trái SQL CHECK; vòng đời/validation voucher và liên kết ledger chưa hoàn thiện.
- Giá dự kiến lịch vẫn nhận client; giá hóa đơn dùng catalog hiện tại. Chưa có snapshot lịch sử giá/thành phần combo. Combo từng bị chỉnh trước bản vá hoặc catalog ngừng hoạt động trước khi xuất hóa đơn cần xử lý riêng.
- Chưa giải quyết concurrency đặt lịch/thanh toán/điểm; chuyên môn nhân viên chưa được liên kết để kiểm tra; lịch không chọn nhân viên chưa kiểm tra ca làm.
- Những lỗi/bổ sung khác trong API_REVIEW.md vẫn là backlog. Ưu tiên tiếp theo: vô hiệu token tài khoản khóa, điểm/hóa đơn0 và quyền động.
