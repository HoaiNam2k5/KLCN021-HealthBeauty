# Review đề xuất trên nhánh mobile app — 26/10/2026

Nhánh được kiểm tra: `origin/feature/mobile-app`, commit `ae12e66` — `feat(mobile): add customer app enhancements`.

Phạm vi: đọc thay đổi của commit mới nhất so với parent, đối chiếu hợp đồng API và app hiện tại trên `main` (`6e95170`), đồng thời giữ nguyên bản sửa local phân loại lịch qua ngày. Chỉ review và ghi note; chưa merge, cherry-pick, sửa tính năng hoặc triển khai. Có đọc các test mới nhưng chưa chạy nhánh này, nên không kết luận tính năng đã chạy đạt trên thiết bị.

## Kết luận và mức ưu tiên

| Nhóm | Đánh giá | Khuyến nghị |
|---|---|---|
| Đổi lịch hẹn | Nên áp dụng, ưu tiên cao | Giữ lịch đủ điều kiện, dịch vụ, nhân viên/ghi chú và liên kết gói; sửa đúng DTO phản hồi và refresh danh sách. Chỉnh các trường hợp dưới đây trước khi tích hợp. |
| Đổi điểm lấy voucher | Nên áp dụng sau khi bổ sung bảo vệ giao dịch | Hiển thị giá đổi, số dư, xác nhận, refresh ví/điểm và lỗi nghiệp vụ là đúng. Cần bảo vệ tài khoản, giá điểm đã xác nhận và thứ tự refresh. |
| Lọc giá dịch vụ | Nên áp dụng, ít phụ thuộc backend | Giữ min/max, xóa lọc, min ≤ max và phối hợp tìm kiếm/danh mục. Không cần cấm min thấp hơn giá rẻ nhất. |
| Hạng thành viên | Nên áp dụng nội dung tham khảo ngay | Bỏ giảm giá, ưu tiên, quà tự động chưa có backend. Không coi hạng tính từ số dư điểm là hạng chính thức nếu chưa chốt chính sách. |

## 1. Đổi lịch hẹn

### Điểm hợp lý

- Chỉ cho đổi lịch ở `ChoXacNhan` hoặc `DaXacNhan`, khớp điều kiện backend; không cho sửa lịch đang thực hiện/đã hoàn thành/đã hủy.
- Giữ dịch vụ và dữ liệu hiện có, chỉ đổi ngày giờ đủ điều kiện.
- API `POST /appointments/{id}/reschedule` đang trả `200` với DTO chi tiết có `lichHenId`, `ngayGioHen`, `chitietlichhens`, khác DTO danh sách `id`, `appointmentAt`, `items`. Factory mới xử lý khác biệt này, đúng nguyên nhân một trường hợp app báo lỗi mặc dù backend đã lưu.
- Cập nhật cache/danh sách sau đổi; có kiểm tra phản hồi cũ khi tài khoản thay đổi.

### Phải chỉnh trước khi tích hợp

1. **Giữ liên kết gói đã mua.** `models/appointment.dart:91–145` trên nhánh review chưa giữ `customerPackageId`. Bản hiện tại có lịch sử dụng gói, nên mapper phải giữ trường này và các metadata hóa đơn/đánh giá. Không được biến lịch dùng gói thành lịch trả tiền riêng trên giao diện sau đổi ngày.
2. **Giới hạn lịch chọn ngày.** `reschedule_screen.dart:45–47` lấy ngày lịch cũ làm ngày focus; dòng 201 giới hạn `lastDay` ở hôm nay +60 ngày. Lịch đã được web/API đặt xa hơn giới hạn có thể làm TableCalendar lỗi assert. Cần clamp ngày focus hoặc cho khoảng chọn phù hợp, và xử lý lịch cũ đã qua ngày.
3. **Phân biệt lỗi parse với timeout thật.** Sửa DTO không giải quyết mọi lỗi mạng sau khi backend ghi thành công. Khi không chắc kết quả, đọc lại lịch và hiển thị trạng thái hiện tại; không hướng khách bấm gửi đổi lịch liên tục.
4. **Giữ quy tắc gói và lịch trống từ server.** Ngày mới phải trong hạn gói, còn phù hợp ca làm việc và không trùng lịch. App chỉ hỗ trợ chọn, không thay thế kiểm tra backend.

Có test mới cho hợp đồng đổi lịch trong `test/booking_contract_test.dart:436–550`; cần bổ sung trường hợp lịch dùng gói, lịch ngoài 60 ngày và lỗi mạng sau lưu.

## 2. Đổi điểm lấy voucher

### Điểm hợp lý

- Danh sách có thể đổi và kết quả đổi khớp DTO của API hiện có:
  - `GET /customers/me/voucher-offers`.
  - `POST /customers/me/vouchers/{id}/redeem`.
- Hiển thị số điểm cần dùng và số dư; xác nhận trước khi đổi; khóa gửi đồng thời.
- Backend tự kiểm tra số dư, hạn/khả dụng và voucher đã được nhận; không tin số dư điểm do app cung cấp.
- Sau thành công tải lại điểm và ví; thông báo rõ thiếu điểm/hết khả dụng là phù hợp.

### Phải chỉnh trước khi tích hợp

1. **Xác nhận gắn với đúng tài khoản.** `offers_screen.dart:82–107` chưa giữ `accountVersion` trước khi mở dialog. Nếu đổi tài khoản trong lúc dialog mở, nút xác nhận có thể gọi provider của tài khoản mới. Cần chụp và kiểm tra phiên trước POST, sau POST và sau refresh.
2. **Giá đổi phải khớp số khách đồng ý.** App chỉ POST voucher ID (`catalog_provider.dart:279–292`), trong khi backend trừ `PointsCost` hiện tại (`VoucherRedemptionController.cs:46–55`). Nếu giá đổi bị quản trị sửa sau khi app hiển thị, khách có thể bị trừ số khác số đã xác nhận. Nên gửi `expectedPointsCost` hoặc version; backend trả conflict và yêu cầu xác nhận lại nếu giá đổi thay đổi. Đây là thay đổi hợp đồng API cần làm cùng app, không chỉ sửa giao diện.
3. **Không để ví cũ ghi đè ví mới.** `loadMyVouchers()` bỏ qua khi đang loading, còn redeem gọi lại hàm này ở dòng 298. Request ví trước lúc đổi có thể trả về muộn, hoặc refresh sau đổi bị bỏ qua. Cần invalidate request cũ/generation và bảo đảm có một lần đọc mới sau giao dịch.
4. **Không tự thử đổi lại khi timeout.** Trước hết tải lại ví và số dư để biết voucher đã được cấp chưa; tránh người dùng hiểu là thất bại và tiếp tục đổi.

Có test DTO, đổi thành công và thiếu điểm tại `test/catalog_contract_test.dart:220–294`; cần thêm test đổi tài khoản khi dialog mở, giá điểm thay đổi và hai request ví trả về trái thứ tự.

## 3. Lọc dịch vụ theo giá

### Nên giữ

- Min/max được áp dụng cùng bộ lọc tên và danh mục; hai đầu khoảng giá tính bao gồm.
- Có nút xóa; kiểm tra min không vượt max; thông báo khi không có kết quả phù hợp.
- Có thể lọc local khi catalog đã được tải đầy đủ, không cần tạo API mới chỉ cho bộ lọc này.

### Nên điều chỉnh yêu cầu giá sàn

`services_screen.dart:317–326` đang từ chối cả min/max thấp hơn giá dịch vụ thấp nhất.

Không cần coi đây là dữ liệu sai: catalog rẻ nhất 100.000đ thì lọc **0–200.000đ** vẫn hợp lý và có kết quả; lọc **0–50.000đ** có thể báo chưa có dịch vụ phù hợp. Giá nhỏ nhất/lớn nhất nên là gợi ý hoặc giới hạn thanh trượt, không phải quy tắc cấm đối với ô nhập.

Khuyến nghị: để trống nghĩa là không giới hạn; giá không âm, hữu hạn, min ≤ max; có nút xóa rõ ràng. Giới hạn độ dài số để tránh nhập giá cực lớn thành Infinity. Nếu catalog được tải theo trang trong tương lai, không lọc trên riêng trang đầu rồi coi là toàn bộ kết quả.

Nhánh hiện chỉ áp dụng giá cho tab dịch vụ. Nếu cần lọc combo, bổ sung chủ động; không làm mất tab gói dịch vụ hiện đã có trên bản mới.

## 4. Hạng thành viên và quyền lợi

### Nên giữ

- Bỏ các cam kết giảm 5%/10%/15%, tích điểm nhân hệ số, phòng VIP, quà sinh nhật hoặc ưu tiên chuyên viên tự động khi backend chưa thực thi.
- Dùng nội dung tham khảo, hiển thị tiến độ và các tính năng thật: điểm, ví voucher, lịch sử điểm.
- Nội dung tĩnh không cần gọi API riêng. Số điểm hiện tại vẫn phải lấy từ dữ liệu tài khoản server, không giảm phụ thuộc API bằng cách tự tính/cất số dư trên app.

### Điểm cần chốt về chính sách

`account_screen.dart:132–133` lấy `customer.rewardPoints` làm đầu vào; `membership_tier.dart:48–52` đặt mốc 100/500/1000. Đây là **số dư điểm có thể tiêu**, không phải tổng điểm tích lũy hoặc doanh thu trọn đời.

Ví dụ khách có 520 điểm được hiển thị Vàng, đổi voucher hết 100 điểm còn 420 thì app hiển thị Bạc. Nếu không chủ đích cho xuống hạng khi tiêu điểm, phải tách **điểm xét hạng** và **điểm khả dụng**. Khi backend chưa có chính sách/dữ liệu hạng chính thức, nên ghi rõ “mốc tham khảo theo điểm hiện có”, không quảng bá như quyền lợi được bảo đảm.

Các câu “có thể nhận quà/voucher theo chương trình” chỉ nên giữ nếu có chương trình thật. Không tự động áp giảm giá dựa vào hạng UI.

## Cách tích hợp đề xuất

1. Lấy nội dung quyền lợi tham khảo và bộ lọc giá, đồng thời chỉnh quy tắc giá sàn.
2. Lấy fix DTO/luồng đổi lịch, bổ sung bảo toàn gói và các trường hợp ngày giới hạn/timeout.
3. Tích hợp đổi voucher sau khi sửa các điều kiện xác nhận tài khoản, giá điểm và refresh ví.

**Không merge hoặc chép đè nguyên nhánh mobile lên main.** Nhánh có ba commit mobile chưa nằm trong lịch sử main theo cùng nhánh, còn app main hiện có QR hóa đơn, thanh toán gói, nút mua gói và bản sửa lịch qua ngày. Cần port các thay đổi cần thiết từ `ae12e66` vào bản hiện tại và chạy lại kiểm thử tích hợp để giữ các tính năng mới.

Ghi nhận này là review source và hợp đồng API; chưa thực hiện các chỉnh sửa được đề xuất, chưa đổi database, chưa push/deploy.
