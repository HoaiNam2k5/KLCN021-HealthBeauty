# Thanh toán gói, dịch vụ và combo

| Trường hợp | Luồng thanh toán |
|---|---|
| Mua gói dịch vụ trả trước | Khách tạo yêu cầu mua trên app, mở QR chuyển khoản. Gói chỉ được kích hoạt khi backend xác nhận tiền hoặc người có quyền ghi nhận khoản thu thực tế. |
| Dịch vụ hoặc combo tại cửa hàng | Hoàn thành lịch tạo hóa đơn chờ thanh toán. Lễ tân bấm **Thu tiền** để mở QR lớn cho khách quét bằng ứng dụng ngân hàng. Khách vẫn có thể thanh toán hóa đơn trong app. |
| Đặt lịch bằng gói đã mua | Chỉ gói đã thanh toán, còn hạn và đủ lượt được sử dụng. Đặt lịch giữ lượt; hoàn thành tiêu thụ lượt, hủy hợp lệ hoàn lượt giữ. Hóa đơn sử dụng gói bằng 0, không thu thêm. |

## Mua gói trên app

1. Khách chọn gói và gửi yêu cầu mua. Trạng thái ban đầu là `Pending`; chưa được đặt lịch bằng gói này.
2. Trong chi tiết gói chờ thanh toán, chọn chuyển khoản để lấy hướng dẫn từ API.
3. QR chứa tài khoản ngân hàng đã cấu hình, đúng giá gói và mã `HP{purchaseId}`. App không tự gán trạng thái đã thanh toán.
4. Backend xác thực webhook SePay, ngân hàng/tài khoản nhận, tiền vào, số tiền, thời gian và mã mua gói. Một lần lưu bao gồm kích hoạt gói, hạn sử dụng, điểm và thông báo riêng cho khách, cùng giao dịch đối soát.
5. App kiểm tra trạng thái mỗi 5 giây khi màn hình thanh toán đang ở foreground, giới hạn mỗi đợt 5 phút. Có nút kiểm tra lại và tự tải khi quay lại app. Khi nhận `Paid`, QR biến mất và gói có thể dùng để đặt lịch.

API: `POST /api/v1/service-packages/purchases/{id}/bank-transfer`. Khách chỉ được lấy hướng dẫn cho gói của mình. Phản hồi gồm `purchaseId`, `amount`, `status`, thông tin ngân hàng, `transferContent`, `qrImageUrl`.

## Thu tiền dịch vụ/combo tại quầy

1. Lễ tân hoàn thành dịch vụ và xem hóa đơn.
2. Bấm **Thu tiền** tại lịch hẹn hoặc danh sách/chi tiết hóa đơn. Màn hình hiển thị tên khách, dịch vụ, tổng tiền, QR, tài khoản và nội dung `HB{invoiceId}`.
3. Khách mở ứng dụng ngân hàng trên điện thoại để quét QR từ màn hình cửa hàng. Không bắt buộc mở app HealthBeauty.
4. Web kiểm tra hóa đơn mỗi 5 giây khi đang hiển thị và khi trở lại cửa sổ. Chỉ khi backend báo đã thanh toán mới hiện thành công và nút in hóa đơn.
5. **Để thanh toán sau** chỉ đóng màn hình thu tiền; hóa đơn vẫn chờ và còn trong app. **Thu tiền mặt / thẻ** mở phần ghi nhận theo quyền `PAYMENT.WRITE`, có kiểm tra lại trạng thái trước khi gửi.

Không dùng nút ghi nhận chuyển khoản thủ công trong luồng thu tiền thông thường trên web. Không dựa vào ảnh chụp chuyển khoản để tự đánh dấu thành công. Nếu hóa đơn thay đổi số tiền, đã thanh toán, bị hủy hoặc lỗi đồng bộ, web không giữ QR cũ để tiếp tục thu tiền.

## Đối soát và triển khai

- `HB…` dành cho hóa đơn và `HP…` dành cho mua gói. Một nội dung có nhiều mã hoặc trộn hai loại sẽ không được tự đối soát.
- Dùng lại bảng `SePayTransaction` hiện có. Giao dịch mua gói giữ mã `HP…` trong `Content`, `InvoiceId` để trống, `Outcome=PackagePaid`; không áp dụng index thanh toán hóa đơn cho mua gói.
- Giữ nguyên ràng buộc gói đã thanh toán phải có tài khoản người thanh toán: chuyển khoản tự động ghi tài khoản chủ gói, thu thủ công ghi tài khoản nhân viên thực hiện. Gói của khách chưa có tài khoản chỉ thu qua nhân viên, không cấp QR tự động có thể bị kẹt kích hoạt.
- Khóa giao dịch SePay chống xử lý lặp. Version của gói và rowversion khách hàng bảo vệ việc thanh toán đồng thời; toàn bộ thay đổi và thông báo được lưu cùng nhau.
- Không có thay đổi schema, không cần chạy SQL mới hay đổi JWT/database/khóa SePay. Cần cập nhật API, web và app cùng đợt để sử dụng đầy đủ luồng mới.
- Nếu webhook trên dashboard đang có bộ lọc chỉ cho mã `HB…`, phải rà soát để giao dịch mua gói `HP…` cũng được chuyển đến endpoint hiện tại. Không cần tạo endpoint webhook thứ hai; không đưa khóa lên app/web.
- Kiểm thử local không thay thế việc kiểm tra webhook thực tế sau triển khai. Không tự tạo giao dịch giả hoặc thay đổi khoản thu production để smoke test.

## Kiểm tra nghiệm thu

- Mua gói: trước thanh toán không đặt lịch được; sai tiền/sai tài khoản không kích hoạt; đúng giao dịch kích hoạt một lần, gửi lại webhook không cộng điểm lần hai.
- Quầy: mở hóa đơn đúng khách, QR đúng số tiền/mã; thanh toán xong web bỏ QR và app thấy hóa đơn đã trả. Không ghi nhận thêm bằng tiền mặt cho hóa đơn đã được SePay thanh toán.
- Gói đã mua: đặt lịch giữ lượt; hoàn thành trừ đúng lượt và tạo hóa đơn 0; không sinh QR thu tiền dịch vụ lần nữa.
