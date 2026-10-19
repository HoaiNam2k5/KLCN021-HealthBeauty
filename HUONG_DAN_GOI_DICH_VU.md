# GÓI DỊCH VỤ NHIỀU BUỔI — HƯỚNG DẪN WEB/FLUTTER

Ngày 19/10/2026. Backend được tích hợp vào nhánh `feature/huynh-web` để thành viên pull và làm giao diện. Giữ nguyên combo cũ và mã Web/Flutter. Các mục giao diện bên dưới là việc hai thành viên cần tích hợp.

## 1. Phân biệt và ví dụ

- **Combo:** nhóm dịch vụ bán chung cho một lần đặt lịch; tiếp tục dùng API combo hiện có.
- **Gói nhiều buổi:** khách trả tiền mua quyền sử dụng nhiều lần, có hạn dùng và số lượt theo từng dịch vụ.
- Ví dụ gói A giá 2.000.000đ, hạn 90 ngày, gồm chăm sóc da10 lượt và massage5 lượt. Khách dùng chăm sóc da3 lượt, đặt giữ2 lượt nữa thì: được cấp10, đã dùng3, đang giữ2, còn chưa dùng7, khả dụng để đặt mới5.
- `packageId` là ID danh mục gói. **`customerPackageId` là ID phiếu mua/gói của khách**, không phải ID danh mục.

## 2. Vòng đời

1. Admin/Manager/Reception tạo danh mục gói: tên, giá, số ngày hiệu lực, ảnh tùy chọn và số lượt theo dịch vụ.
2. Khách hoặc lễ tân tạo phiếu mua, trạng thái `Pending`. API chụp tên/giá/nội dung/hạn dùng; sửa danh mục sau đó không đổi gói đã mua.
3. Người có `PAYMENT.WRITE` xác nhận đã nhận đủ tiền. API chuyển `Paid`, ghi phương thức/người xác nhận, bắt đầu hạn dùng và cộng `floor(giá gói/10.000)` điểm đúng một lần. Đây là **ghi nhận thanh toán tại cơ sở**, chưa phải tích hợp cổng ngân hàng.
4. Khách đặt lịch, gửi `customerPackageId`. API giữ số lượt tương ứng trước khi trả kết quả đặt thành công.
5. Hủy lịch hợp lệ → trả số lượt đang giữ; không hoàn điểm hoặc hoàn tiền mua gói.
6. Lễ tân chuyển lịch đến `HoanThanh` → chuyển lượt đang giữ sang đã dùng, tạo hóa đơn dịch vụ **0đ, DaThanhToan**. Khách vẫn được đánh giá; không thu tiền/cộng điểm lần hai.
7. Hết hạn → `available=0`; lịch đã đặt đúng hạn có thể được kết thúc nghiệp vụ sau đó. Đổi lịch sang sau hạn bị từ chối.

Đợt đầu chỉ cho lịch **toàn bộ được chi trả bởi một gói**: không trộn combo, dịch vụ ngoài gói hoặc một phần tiền mặt trong cùng lịch. Muốn thêm dịch vụ trả tiền riêng thì đặt lịch riêng. Khách cần thanh toán gói xong mới đặt bằng gói.

## 3. Danh mục gói

Tiền tố API `/api/v1`.

| Method / đường dẫn | Quyền / kết quả |
|---|---|
| `GET /service-packages` | Công khai, chỉ gói đang bật, trả mảng danh mục kèm items |
| `GET /service-packages/{id}` | Công khai, chi tiết gói đang bật; không có/tắt trả404 |
| `GET /service-packages/management` | Admin/Manager/Reception + SERVICE.WRITE; bao gồm gói tắt |
| `POST /service-packages` | SERVICE.WRITE, tạo201 |
| `PUT /service-packages/{id}` | SERVICE.WRITE, cập nhật200; dùng active=false để ngừng bán |

Body tạo/sửa:

```json
{
  "name": "Gói chăm sóc da 10 buổi",
  "price": 2000000,
  "validityDays": 90,
  "active": true,
  "imageUrl": "",
  "items": [{ "serviceId": 1, "sessions": 10 }]
}
```

Tối đa100 dịch vụ, không trùng serviceId; mỗi dịch vụ1–10.000 lượt; giá0,01–1tỷ, tối đa2 chữ số thập phân; hạn1–3650ngày. Upload ảnh qua `/media/images` hiện có rồi gửi `imageUrl`. Bỏ qua/null giữ ảnh cũ khi sửa, chuỗi rỗng bỏ liên kết. Danh mục items có serviceId/sessions; lấy tên dịch vụ từ danh mục `/services` khi cần.

## 4. Mua, thanh toán và xem số lượt

| API | Quyền / chức năng |
|---|---|
| `POST /service-packages/purchases` | Khách mua cho chính mình; quản trị cần CUSTOMER.WRITE và customerId |
| `POST /service-packages/purchases/{id}/pay` | Admin/Manager/Reception + PAYMENT.WRITE; chỉ phiếu Pending |
| `GET /service-packages/mine` | Khách xem gói của mình |
| `GET /service-packages/customers/{customerId}` | Admin/Manager/Reception + CUSTOMER.READ |
| `GET /service-packages/purchases/{id}` | Chủ gói hoặc quản trị có CUSTOMER.READ; trả `{package,history}` |
| `DELETE /service-packages/purchases/{id}` | Chủ gói hoặc quản trị có CUSTOMER.WRITE; chỉ hủy phiếu Pending |

Mua: `{ "packageId": 1 }`; lễ tân thêm `"customerId": 7`. Thành công201 trả ID phiếu và snapshot, trạng thái Pending, available0. Client không gửi giá/lượt/trạng thái để tự cấp gói.
Thanh toán: `{ "method": "TienMat" }`, chấp nhận `TienMat|ChuyenKhoan|The`. Không gửi số tiền do client tính; API lấy giá đã chụp trên phiếu. Thành công200 trả gói Paid. Phiếu đã Paid/Cancelled không trả tiền lần nữa (409).

Một phần response:

```json
{
  "id": 15,
  "servicePackageId": 1,
  "customerId": 7,
  "name": "Gói chăm sóc da 10 buổi",
  "status": "Paid",
  "items": [{ "id": 25, "serviceId": 1, "serviceName": "Chăm sóc da", "granted": 10, "reserved": 2, "used": 3, "remaining": 7, "available": 5 }]
}
```

- `remaining=granted-used`: chưa sử dụng, có bao gồm lượt đã giữ cho lịch hẹn.
- `available=granted-used-reserved`: được đặt mới, nhưng bằng0 nếu chưa thanh toán/hết hạn.
- Kiểm tra `expiresAt` để hiển thị hết hạn; status Paid chỉ nói đã thanh toán, không có nghĩa còn hiệu lực.
- `history` có appointmentId, customerPackageItemId, quantity, status Reserved/Consumed/Released, createdAt/settledAt. Ghép item bằng ID để biết dịch vụ.
- API giữ/trừ lượt bằng concurrency token; client chỉ hiển thị và gọi API, không tự sửa số lượt.

## 5. Đặt lịch dùng gói

Gọi `POST /appointments` như cũ, thêm **customerPackageId** của gói đã Paid:

```json
{
  "appointmentAt": "2026-11-01T09:00:00",
  "items": [{ "serviceId": 1, "comboId": null, "expectedPrice": 0 }],
  "customerPackageId": 15
}
```

Quản trị tạo lịch phải thêm customerId; staffId tùy chọn như luồng cũ. Gửi ngày theo giờ địa phương bằng helper đặt lịch sẵn có, không tự chuyển sang ISO UTC. Mỗi phần tử items dùng1 lượt dịch vụ đó; muốn2 lượt gửi2 phần tử tương ứng. Server tự xác định giá dự kiến0 với lịch dùng gói.
Response lịch hẹn bổ sung `customerPackageId`, `fundingSource="ServicePackage"`; lịch thường trả `fundingSource="Cash"` (nghĩa là thanh toán thông thường, chưa phải phương thức tiền mặt).

- Hủy bằng `DELETE /appointments/{id}` hoặc PATCH status DaHuy đều trả lượt.
- Đổi ngày bằng PUT hoặc POST reschedule đều kiểm tra hạn dùng.
- Chuyển trạng thái vẫn đi đúng chuỗi DaXacNhan → DaDen → DangThucHien → HoanThanh bằng nghiệp vụ hiện có.
- Không gọi tạo hóa đơn thường hoặc thanh toán lần nữa cho lịch dùng gói: API trả409. Hóa đơn0đ được tạo tự động khi hoàn thành.
- Gặp409: tải lại lịch và số lượt; không tự cộng/trừ lượt ở UI. Gặp400: kiểm tra số lượt, hạn, dịch vụ và trạng thái thanh toán. Thiếu quyền403; hết phiên401.

## 6. Giao diện hai thành viên cần làm

**Web:** thêm danh mục gói riêng combo; tạo phiếu mua cho khách; xác nhận thu tiền có quyền PAYMENT.WRITE; tab gói của khách/chi tiết số lượt/lịch sử; chọn gói khi tạo lịch và hiển thị nguồn chi trả; ẩn thao tác thu tiền lần hai. Sau thanh toán/trạng thái lịch, invalidate cache gói/lịch/hóa đơn/điểm khách.
**Flutter:** xem danh mục/chi tiết gói; tạo phiếu mua; xem Pending/Paid/hết hạn và từng số lượt; chọn gói của mình khi đặt lịch; xem lịch sử. Không cho khách tự đánh dấu đã thanh toán hoặc nhập số lượt còn lại.

## 7. Doanh thu và điểm

`GET /service-packages/sales?from=2026-10-01T00:00:00&to=2026-11-01T00:00:00` cần REPORT.READ, trả `{from,to,count,revenue,items}` theo thời điểm xác nhận thanh toán, khoảng `[from,to)`, tối đa366ngày/10.000 phiếu.
Doanh thu gói được ghi một lần ở phiếu mua; báo cáo hóa đơn cũ không tự cộng nguồn này. Web muốn tổng tiền bán hàng cần trình bày riêng/hợp nhất doanh thu gói với hóa đơn dịch vụ có chú thích thời điểm khác nhau. Không lấy giá gói cộng lại ở mỗi lần sử dụng. Hóa đơn lượt dùng0đ có thể tăng số hóa đơn/lượt phục vụ nhưng không tăng doanh thu.
Lịch sử điểm `/customers/{id}/points` và `/customers/me/points` bổ sung customerPackageId để mở phiếu nguồn. Chưa áp voucher/đổi điểm trực tiếp để giảm giá mua gói trong đợt này; chưa có thanh toán từng phần, chuyển gói sang người khác hay hoàn tiền gói đã Paid.

## 8. SQL và kiểm chứng

`DB_KLCN021/13_ServicePackages.sql` thêm5 bảng và khóa liên kết trên lịch hẹn/lịch sử điểm; SQL gốc đã tích hợp một lần. Sau toàn bộ migration, thiết kế có33 bảng nghiệp vụ (28+5); đây chưa phải kết quả đếm database local sau nâng cấp.
**Thành viên chạy các migration còn thiếu đến SQL12, rồi SQL13 trong SSMS trước khi chạy API mới.** Máy anh Nam đã chạy SQL và API thật vượt kiểm tra đọc dữ liệu; chưa kiểm chứng idempotence hoặc luồng ghi/tranh chấp SQL thực. Môi trường agent vẫn bị chặn kết nối SQL trực tiếp.
Không tự đổi dữ liệu cũ, không cấp gói miễn phí cho khách có sẵn. Combo/hóa đơn/lịch thường giữ luồng cũ.

Kiểm chứng cuối: **420/420 test đạt** (403 test cũ +12 unit test gói +5 HTTP test). Luồng HTTP đã đi qua mua/thanh toán/đặt/hủy/đặt lại/hoàn thành/hóa đơn0đ/đánh giá; kiểm tra hết hạn qua cả PUT và reschedule, quyền bị thu hồi, giả giá/trạng thái từ client và không cộng điểm hai lần. Hai DbContext kiểm tra concurrency token gói/số lượt. Swagger trả200, có111 thao tác, trong đó12 thao tác gói, customerPackageId đặt lịch là trường tùy chọn. SQL13 đã sửa kiểm tra Paid bắt buộc có ExpiresAt; chưa chạy SQL Server hoặc kiểm chứng tranh chấp SQL thật do môi trường bị chặn kết nối.

Cập nhật sau khi anh Nam chạy SQL (19/10/2026): API thật tại localhost:5230 đã vượt **14/14 kiểm tra HTTP**, gồm đăng nhập200, danh mục gói200, quản trị gói200, lịch hẹn đọc cột SQL13 trả200, khách mới SQL12 trả200 và doanh thu gói200. Anonymous thanh toán401, ID thiếu404, body danh mục không hợp lệ400, đăng xuất204. Có12 thao tác gói trong Swagger. Bộ test chạy lại **420/420 đạt**. Môi trường agent vẫn không nối SQL trực tiếp được; kiểm chứng qua API anh chạy trong PowerShell thường. Đây là kiểm tra tích hợp đọc SQL và validation/phân quyền, chưa phải kiểm thử tranh chấp hay luồng ghi SQL thực. Không tạo/sửa gói, thanh toán hay lượt dùng trên dữ liệu thật.
