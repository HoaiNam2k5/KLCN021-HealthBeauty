# Kiểm tra web ngày 21/10/2026

Nhánh: `feature/huynh-web`. Đã pull fast-forward từ `b2ee367` đến `2ca4f838149f7876dcdb0dff8fda9dd18e4d1d3d`. Commit mới thay đổi 15 file web; API/SQL không đổi. Đây là kiểm tra mã nguồn và build/test, chưa kiểm thử giao diện trên trình duyệt hoặc giao dịch thực với database.

## Kết quả theo yêu cầu

| Yêu cầu | Kết quả |
|---|---|
| Ngày đánh giá lệch 7 giờ | Đã sửa cách gửi: dùng chuỗi giờ địa phương `YYYY-MM-DDTHH:mm:ss`, không chuyển sang UTC bằng toISOString. |
| Voucher đã đổi lỗi 409 do mất chủ sở hữu | Đã giữ `editing.customerId` khi voucher có điểm đổi; khóa sửa chủ sở hữu/điểm ở voucher đã cấp. |
| Báo cáo | Đã thêm quý/năm và lựa chọn nhóm dịch vụ/combo/nhân viên/nhóm dịch vụ. Còn thiếu phần bên dưới. |
| Điểm trung bình | Đã lấy averageRating tổng hợp từ API, không tự tính trên 200 dòng. Có vấn đề quyền truy cập mới. |
| Dịch vụ đặt nhiều nhất | Đã sắp xếp theo quantity trước khi lấy top 5. |
| Tổng khách | Chưa sửa: vẫn đếm độ dài danh sách /customers, API giới hạn 200. |
| Quản lý gói dịch vụ | Đã có giao diện và nối API; cần sửa các lỗi nghiệp vụ bên dưới trước khi chốt. |

## Các lỗi cần sửa ưu tiên

1. **Đặt lịch gói có thể thành lịch thanh toán thường.** `AppointmentsPage.tsx:50–52,93–99`: customerPackageId còn trong form nhưng chosenPackage có thể undefined sau khi đổi khách hoặc khi danh sách gói đang tải/lỗi. Code vẫn gửi lịch với giá thường và bỏ customerPackageId. Cần xóa lựa chọn gói khi đổi khách; nếu đã chọn gói mà chưa xác thực được thì chặn gửi, không tự chuyển sang trả tiền thường.
2. **Báo cáo nhân viên hiển thị số lượng bằng 0.** `ReportsPage.tsx:52` đọc quantity nhưng API nhóm staff trả invoiceCount và paidRevenue. Cần dùng đúng trường và đổi tiêu đề/chỉ số theo loại nhóm.
3. **Tổng khách tối đa 200.** `ReportsPage.tsx` đếm customerList.length; `CustomersController.cs:43` Take(200). Cần API tổng hợp số khách thay vì đếm danh sách.
4. **Quyền truy cập báo cáo đánh giá:** query mới gọi /reviews/management cần REVIEW.MODERATE, trong khi trang chỉ yêu cầu REPORT.READ. Tài khoản chỉ có quyền báo cáo sẽ lỗi 403 ở query này. Cần thống nhất quyền hoặc endpoint tổng hợp riêng.
5. **Quyền trang gói:** menu /packages cho SERVICE.READ nhưng trang luôn gọi /service-packages/management cần SERVICE.WRITE; chưa ẩn đầy đủ nút tạo/sửa/bán theo quyền. API vẫn chặn, nhưng người dùng gặp 403.

## Báo cáo còn thiếu

- Lịch hẹn vẫn cố định groupBy=status; chọn ngày/tuần/tháng chưa thay đổi kiểu tổng hợp lịch hẹn.
- Chưa có bộ lọc trạng thái, nhân viên, dịch vụ, combo, nhóm dịch vụ, từ khóa.
- Xuất Excel vẫn cố định báo cáo orders theo kỳ, chưa xuất theo nhóm đang chọn hoặc loại lịch hẹn/khách mới.

## Gói dịch vụ đã có và phần cần hoàn thiện

Đã có menu, danh mục tạo/sửa/bật tắt, upload ảnh, bán gói cho khách, xác nhận thanh toán theo quyền, tab gói của khách với lượt cấp/đã dùng/giữ chỗ/khả dụng và hạn dùng, lịch sử sử dụng, đặt lịch bằng gói, loại lịch dùng gói khỏi hóa đơn thường, thống kê doanh thu gói.

Còn cần:
- Sau tạo/hủy/đổi trạng thái lịch phải làm mới cache gói để số lượt phản ánh ngay; hiện chỉ làm mới lịch/khung giờ.
- Sau thanh toán gói làm mới báo cáo doanh thu gói.
- Form Thêm gói phải resetFields: hiện có thể giữ tên/giá/ảnh từ gói vừa sửa.
- Nút hủy giao dịch gói chưa thanh toán chưa có UI dù API wrapper đã tồn tại.
- Chọn khách khi bán gói đang lọc trên danh sách tối đa 200; cần tìm kiếm phía API.

## Kiểm chứng

- npm test: **35/35 pass**; commit không bổ sung test mới cho các tình huống trên.
- npm run build -- --configLoader native: **pass**, TypeScript và Vite build thành công (3837 modules). Có cảnh báo kích thước chunk trên 500 kB.
- npm run lint: **fail 3 lỗi có sẵn** tại BillingPage.tsx:64 (setState trong effect), :205 (2 irregular whitespace).
- Không sửa source, không commit hoặc push trong lần kiểm tra này. Worktree review sạch sau pull.
- File ReportingWorkbook.cs đang sửa sẵn ở worktree chính được giữ nguyên.

Ưu tiên thành viên web sửa lỗi đặt lịch gói, trường báo cáo nhân viên, tổng khách và quyền truy cập; sau đó hoàn thiện bộ lọc và kiểm thử giao dịch trên môi trường API đang chạy.
