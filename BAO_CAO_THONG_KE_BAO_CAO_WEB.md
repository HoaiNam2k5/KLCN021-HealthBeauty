# Thống kê và báo cáo – phần Web cần hoàn thiện

| Yêu cầu | Web hiện tại / việc cần làm |
|---|---|
| Lịch hẹn theo ngày/tuần/tháng/trạng thái | Có tổng theo trạng thái; dùng API tổng hợp mới để vẽ theo kỳ. |
| Đơn hàng theo ngày/tuần/tháng/quý/năm | Dùng hóa đơn dịch vụ/combo; biểu đồ hiện lấy danh sách hóa đơn giới hạn 100 nên có thể thiếu dữ liệu. |
| Theo dịch vụ/combo/nhân viên/nhóm dịch vụ | Bổ sung lựa chọn nhóm và các bộ lọc mới; API cũ theo dịch vụ chưa nhận khoảng ngày. |
| Khách hàng mới | Chưa có; số khách hiện đếm danh sách tối đa 200, không phải toàn bộ. |
| Tìm kiếm/lọc/xuất | Web có khoảng ngày nhưng cần gửi `to` = 00:00 ngày kế tiếp; nút Excel hiện xuất CSV. In trình duyệt có thể lưu PDF, chưa có API PDF. |

## API mới (Admin/Manager/Reception + REPORT.READ)
- `GET /api/v1/reports/appointment-summary?groupBy=day|week|month|status`
- `GET /api/v1/reports/orders?page=1&pageSize=20`: `{totalCount,paidRevenue,page,pageSize,items}`; danh sách phân trang, tổng không phụ thuộc trang.
- `GET /api/v1/reports/order-summary?groupBy=day|week|month|quarter|year`
- `GET /api/v1/reports/order-breakdown?groupBy=service|combo|staff|category`
- `GET /api/v1/reports/new-customers?groupBy=day|week|month|quarter|year`
- `GET /api/v1/reports/export?report=appointments|orders|breakdown|new-customers&groupBy=...`: tải XLSX thật; `orders` xuất tổng hợp theo kỳ.

Bộ lọc chung: `from` bao gồm, `to` loại trừ; `status`, `staffId`, `serviceId`, `comboId`, `categoryId`, `search` (tên/SĐT khách). Khách mới chỉ dùng khoảng ngày và search. Tuần bắt đầu thứ Hai; ngày theo giờ máy chủ như dữ liệu hiện có. Khoảng không có dữ liệu không tự sinh dòng 0. Sai bộ lọc/nguồn quá lớn trả 400, cần thu hẹp khoảng ngày; không cắt âm thầm. Xuất tối đa 10.000 dòng gồm metadata.

`order-summary`: `{totalCount,paidRevenue,items:[{periodStart,invoiceCount,paidInvoiceCount,unpaidInvoiceCount,paidRevenue}]}`. Ngày hóa đơn là `NgayLap`, chưa phải ngày thực thu; doanh thu chỉ gồm `DaThanhToan`. Nhóm nhân viên dùng toàn bộ tiền hóa đơn sau giảm, mỗi hóa đơn tính một lần. Nhóm dịch vụ/combo/loại dùng `grossAmount` trước giảm của dòng hàng, không cộng với `paidRevenue`; combo nằm nhóm `comboUnallocated` khi theo loại, không chia giả cho dịch vụ thành phần. Lọc dịch vụ/loại chỉ xét dịch vụ trực tiếp. Bộ lọc hóa đơn chọn hóa đơn có dòng khớp; tổng hóa đơn vẫn là tổng cả hóa đơn, không phải phần dòng khớp.

Khách mới: `{totalCount,unknownHistoricalCount,items:[{periodStart,count}]}`. Chạy `12_ReportingCustomerCreatedAt.sql` sau SQL11. Khách cũ chưa biết ngày tạo giữ NULL và được báo riêng; không suy đoán ngày lịch hẹn thành ngày tạo. Không có bảng mới. Các API báo cáo cũ giữ định dạng để tương thích; Web chuyển dần sang API mới. Không sửa Web/Flutter trong đợt này.

Kiểm chứng đợt này: **403/403 test đạt**, build 0 cảnh báo/0 lỗi; gồm HTTP phân quyền và thu hồi quyền `REPORT.READ`, bộ lọc, kỳ báo cáo và XLSX. File XLSX được đọc độc lập bằng openpyxl, giữ đúng tiếng Việt/số và nội dung bắt đầu bằng dấu `=` vẫn là văn bản.

**SQL12 CHƯA áp dụng vào database local.** Kết nối kiểm thử SQL Server bị `Failed to generate SSPI context` trước khi tạo database; chưa kiểm chứng truy vấn SQL thực hoặc chạy migration hai lần. Không sửa dữ liệu thật. Trước khi chạy API bản mới, anh mở `DB_KLCN021/12_ReportingCustomerCreatedAt.sql` trong SSMS, kết nối SQL Server đang dùng rồi Execute (F5); sau đó khởi động lại API. File có `USE KLCN021_HealthBeauty`, chỉ thêm cột/index, không gán ngày giả cho khách cũ.
