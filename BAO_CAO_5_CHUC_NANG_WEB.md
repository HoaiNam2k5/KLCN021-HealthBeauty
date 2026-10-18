# Đối chiếu 5 chức năng — gửi thành viên Web

Web kiểm tra: `feature/huynh-web` (`a6134da`). Backend bổ sung ở nhánh `feature/api-service-media-reminders`; chưa commit/push.

| Chức năng | Web hiện tại | API/CSDL |
| --- | --- | --- |
| Ảnh minh họa dịch vụ/combo | Có ảnh và ô URL, nhưng chỉ lưu localStorage; chưa upload/đồng bộ | Đã bổ sung `imageUrl` dùng chung và upload Cloudinary; cần cấu hình khóa server |
| Gói/combo dịch vụ | Có thêm, sửa, ngừng dùng, chọn dịch vụ thành phần/số lượng | Đã có; áp dụng cho combo gồm nhiều dịch vụ |
| Tìm kiếm, lọc, danh sách dịch vụ | Đã có tìm tên, lọc loại, bảng danh sách | Đã có `keyword`, `categoryId` |
| Xác nhận/thay đổi/nhắc lịch | Thao tác lịch đã gọi API; không cần Web tự gửi thông báo lần nữa | Đã có xác nhận/đổi/hủy; bổ sung nhắc tự động trước 60 phút. Push thật cần Firebase |
| Cộng/trừ điểm, đổi voucher | Đã nhập voucher/điểm đổi và cập nhật số dư; chưa có cấu hình voucher đổi điểm/lịch sử điểm | Bổ sung `pointsCost`, đổi voucher và lịch sử điểm, chống trừ/cộng trùng đồng thời |

## Việc Web cần làm

1. **Ảnh:** thêm chọn file PNG/JPG/WebP ≤5MB → `POST /api/v1/media/images` bằng FormData, trường `file` → lấy `imageUrl` gửi cùng POST/PUT dịch vụ hoặc combo. Đọc ảnh từ API, bỏ lưu localStorage. Không tự đặt `Content-Type` JSON cho FormData. Xóa ảnh: gửi `imageUrl: ""`; bỏ trường/null khi sửa để giữ ảnh cũ.
2. **Voucher:** thêm ô `pointsCost` (0–1.000.000) vào form tạo/sửa voucher. `0` = voucher tặng/khuyến mãi; `>0` = cần đổi điểm, tạo với `customerId: null`. Mỗi mã là một voucher đổi một lần; tạo nhiều mã nếu cần nhiều suất. Không gán thẳng voucher đổi điểm cho khách để bỏ qua trừ điểm.
3. **Điểm:** thêm tab lịch sử trong hồ sơ khách, gọi `GET /api/v1/customers/{id}/points?page=1&pageSize=20` (quyền `CUSTOMER.READ`); hiện điểm tăng/giảm, loại, ngày, hóa đơn/voucher liên quan. Response có `diemThuong`, `transactions`, `totalCount`.
4. **Phân biệt nghiệp vụ:** thanh toán cộng `floor(số tiền thực trả/10.000)` điểm; đổi voucher trừ `pointsCost` một lần. Dùng voucher đã đổi không trừ điểm lần nữa. `pointsToRedeem` trên hóa đơn là đổi điểm trực tiếp giảm tiền (1 điểm = 1đ), đang trừ khi lập hóa đơn; giữ riêng với đổi voucher.
5. **Lỗi:** gặp 409 do điểm/voucher/hóa đơn thay đổi thì tải lại dữ liệu, không tự gửi lặp. Thông báo lịch do backend xử lý; cần cấu hình Firebase để kiểm tra gửi đến điện thoại.

API dành cho khách/Flutter: `GET /api/v1/customers/me/voucher-offers` và `POST /api/v1/customers/me/vouchers/{id}/redeem` (không body). Web quản trị chỉ cấu hình voucher; không dùng hai API này để đổi hộ khách.

Database máy thành viên: sau 04–06 chạy thêm **07 → 08 → 09 → 10**. Chi tiết backend/cấu hình tại `HealthBeauty.Api/REVIEWS.md`. Không sửa mã nguồn Web trong đợt này.

Phạm vi ảnh hiện tại là ảnh đại diện dịch vụ/combo, chưa phải album nhiều ảnh hay module sản phẩm/avatar người dùng. Gói liệu trình nhiều buổi có số dư lượt dùng cũng chưa thuộc module combo hiện tại.
