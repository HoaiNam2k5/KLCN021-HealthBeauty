# Chuyển khoản SePay và lịch sử hóa đơn trên app

Tích hợp này dùng **SePay Webhooks giao dịch ngân hàng**, không dùng API cổng thanh toán/IPN của SePay. Mặc định tắt vì chưa có tài khoản SePay/ngân hàng liên kết. Không có tài khoản hay khóa bí mật mẫu hoạt động trong mã nguồn.

## Luồng nghiệp vụ

1. Lễ tân hoàn thành lịch hẹn và lập hóa đơn như hiện tại trên web. Chưa hỗ trợ thu cọc hoặc thanh toán gói dịch vụ qua luồng này.
2. Khách xem hóa đơn của mình trong app, bấm thanh toán chuyển khoản. Server trả thông tin ngân hàng đã cấu hình, số tiền phải trả và mã riêng `HB<invoiceId>`.
3. Khách chuyển đúng số tiền, giữ nguyên nội dung. QR chỉ điền sẵn thông tin; mở QR hoặc bấm kiểm tra không đồng nghĩa đã thanh toán.
4. SePay gửi giao dịch đến webhook. Server xác thực API key, tài khoản, ngân hàng, chiều tiền vào, mã hóa đơn và số tiền nguyên VND chính xác.
5. Giao dịch khớp được lưu cùng trạng thái hóa đơn, điểm thưởng và thông báo trong một transaction EF/SQL. App kiểm tra lại trạng thái từ server. Khách xem chi tiết/lịch sử hóa đơn, không tự xác nhận đã thu tiền.
6. Chức năng xuất/in hóa đơn của web giữ nguyên.

## Cấu hình để kích hoạt

Chưa cần cấu hình để chạy lịch sử hóa đơn. Khi chưa bật SePay, yêu cầu QR trả HTTP 503 với thông báo liên hệ lễ tân; không trả ngân hàng giả.

1. Tạo tài khoản tại https://my.sepay.vn và liên kết tài khoản ngân hàng nhận tiền. Chọn ngân hàng được SePay hỗ trợ. Dùng môi trường thử nghiệm riêng trước khi bật giao dịch thật.
2. Sao lưu DB và áp dụng `DB_KLCN021/16_BankTransfers.sql` vào đúng database mà container API đang kết nối (tên database trong `ConnectionStrings__DefaultConnection`, hoặc cấu hình tương ứng hiện có). Chọn database trong SSMS hoặc dùng `sqlcmd -d`; script không tự đổi database bằng `USE`. Script in tên database và ID bảng sau khi hoàn tất. Nếu tên database triển khai khác tên mặc định trong script cũ, cần chạy bản sửa này trên đúng database API. Script kiểm tra `RowVersion` của hóa đơn và khách hàng; nếu thiếu cần áp dụng migrations 06/09 trước. Script không được tự chạy khi app khởi động. Không bật SePay khi migration chưa được áp dụng.

   Bản SQL16 hiện kiểm tra đầy đủ 11 cột ledger, PK/FK/index và 46 cột phụ thuộc của luồng thanh toán; dừng nếu schema không tương thích, không tự sửa dữ liệu cũ. Với SQL Server Docker trên AWS, dùng hướng dẫn [SEPAY_AWS_SCHEMA_REPAIR.md](SEPAY_AWS_SCHEMA_REPAIR.md), script `apply-bank-transfers-aws.sh` và `16_VerifyBankTransfers.sql`. Việc publish API không tự áp dụng SQL16 vào AWS.
3. Cấu hình trên server bằng biến môi trường hoặc kho secrets. Các trường ngân hàng phải trùng tài khoản đã liên kết:

| Biến | Giá trị cần cung cấp |
| --- | --- |
| `Payments__SePay__Enabled` | `true` sau khi cấu hình và thử xong |
| `Payments__SePay__BankName` | Tên `gateway` chính xác SePay gửi, ví dụ tên ngân hàng, không phải tên chủ tài khoản |
| `Payments__SePay__BankCode` | Mã ngân hàng được dịch vụ QR SePay chấp nhận; có thể khác tên `gateway` |
| `Payments__SePay__AccountNumber` | Số tài khoản nhận tiền đã liên kết, giữ nguyên số 0 đầu |
| `Payments__SePay__AccountName` | Tên chủ tài khoản để khách đối chiếu |
| `Payments__SePay__WebhookApiKey` | Khóa ngẫu nhiên riêng dài 32–256 ký tự, không có khoảng trắng |

Không đặt WebhookApiKey vào Flutter, web frontend, Git, URL hoặc log. Khóa này dùng cho webhook do anh cấu hình, không phải token gọi API quản trị SePay.

4. Tạo webhook trong SePay: sự kiện **Có tiền vào**, chọn đúng tài khoản, xác thực **API Key** và nhập cùng khóa bí mật. Nếu cấu hình bộ lọc/mã thanh toán, dùng tiền tố `HB`. Không chọn OAuth/HMAC hoặc không xác thực cho endpoint hiện tại.
5. URL webhook của API triển khai hiện tại: `https://healthbeauty.duckdns.org/api/v1/payments/sepay/webhook`. URL phải đi tới API mới triển khai, cho phép POST công khai và giữ header `Authorization: Apikey <khóa>` qua reverse proxy; đây là xác thực riêng, không cần JWT khách hàng.
6. Triển khai API và Mobile cùng phiên bản. API cũ chưa có endpoint tạo QR/chi tiết sẽ trả 404; sửa Flutter đơn lẻ chưa kích hoạt được thanh toán.
7. Dùng giao dịch thử trong môi trường tách biệt, đối chiếu trạng thái và số tiền. Sau đó kiểm tra giao dịch thật có kiểm soát trước khi cho khách dùng.

## API

- `GET /api/v1/invoices?offset=0&limit=50`: JWT; giữ response mảng cũ; mặc định limit 100, giới hạn 1–100; offset >= 0. Khách chỉ thấy hóa đơn thuộc tài khoản; nhân viên cần `INVOICE.READ`. Sắp xếp ngày lập giảm dần rồi ID giảm dần.
- `GET /api/v1/invoices/{id}`: JWT; chi tiết theo DTO hóa đơn hiện có, khách không đọc được hóa đơn người khác (404).
- `POST /api/v1/invoices/{id}/bank-transfer`: JWT; không nhận số tiền/tài khoản do client gửi. Trả `{invoiceId, amount, status, bankName, bankCode, accountNumber, accountName, transferContent, qrImageUrl}`. 404 nếu không thuộc khách; 409 nếu đã trả, tổng bằng 0/âm/lẻ VND hoặc trạng thái không hợp lệ; 503 nếu chưa cấu hình.
- `POST /api/v1/payments/sepay/webhook`: API key SePay; body giao dịch theo tài liệu chính thức. Trả 200 `{success:true}` cho giao dịch đã xử lý hoặc đã lưu để đối soát. Trả 401 nếu sai key, 503 nếu tắt/chưa cấu hình, 400 nếu payload không hợp lệ, 409 nếu có xung đột cần SePay thử lại.

Ảnh QR dùng HTTPS `https://vietqr.app/img` theo tài liệu SePay. Ngân hàng, tài khoản, số tiền và nội dung được gửi cho dịch vụ tạo ảnh QR; không kèm JWT, khóa bí mật hay thông tin khách hàng.

## Đối soát và chống trùng

`dbo.SePayTransaction.Id` là khóa giao dịch SePay duy nhất. Chỉ một ledger `Paid` được phép cho mỗi hóa đơn. Invoice/Customer `RowVersion` bảo vệ cả thanh toán tay và webhook; khi xung đột, toàn bộ lần lưu bị rollback và webhook trả thất bại để thử lại. Không cộng điểm hay gửi thông báo ngoài transaction.

Các Outcome không tự ghi nhận đã thanh toán: `NotIncoming`, `WrongDestination`, `UnmatchedReference`, `UnknownInvoice`, `InvoiceNotPayable`, `TransactionBeforeInvoice`, `AmountMismatch`, `AlreadyPaid`. Giữ lại giao dịch để lễ tân/quản trị đối chiếu. Chuyển thiếu/thừa, sai nội dung hoặc chuyển lần hai phải được xử lý thủ công; chưa có màn hình đối soát/hoàn tiền mới trong lần tích hợp này. Không tự chuyển giao dịch thừa sang hóa đơn khác.

Ví dụ truy vấn chỉ đọc để đối soát trên DB quản trị:

```sql
SELECT Id, InvoiceId, Amount, Gateway, AccountNumber, Content, ReferenceCode, Outcome, ReceivedAt, TransactionAt
FROM dbo.SePayTransaction
WHERE Outcome <> 'Paid'
ORDER BY ReceivedAt DESC;
```

Giao dịch webhook lặp với cùng ID được trả thành công mà không xử lý lần hai. Mã `HB1` chỉ khớp tham chiếu độc lập, không khớp một phần `HB10`/`XHB1Z`; nhiều mã khác nhau hoặc `code` mâu thuẫn nội dung không được tự thanh toán. Thời gian giao dịch lưu theo chuỗi giờ Việt Nam SePay cung cấp; `ReceivedAt` lưu UTC. Chặn giao dịch có trước thời điểm lập hóa đơn: quy đổi giờ SePay với offset +07:00, giờ lập hóa đơn theo múi giờ server (phù hợp DateTime.Now hiện có), so sánh tới giây và dung sai một giây vì SQL datetime2(0) làm tròn giờ lập còn SePay không cung cấp mili giây. Không đổi múi giờ server khi dùng các hóa đơn legacy chưa có offset.

## Kiểm tra trước khi mở thật

- Sai/mất API key không thay đổi DB.
- Tiền ra, sai ngân hàng/tài khoản, thiếu/thừa tiền, sai/mơ hồ mã không làm hóa đơn thành đã trả.
- Gửi lặp cùng ID hoặc giao dịch thứ hai cho hóa đơn đã trả không tăng điểm lần hai.
- Khách A không đọc hay tạo QR cho hóa đơn khách B.
- Tắt/mất mạng rồi mở lại app vẫn lấy hóa đơn từ server.
- Kiểm tra concurrency trên SQL Server môi trường thử: webhook cùng lúc, webhook với thao tác thu tiền ở web. Unit tests dùng EF InMemory và mô phỏng concurrency, không thay thế kiểm tra transaction thực tế trên SQL Server.

## Tài liệu chính thức

- https://docs.sepay.vn/tich-hop-webhooks.html (payload, `Authorization: Apikey`, `{success:true}`, khóa giao dịch duy nhất)
- https://developer.sepay.vn/vi/tien-ich-khac/tao-qr-code (dịch vụ tạo ảnh VietQR)

Chưa xác minh giao dịch SePay thật hoặc áp dụng migration/triển khai vào API công khai trong tác vụ viết code này.
