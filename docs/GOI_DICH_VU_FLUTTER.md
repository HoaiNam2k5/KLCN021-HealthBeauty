# Gói dịch vụ trên Flutter

Đã tích hợp vào `HealthBeauty.Mobile` trong thư mục dự án chung. Dùng API/SQL13 gói dịch vụ đã có, không thêm bảng hoặc migration mới, không sửa web/API trong đợt này. Chưa commit/push.

## Khách sử dụng ở đâu?

- **Dịch vụ → Gói dịch vụ**: xem/tìm kiếm gói đang bán, ảnh, giá, thời hạn và số lượt theo dịch vụ.
- **Tài khoản → Gói dịch vụ của tôi**: xem các đăng ký, trạng thái, số lượt còn lại và lịch sử.
- **Đặt lịch → Dùng gói dịch vụ đã mua**: chọn gói đã thanh toán và còn lượt; hoặc mở chi tiết gói rồi bấm **Đặt lịch sử dụng gói**.

## Mua và xác nhận thanh toán

1. Khách chọn gói, xem giá/quyền lợi và xác nhận đăng ký mua. Nếu chưa đăng nhập, app yêu cầu đăng nhập khách hàng.
2. App chỉ gửi `packageId`; API xác định chủ sở hữu, giá và số lượt. Đăng ký mới ở trạng thái **Chờ thanh toán**.
3. Khách liên hệ Spa thanh toán. Quản trị xác nhận **Thu tiền** trên web; Flutter không gọi API xác nhận thanh toán và không tự đổi gói thành đã trả tiền.
4. Khách kéo tải lại **Gói của tôi** hoặc chi tiết gói để nhận trạng thái **Đã thanh toán**, ngày hết hạn và lượt có thể sử dụng. Thời hạn bắt đầu từ lúc quản trị xác nhận thanh toán.
5. Đăng ký chưa thanh toán có thể hủy trên app sau xác nhận. Gói đã thanh toán không có nút tự hoàn tiền/hủy mua.

App không tạo số tài khoản/QR chuyển tiền giả. Nếu mạng lỗi sau đăng ký, thông báo yêu cầu kiểm tra Gói của tôi trước khi thử lại để tránh tạo đăng ký trùng.

## Lượt được tính thế nào?

- **Được cấp**: tổng số lượt mua của từng dịch vụ.
- **Đã dùng**: số lượt của các lịch đã hoàn thành.
- **Đang giữ**: số lượt dành cho lịch chưa hoàn thành.
- **Còn lại** = được cấp − đã dùng.
- **Có thể đặt**: số lượt API cho phép đặt ngay, đã trừ lượt đang giữ; gói chưa thanh toán/hết hạn có thể đặt0 dù còn lại vẫn lớn hơn0.

Ví dụ gói5lượt: đặt1lượt thì đang giữ1, còn lại5, có thể đặt4. Hủy lịch được phép thì đang giữ0, có thể đặt5. Hoàn thành lịch thì đã dùng1, còn lại4, có thể đặt4. App hiển thị số dư server, không tự cộng/trừ thay API.

Chi tiết gói hiển thị lịch sử **Đang giữ/Đã sử dụng/Đã trả lượt**, số lượng và lịch hẹn liên quan. Tên/quyền lợi của gói đã mua là snapshot từ API, không lấy giá/quyền lợi hiện tại của danh mục để thay thế.

## Đặt lịch bằng gói

1. Chọn gói hợp lệ, chọn dịch vụ thuộc gói và số lượt lần hẹn. Chỉ những dịch vụ hiện còn trong danh mục hoạt động và đủ lượt mới đặt được.
2. Không trộn combo, dịch vụ ngoài gói hoặc voucher/thanh toán riêng trong cùng lịch dùng gói. Có thể đổi về đặt dịch vụ thông thường nếu muốn dùng luồng cũ.
3. Chọn nhân viên và ngày/giờ như hiện tại; ngày/giờ sau hạn dùng gói bị loại. Toàn bộ số lượt chọn được tính vào thời lượng lịch.
4. Xác nhận hiển thị gói, các dịch vụ/số lượt và tiền dịch vụ0 vì đã thanh toán theo gói.
5. Trước khi gửi, app lấy lại chi tiết/số dư và kiểm tra lựa chọn; gửi `customerPackageId` cùng các dòng dịch vụ thông thường, mỗi lượt một dòng, `comboId=null`.
6. API kiểm tra sở hữu/hạn dùng/số dư/tranh chấp và giữ lượt. Đặt thành công hoặc hủy lịch từ app sẽ xóa cache số dư và tải lại gói của tôi. Chi tiết gói cũng tải mới mỗi khi mở.

Đổi tài khoản vô hiệu hóa dữ liệu riêng và request cũ; thao tác đăng ký/hủy gắn với phiên đăng nhập trước khi gửi, không gửi lại dưới tài khoản mới sau refresh token.

## Endpoint dùng

| Chức năng | API |
| --- | --- |
| Gói đang bán | GET `/api/v1/service-packages` |
| Gói của tôi | GET `/api/v1/service-packages/mine` |
| Chi tiết/số dư/lịch sử | GET `/api/v1/service-packages/purchases/{id}` |
| Đăng ký mua | POST `/api/v1/service-packages/purchases` với `{ "packageId": ... }` |
| Hủy đăng ký Pending | DELETE `/api/v1/service-packages/purchases/{id}` |
| Đặt lịch dùng lượt | POST `/api/v1/appointments`, thêm `customerPackageId` |

`/purchases/{id}/pay` dành cho quản trị, app khách không gọi.

## Kiểm tra và chạy thử

- Phân tích trực tiếp **66 file Dart lib/test: không diagnostic**.
- **25/25 kiểm tra độc lập đạt**:12model/contract gói và13quy tắc đặt lịch dùng lượt.
- Thêm10test Flutter cho provider/payload/generation/booking; lệnh Flutter test bị môi trường chặn tạo `vswhere.exe` (`CreateFile failed5`), nên chưa chạy bộ này hoặc kiểm chứng giao diện trên emulator.
- Rà soát chỉ đọc không phát hiện lỗi cụ thể trong phần tích hợp. Không ghi dữ liệu mua/thanh toán/lượt dùng thật trong quá trình kiểm tra. Lần probe API cổng5230 không kết nối được vì API không chạy tại thời điểm kiểm tra.

Mở API trước. Dừng Flutter rồi chạy lại `CHAY_FLUTTER.ps1` ở gốc dự án để khởi tạo provider mới; chỉ hot reload có thể chưa chạy lại `main()`.

Luồng test nhóm:

1. Web tạo gói đang bán gồm5lượt dịch vụA và tạo ca làm đủ thời lượng cho nhân viên.
2. Flutter đăng nhập khách → Dịch vụ/Gói dịch vụ → đăng ký mua. Kiểm tra Pending và không có nút dùng gói.
3. Web xác nhận thu tiền → Flutter kéo tải lại → thấy Paid/hạn dùng/số lượt.
4. Dùng1lượt A đặt lịch → kiểm tra đang giữ1/có thể đặt4. Hủy lịch → kiểm tra trả lượt5.
5. Đặt lại, web hoàn thành lịch → Flutter mở chi tiết gói thấy đã dùng1/còn lại4 và lịch sử. Không thu tiền/cộng điểm thêm khi dùng lượt.
6. Kiểm tra gói hết hạn, toàn bộ lượt đang giữ, hết lượt, dịch vụ bị tắt, mạng lỗi và đăng xuất/đổi tài khoản trong lúc tải.
