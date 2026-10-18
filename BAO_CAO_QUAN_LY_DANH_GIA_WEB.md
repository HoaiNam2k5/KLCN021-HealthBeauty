# Báo cáo quản lý đánh giá dịch vụ — 18/10/2026

| Yêu cầu | Web hiện tại | API sau bổ sung |
|---|---|---|
| Xem đánh giá và bình luận | Có giao diện nhưng adapter chưa đọc `items`, có thể hiện danh sách rỗng | Có danh sách quản trị, tên khách, dịch vụ/combo, phân trang |
| Lọc dịch vụ, thời gian, số sao | Chỉ lọc sao trên dữ liệu đã tải; thiếu dịch vụ/thời gian | Đã hỗ trợ đầy đủ ở máy chủ |
| Duyệt, ẩn, xóa bình luận | Có duyệt/ẩn; thiếu mục đã ẩn và nút xóa | Có duyệt/ẩn và xóa mềm, không khôi phục bản đã xóa |
| Phản hồi khách hàng | Đang lưu localStorage, chưa gửi API | Phản hồi được lưu CSDL, hiện cùng đánh giá công khai |

Thành viên Web cần làm:
- Sửa `asReviewArray` để đọc `{items,...}`; bỏ lưu phản hồi localStorage và thông báo gửi thành công giả.
- Gọi `GET /api/v1/reviews/management?serviceId=1&from=2026-10-01T00:00:00&to=2026-10-18T23:59:59&stars=5&status=An&page=1&pageSize=20`. Các bộ lọc đều tùy chọn; `status`: `HienThi`, `ChoDuyet`, `An`; bỏ status để lấy cả ba. `from/to` so sánh bao gồm đúng thời điểm, Web chọn ngày cần gửi đầu/cuối ngày theo múi giờ lịch hẹn hiện có.
- Đọc `{items,totalCount,averageRating,page,pageSize}`; mỗi item có `danhGiaId,hoaDonId,soSao,binhLuan,ngayDanhGia,trangThai,tenKhachHang,customerId,services,reply,replyAccountId,repliedAt,version`; `services` chứa `serviceId/serviceName/comboId/comboName` từ dòng hóa đơn. Lọc dịch vụ khớp cả thành phần combo.
- Duyệt/ẩn: `PATCH /api/v1/reviews/{id}/moderation?visible=true|false`; xóa: `DELETE /api/v1/reviews/{id}`; phản hồi/thay phản hồi: `PUT /api/v1/reviews/{id}/reply` với `{ "reply": "Nội dung phản hồi" }` (1–2000 ký tự, không chỉ khoảng trắng). Thành công trả `204`, tải lại danh sách; `409` tải lại và thử lại; `404` bản không tồn tại/đã xóa.
- Ba vai trò `Admin,Manager,Reception` đều cần quyền đang được cấp `REVIEW.MODERATE`; ẩn nút/mục theo quyền, API vẫn kiểm tra độc lập.
- Trang khách hàng đọc `reply/repliedAt` trong `GET /api/v1/reviews` và hiển thị tên người phản hồi là HealthBeauty. Phản hồi chưa tự gửi push/email.

CSDL: chạy `DB_KLCN021/11_ReviewManagement.sql` sau các script trước; chạy lại an toàn. Máy local đã nâng cấp, giữ nguyên toàn bộ dữ liệu cũ và 28 bảng. Xóa mềm vẫn giữ quy tắc một đánh giá/hóa đơn và `hasReviewed`; khách không được đánh giá lại để vượt kiểm duyệt. Đánh giá mới vẫn hiển thị ngay theo hợp đồng trước; có thể ẩn sau khi kiểm tra.

Kiểm chứng: 373 kiểm thử API đạt; 9 kiểm tra SQL độc lập đạt (tạo mới, chạy migration hai lần, truy vấn quản trị, xung đột cập nhật, xóa mềm); CSDL thử đã xóa. Không sửa Web/Flutter; chưa commit/push.
