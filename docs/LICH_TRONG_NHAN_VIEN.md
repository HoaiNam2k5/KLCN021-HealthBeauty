# Chọn nhân viên và ngày còn lịch trống

Đã áp dụng trong API/Flutter tại thư mục dự án chung ngày 24/10/2026. Không cần SQL mới; web tiếp tục tạo ca làm nhân viên như hiện tại.

## Luồng cho khách

1. Chọn dịch vụ/combo rồi tiếp tục sang bước nhân viên và thời gian.
2. Chọn nhân viên cụ thể hoặc **Bất kỳ nhân viên**. App tải ngày còn giờ trong khoảng hôm nay đến 60 ngày sau (61 ngày kể cả hôm nay).
3. Ngày có chấm là ngày có ít nhất một giờ phù hợp; ngày không có giờ bị vô hiệu hóa. App lọc thêm lịch riêng của khách và hiệu lực combo.
4. Bấm **Lịch trống gần nhất** để chuyển thẳng tới ngày phù hợp sớm nhất, rồi chọn giờ. Nút này không tự tạo lịch hẹn hay tự xác nhận giờ.
5. Đổi nhân viên/dịch vụ sẽ tải lại ngày, bỏ giờ đã chọn; phản hồi cũ không ghi đè lựa chọn mới. Có nút **Cập nhật lịch trống** nếu dữ liệu vừa thay đổi.

Không có ca làm thì không có giờ để đặt. Nếu không tìm thấy lịch trong phạm vi trên, app thông báo rõ để khách đổi nhân viên/dịch vụ. Đây là lịch trống tại lúc truy vấn; API vẫn kiểm tra trùng khi đặt thật.

## API mới

```http
GET /api/v1/appointments/availability/days?from=2030-01-01&to=2030-01-31&staffId=2&durationMinutes=90
```

```json
[
  { "date": "2030-01-03", "startTimes": ["09:00:00", "10:30:00"] }
]
```

- `from` và `to` bắt buộc, ngày địa phương `yyyy-MM-dd`; tối đa 61 ngày kể cả hai đầu. `durationMinutes`: 1–1440. Bỏ `staffId` để lấy giờ của bất kỳ nhân viên nào.
- Chỉ trả ngày có giờ, sắp xếp ngày/giờ; giờ trùng giữa nhiều nhân viên được gộp. Không trả thông tin lịch hẹn hay khách hàng.
- Dùng chung quy tắc với API một ngày: không nghỉ phép, đủ toàn bộ thời lượng trong một ca, bước giờ 30 phút, loại giờ đã qua và lịch nhân viên bị trùng, kể cả lịch từ hôm trước kéo dài sang.
- Trả tất cả giờ còn trống thay vì chỉ giờ đầu tiên để Flutter không bỏ mất ngày còn giờ khác sau khi lọc lịch riêng của khách.
- API cũ `GET /appointments/availability` và `/available-slots` giữ nguyên hợp đồng. Khi chọn ngày, Flutter gọi lại API ngày để xem giờ mới nhất.
- Lấy ca/lịch theo lô, không gọi database riêng cho từng ngày. Không thay đổi cách phân công của lựa chọn **Bất kỳ nhân viên**.

## Các file chính

- API: `HealthBeauty.Api/Controllers/SupplementControllers.cs`.
- Flutter: `lib/models/availability_day.dart`, `lib/providers/appointment_provider.dart`, `lib/screens/booking_screen.dart`.
- Kiểm thử: `AvailabilityDaysTests.cs`, HTTP test trong `MobileAuthenticationHttpTests.cs`, Flutter `availability_calendar_test.dart`, kiểm tra độc lập `availability_calendar_contract_check.dart`.

## Luồng test thủ công

1. Trên web tạo ca tương lai cho nhân viên A vào một ngày, nhân viên B vào ngày khác; thời lượng ca đủ dịch vụ.
2. Khởi động lại API bằng `CHAY_API.ps1`; chạy lại Flutter bằng `CHAY_FLUTTER.ps1` tại gốc dự án.
3. Chọn dịch vụ → A: chỉ những ngày A thực sự còn giờ được đánh dấu. Bấm lịch gần nhất, kiểm tra ngày được chọn và danh sách giờ.
4. Chuyển sang B: các dấu ngày cập nhật, giờ cũ bị bỏ. Chọn Bất kỳ: thấy các ngày của cả hai nếu còn giờ.
5. Lấp kín hoặc chuyển ca thành nghỉ phép trên web; bấm Cập nhật lịch trống, ngày đó phải mất dấu/không chọn được.
6. Kiểm tra dịch vụ dài không vừa ca và combo hết hạn: các ngày không phù hợp không có dấu. Khách đã có lịch trùng toàn bộ giờ của ngày thì ngày đó cũng không chọn được.

Google OAuth và SQL14 không liên quan thay đổi này. Các chức năng đặt lịch khác giữ nguyên.

## Kiểm chứng

- Toàn bộ API: **500/500 test đạt**, gồm kiểm tra endpoint mới qua HTTP/Swagger trong database test cô lập.
- Flutter: **50 file lib/test không có diagnostic** qua analysis server trực tiếp; **6/6 kiểm tra độc lập** cho sắp xếp ngày/giờ, giờ trùng khách, ngày combo không hợp lệ và dữ liệu sai.
- Đã thêm 5 test Flutter cho provider/lọc lịch; lệnh `flutter test --no-pub test/availability_calendar_test.dart` bị Windows chặn tạo tiến trình `vswhere.exe` với `CreateFile failed 5`, nên chưa chạy được bộ test này hoặc xác minh giao diện trên emulator. Formatter đã định dạng 5 file nhưng kết thúc lỗi quyền ghi telemetry ngoài workspace; phân tích mã sau định dạng vẫn sạch.
- Reviewer chỉ đọc không phát hiện lỗi cụ thể. Chưa push; không có SQL mới.
