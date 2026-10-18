# Hướng dẫn tích hợp API mới cho Web và Flutter — HealthBeauty

> Cập nhật bàn giao 18/10/2026: backend đã tích hợp vào nhánh `feature/huynh-web`. Thành viên Web đọc `BAO_CAO_TONG_HOP_CHO_WEB.md`, chạy các migration còn thiếu đến **SQL12**. SQL12 chưa áp dụng local do SSPI; các đoạn hướng dẫn nhánh cũ bên dưới ghi nhận đợt bàn giao trước.

Cập nhật ngày 17/10/2026. Tài liệu tổng hợp các thay đổi backend vừa thực hiện: đánh giá dịch vụ, thông tin hóa đơn/đánh giá trong lịch hẹn, quên mật khẩu qua OTP email và hệ thống thông báo.

Backend đã triển khai; hai thành viên phụ trách Web và Flutter thực hiện phần giao diện theo hợp đồng bên dưới. Bản backend tích hợp nằm trên nhánh `feature/healthbeauty-web-mobile-ready`; mã nguồn Web/Flutter được giữ nguyên trong đợt cập nhật backend này. Hai thành viên pull nhánh này, cập nhật database theo các script 04 → 05 → 06 rồi tích hợp giao diện.

## 1. Quy ước chung

- Địa chỉ API khi chạy trên máy: `http://localhost:5230/api/v1`.
- Swagger: `http://localhost:5230/swagger`.
- Flutter chạy trên Android Emulator dùng `http://10.0.2.2:5230/api/v1`; điện thoại thật dùng IP LAN của máy chạy API và cần truy cập được cổng 5230.
- Gửi JSON với `Content-Type: application/json`; tên thuộc tính dùng camelCase.
- Endpoint yêu cầu đăng nhập: thêm `Authorization: Bearer <accessToken>`.
- Các ví dụ dùng ID và thông tin minh họa, cần thay bằng dữ liệu thực tế.

| Nhóm thay đổi | Endpoint | Thành viên cần chú ý |
| --- | --- | --- |
| Danh sách đánh giá và thống kê | `GET /reviews?serviceId={id}` | Web/Flutter đang đọc đánh giá |
| Đánh giá hóa đơn | `POST /reviews/invoices/{invoiceId}` | Flutter; Web nếu có chức năng này |
| Đánh giá trực tiếp từ lịch hẹn, mới bổ sung | `POST /reviews/appointments/{appointmentId}` | Flutter có thể dùng thay cho gửi invoiceId |
| Thông tin hóa đơn và đánh giá trong lịch hẹn | `GET /appointments` | Web và Flutter |
| Ẩn/hiện đánh giá | `PATCH /reviews/{id}/moderation?visible=false` | Web quản trị |
| Yêu cầu mã OTP | `POST /auth/forgot-password` | Web và Flutter |
| Đặt lại mật khẩu | `POST /auth/reset-password` | Web và Flutter |

Đường dẫn trong bảng đều nối sau `/api/v1`.

## 2. Danh sách đánh giá và thống kê sao

### GET /api/v1/reviews?serviceId=1

API công khai, không cần token. `serviceId` là tùy chọn; nếu truyền phải là số nguyên dương. Bỏ `serviceId` để lấy đánh giá công khai của tất cả dịch vụ.

**Thay đổi cần sửa ở frontend:** response trước đây là mảng; hiện tại là đối tượng chứa `averageRating`, `totalReviews` và `items`. Danh sách nhận xét phải đọc từ `response.items` (hoặc `response.data.items` nếu thư viện HTTP của frontend bọc dữ liệu trong `data`).

Ví dụ HTTP 200:

```json
{
  "averageRating": 4.8,
  "totalReviews": 250,
  "items": [
    {
      "danhGiaId": 1,
      "hoaDonId": 2,
      "soSao": 5,
      "binhLuan": "Dịch vụ tốt, nhân viên nhiệt tình.",
      "ngayDanhGia": "2026-10-17T10:00:00",
      "tenKhachHang": "Nguyễn Văn A"
    }
  ]
}
```

- `tenKhachHang`: tên khách gắn với hóa đơn; không bổ sung email, số điện thoại hay thông tin tài khoản.
- Chỉ đánh giá có `trangThai = HienThi` được trả về và tính thống kê.
- Lọc dịch vụ xét cả dịch vụ lẻ và dịch vụ nằm trong combo đã lập hóa đơn.
- `totalReviews` và `averageRating` tính trên toàn bộ đánh giá phù hợp; điểm trung bình làm tròn một chữ số thập phân.
- `items` tối đa 200 đánh giá gần nhất, sắp xếp ngày đánh giá giảm dần rồi ID giảm dần. Vì vậy `items.length` có thể nhỏ hơn `totalReviews`.
- Khi chưa có đánh giá: `averageRating = 0`, `totalReviews = 0`, `items = []`. Giao diện nên hiện “Chưa có đánh giá”.
- API này hiện không hỗ trợ lọc `rating` hoặc phân trang `page/size`.
- `serviceId` không hợp lệ nhận 400; ID hợp lệ nhưng không có đánh giá nhận 200 với danh sách rỗng.

## 3. Gửi đánh giá theo hóa đơn

### POST /api/v1/reviews/invoices/{invoiceId}

Cần đăng nhập bằng tài khoản có hồ sơ khách hàng và sở hữu hóa đơn. Hóa đơn phải có trạng thái `DaThanhToan`.

Body:

```json
{
  "stars": 5,
  "comment": "Dịch vụ tốt, nhân viên nhiệt tình."
}
```

- `stars`: số nguyên từ 1 đến 5.
- `comment`: không bắt buộc, tối đa 1000 ký tự; backend bỏ khoảng trắng đầu/cuối khi lưu.
- Tên trường gửi lên là `stars`, `comment`; tên trường nhận về là `soSao`, `binhLuan`.

Ví dụ HTTP 201:

```json
{
  "danhGiaId": 1,
  "hoaDonId": 2,
  "soSao": 5,
  "binhLuan": "Dịch vụ tốt, nhân viên nhiệt tình.",
  "trangThai": "HienThi",
  "ngayDanhGia": "2026-10-17T10:00:00"
}
```

Đánh giá mới hiển thị ngay, không cần chờ duyệt. Những đánh giá cũ đang `ChoDuyet` vẫn giữ trạng thái cũ. Mỗi hóa đơn chỉ có một đánh giá, kể cả đánh giá bị ẩn hoặc đang chờ duyệt. Backend có ràng buộc database để chặn cả các yêu cầu gửi đồng thời.

| Mã HTTP | Ý nghĩa và cách xử lý |
| --- | --- |
| 201 | Gửi thành công; tải lại lịch hẹn và danh sách đánh giá |
| 400 | Số sao/bình luận không hợp lệ hoặc hóa đơn chưa thanh toán |
| 401 | Chưa đăng nhập hoặc phiên không hợp lệ |
| 403 | Tài khoản không có hồ sơ khách hàng |
| 404 | Hóa đơn không tồn tại hoặc không thuộc khách đang đăng nhập |
| 409 | Hóa đơn đã được đánh giá; tải lại dữ liệu và ẩn nút gửi |

Lỗi nghiệp vụ của API đánh giá có thể trả chuỗi thông báo; lỗi kiểm tra dữ liệu tự động của ASP.NET Core có thể trả đối tượng có `errors`. Frontend nên xử lý dựa trên mã HTTP, không giả định mọi lỗi đều có trường `message`.

## 4. Gửi đánh giá trực tiếp từ lịch hẹn

### POST /api/v1/reviews/appointments/{appointmentId}

Endpoint mới giúp Flutter gửi đánh giá bằng ID lịch hẹn mà không cần tự quản lý ID hóa đơn. Body, response thành công và giới hạn nội dung giống mục 3. Frontend chọn một trong hai endpoint tạo đánh giá, không gọi cả hai cho cùng một lần gửi.

Backend kiểm tra:

1. Lịch hẹn thuộc khách đang đăng nhập.
2. Lịch hẹn có `status = HoanThanh`.
3. Có hóa đơn gắn với lịch hẹn và cùng khách hàng.
4. Hóa đơn mới nhất đã `DaThanhToan` và chưa được đánh giá.

“Hóa đơn mới nhất” được chọn theo `NgayLap` giảm dần, sau đó `HoaDonID` giảm dần; thống nhất với thông tin trả về trong danh sách lịch hẹn. Nếu hóa đơn mới nhất chưa thanh toán, backend trả 400, không tự chọn hóa đơn cũ đã thanh toán.

Lịch hẹn không thuộc khách hoặc không tồn tại: 404. Lịch chưa hoàn thành, thiếu hóa đơn hoặc hóa đơn chưa thanh toán: 400. Đã đánh giá qua một trong hai endpoint: 409.

Endpoint theo hóa đơn ở mục 3 giữ điều kiện hóa đơn đã thanh toán; điều kiện lịch hẹn hoàn thành được kiểm tra riêng ở endpoint theo lịch hẹn này.

## 5. Thông tin mới trong danh sách lịch hẹn

### GET /api/v1/appointments

Vẫn cần token và giữ cấu trúc phân trang:

```json
{
  "items": [
    {
      "id": 1,
      "customerId": 1,
      "staffId": 3,
      "appointmentAt": "2026-10-17T09:00:00",
      "status": "HoanThanh",
      "note": null,
      "items": [
        {
          "id": 1,
          "serviceId": 1,
          "serviceName": "Chăm sóc da",
          "comboId": null,
          "expectedPrice": 200000,
          "durationMinutes": 60
        }
      ],
      "invoiceId": 2,
      "invoiceStatus": "DaThanhToan",
      "hasReviewed": true,
      "reviewStars": 5
    }
  ],
  "totalCount": 1,
  "page": 1,
  "pageSize": 20
}
```

Bốn trường mới cần bổ sung vào model Web/Flutter:

| Trường | Kiểu dữ liệu | Ý nghĩa |
| --- | --- | --- |
| `invoiceId` | Số nguyên hoặc null | ID hóa đơn mới nhất của lịch hẹn |
| `invoiceStatus` | Chuỗi hoặc null | Trạng thái hóa đơn đó |
| `hasReviewed` | Boolean | Hóa đơn đó đã có đánh giá hay chưa |
| `reviewStars` | Số nguyên hoặc null | Số sao đã gửi |

Chưa có hóa đơn: `invoiceId`, `invoiceStatus`, `reviewStars` đều null; `hasReviewed = false`. Đã có đánh giá bị ẩn hoặc đang chờ duyệt vẫn có `hasReviewed = true`, để tránh gửi trùng. Các trường này chưa bao gồm trạng thái duyệt hay nội dung đánh giá đã gửi.

Điều kiện gợi ý để hiển thị nút **Đánh giá dịch vụ**:

```text
status == "HoanThanh"
&& invoiceStatus == "DaThanhToan"
&& hasReviewed == false
```

Sau khi gửi thành công, tải lại lịch hẹn và đánh giá dịch vụ. Khóa nút trong lúc gửi để hạn chế thao tác lặp.

Các trường mới thuộc `AppointmentResponse` của API danh sách và response tạo lịch hẹn. `GET /api/v1/appointments/{id}` có hợp đồng chi tiết riêng, chưa bổ sung bốn trường trên; không giả định hai response giống nhau.

## 6. Ẩn/hiện đánh giá trên Web quản trị

```http
PATCH /api/v1/reviews/{id}/moderation?visible=false
Authorization: Bearer <accessToken>
```

- Cần vai trò `Admin`, `Manager` hoặc `Reception`, đồng thời có quyền `REVIEW.MODERATE`.
- `visible=false`: chuyển thành `An`; `visible=true`: chuyển thành `HienThi`.
- Thành công: 204, không có body; không tìm thấy đánh giá: 404.
- `GET /api/v1/reviews/pending` vẫn lấy các đánh giá cũ `ChoDuyet`, với cùng điều kiện quyền quản trị trên.
- API công khai chỉ lấy đánh giá đang hiển thị; endpoint pending không phải danh sách tất cả đánh giá.

## 7. Quên mật khẩu bằng OTP email

Hai endpoint bên dưới công khai, không cần token. Web và Flutter có thể dùng cùng một luồng:

1. Người dùng nhập email rồi gọi `forgot-password`.
2. Hiển thị thông báo tiếp nhận và màn hình nhập OTP cùng mật khẩu mới.
3. Người dùng gửi OTP/mật khẩu mới qua `reset-password`.
4. Thành công: xóa phiên đăng nhập cũ và chuyển về màn hình đăng nhập bằng mật khẩu mới.

Hiện không có endpoint kiểm tra OTP riêng. OTP được kiểm tra cùng lúc với thao tác đặt lại mật khẩu.

### 7.1. POST /api/v1/auth/forgot-password

Body:

```json
{
  "email": "user@example.com"
}
```

HTTP 200:

```json
{
  "message": "Nếu email thuộc tài khoản đang hoạt động, mã xác nhận sẽ được gửi đến email đó. Vui lòng kiểm tra hộp thư và thư rác."
}
```

- Email bắt buộc, đúng định dạng, tối đa 255 ký tự.
- Cùng thông báo 200 cho email tồn tại, không tồn tại, tài khoản ngừng hoạt động hoặc yêu cầu gửi lại quá sớm; tránh tiết lộ tài khoản.
- HTTP 200 nghĩa là đã tiếp nhận yêu cầu, không đảm bảo email đã giao thành công. SMTP gửi thư bất đồng bộ.
- Không trả `debugOtp`, OTP thật hay token trong response. Giao diện hướng dẫn kiểm tra cả hộp thư đến và thư rác.
- Email sai định dạng: 400; vượt giới hạn theo IP: 429.

### 7.2. POST /api/v1/auth/reset-password

Body:

```json
{
  "email": "user@example.com",
  "otp": "012345",
  "newPassword": "HealthBeauty@456"
}
```

- `otp` là **chuỗi đúng 6 chữ số**, phải giữ số 0 ở đầu; không chuyển sang số nguyên.
- `newPassword`: 8–128 ký tự, không chỉ chứa khoảng trắng. Frontend không tự trim mật khẩu.
- Ô xác nhận mật khẩu là kiểm tra phía giao diện, không có trường `confirmPassword` trong API.

HTTP 200:

```json
{
  "message": "Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới."
}
```

HTTP 400 khi mã sai, hết hạn, đã dùng, hết lượt thử hoặc tài khoản không đủ điều kiện:

```json
{
  "message": "Mã xác nhận không hợp lệ hoặc đã hết hạn."
}
```

Dữ liệu sai định dạng cũng trả 400, có thể dùng cấu trúc lỗi có `errors` của ASP.NET Core. Không dựa vào thông báo lỗi để suy ra email có tồn tại.

HTTP 429 khi vượt giới hạn IP:

```json
{
  "message": "Bạn đã thử quá nhiều lần. Vui lòng thử lại sau."
}
```

Khi nhận 429, đọc header `Retry-After` để thông báo thời gian thử lại; cấu hình hiện tại trả `600` giây.

### 7.3. Thời hạn OTP và gửi lại

| Chính sách | Giá trị hiện tại |
| --- | --- |
| Thời hạn OTP | 15 phút |
| Số lượt kiểm tra OTP tối đa | 5 lượt |
| Khoảng cách tối thiểu giữa hai lần gửi | 60 giây |
| Giới hạn gửi theo tài khoản | 5 lần trong cửa sổ 1 giờ |
| Giới hạn `forgot-password` theo IP | 10 yêu cầu trong 10 phút |
| Giới hạn `reset-password` theo IP | 20 yêu cầu trong 10 phút |

- Hai giới hạn IP có bộ đếm riêng. Các giới hạn theo tài khoản vẫn trả thông báo tiếp nhận chung để bảo mật.
- Gửi lại bằng chính `forgot-password`, không có endpoint resend riêng.
- Sau khi gửi lại thành công ở backend, mã mới thay thế mã cũ; dùng email mới nhất.
- Giao diện nên đếm ngược 60 giây cho nút gửi lại. Response không có `expiresAt` hay thời gian gửi lại chính xác từ máy chủ; đồng hồ phía giao diện chỉ là hướng dẫn.
- OTP chỉ dùng một lần. Hết lượt thử hoặc hết hạn thì yêu cầu mã mới, theo giới hạn gửi lại.

### 7.4. Xử lý phiên sau khi đổi mật khẩu

Backend đổi mật khẩu, đánh dấu OTP đã dùng, thay SecurityStamp, thu hồi refresh token và ghi audit trong cùng giao dịch database. Access token và refresh token cũ bị từ chối sau khi đặt lại mật khẩu.

Frontend cần:

- Xóa access token, refresh token và thông tin người dùng đang lưu sau HTTP 200 của `reset-password`.
- Chuyển về đăng nhập; API reset không tự đăng nhập và không cấp token mới.
- Khi phiên cũ ở thiết bị khác nhận 401, xóa phiên và yêu cầu đăng nhập lại; tránh lặp refresh vô hạn.
- Tài khoản ngừng hoạt động không được tự kích hoạt lại qua quên mật khẩu. Với tài khoản hợp lệ, đặt lại mật khẩu thành công xóa bộ đếm đăng nhập sai và khóa tạm thời.

## 8. Database và cấu hình khi thành viên chạy trên máy khác

### Database có sẵn

Chạy lần lượt trong SSMS trước khi chạy backend mới:

1. `DB_KLCN021/04_PasswordRecovery.sql`: thêm bảng `PASSWORDRESETCHALLENGE` và cột `SecurityStamp` vào `TAIKHOAN`, `REFRESHTOKEN`.
2. `DB_KLCN021/05_ReviewInvoiceUniqueness.sql`: tạo ràng buộc mỗi hóa đơn chỉ có một đánh giá.

Cả hai script chạy lại được. Script 05 dừng nếu có đánh giá trùng hóa đơn để xử lý thủ công, không tự xóa đánh giá. Script 04 không đổi mật khẩu hay dữ liệu nghiệp vụ cũ. Database local của máy đang phát triển đã áp dụng cả hai; máy thành viên khác cần tự cập nhật.

Database tạo mới dùng `KLCN021_HealthBeauty.sql` hiện tại đã có cấu trúc trên, sau đó chạy seed/quyền theo README của dự án. Sau phần quên mật khẩu, database có 25 bảng nghiệp vụ; phần đánh giá không tạo thêm bảng.

### SMTP gửi OTP

Cấu hình SMTP anh cung cấp đã được áp dụng riêng trên máy đang phát triển trong `HealthBeauty.Api/appsettings.Development.local.json`, với `Smtp:Enabled=true`. File này được Git bỏ qua, nên clone code không tự có cấu hình gửi email. API đã khởi động lại với cấu hình đó, nhưng chưa kiểm chứng giao email thật.

Mỗi thành viên có thể dùng User Secrets trong thư mục `HealthBeauty.Api`:

```powershell
dotnet user-secrets set "Smtp:Enabled" "true"
dotnet user-secrets set "Smtp:Host" "smtp.gmail.com"
dotnet user-secrets set "Smtp:Port" "587"
dotnet user-secrets set "Smtp:EnableSsl" "true"
dotnet user-secrets set "Smtp:UserName" "<email-gui>"
dotnet user-secrets set "Smtp:SenderEmail" "<email-gui>"
dotnet user-secrets set "Smtp:SenderName" "HealthBeauty"
dotnet user-secrets set "Smtp:Password" "<mat-khau-ung-dung>"
```

Với Gmail, dùng mật khẩu ứng dụng của tài khoản gửi, không dùng mật khẩu đăng nhập Gmail. Thay các giá trị trong dấu `<...>` bằng cấu hình được cấp riêng, không chép thông tin bí mật vào tài liệu/Git. Có thể dùng biến môi trường hoặc file local thay thế. Nếu file local có cùng khóa, nó ghi đè User Secrets trong môi trường Development; biến môi trường/tham số dòng lệnh có ưu tiên cao hơn.

Sau khi đổi cấu hình, khởi động lại API:

```powershell
cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty\HealthBeauty.Api
dotnet run --launch-profile http
```

Đường dẫn trên là máy đang phát triển; máy thành viên khác dùng đường dẫn clone tương ứng. JWT và kết nối SQL vẫn cấu hình theo README. Thiếu hoặc tắt SMTP thì API vẫn chạy, nhưng không tạo/gửi mã OTP. Frontend không giữ mật khẩu SMTP và không tự gửi email.

Chi tiết kỹ thuật phần khôi phục mật khẩu có thêm trong [PASSWORD_RECOVERY.md](PASSWORD_RECOVERY.md). Database chỉ lưu mã OTP đã băm, không lưu OTP thô; hàng đợi email nằm trong RAM nên thư đang chờ có thể mất khi API dừng. Người dùng có thể gửi lại theo giới hạn ở trên.

## 9. Checklist cho hai thành viên

### Flutter

- [ ] Đổi model danh sách đánh giá từ mảng sang đối tượng thống kê có `items`.
- [ ] Hiển thị `tenKhachHang`, `averageRating`, `totalReviews` và trạng thái chưa có đánh giá.
- [ ] Thêm bốn trường hóa đơn/đánh giá vào model lịch hẹn, xử lý null.
- [ ] Hiện nút đánh giá theo điều kiện ở mục 5; gửi đúng `stars`, `comment` qua một trong hai endpoint.
- [ ] Sau 201 hoặc 409, tải lại trạng thái lịch hẹn; không cho gửi lặp.
- [ ] Tạo luồng quên mật khẩu → OTP/mật khẩu mới → đăng nhập lại; giữ OTP dạng chuỗi.
- [ ] Xử lý lỗi 400/429, đếm ngược gửi lại, xóa phiên sau reset thành công.

### Web

- [ ] Nếu đang đọc đánh giá, đổi sang `items` và hiển thị thống kê theo hợp đồng mới.
- [ ] Dùng endpoint PATCH ẩn/hiện với quyền `REVIEW.MODERATE`; 204 không đọc JSON body.
- [ ] Khi dùng danh sách lịch hẹn, đọc các trường hóa đơn/đánh giá mới và xử lý null.
- [ ] Thêm luồng quên mật khẩu trên màn hình đăng nhập; dùng cùng API và quy tắc OTP như Flutter.
- [ ] Xóa phiên sau reset; xử lý 401 của phiên cũ, không lặp refresh vô hạn.

### Kiểm tra tích hợp chung

- [ ] Dịch vụ chưa có đánh giá hiển thị đúng, không mặc định 5 sao.
- [ ] Đánh giá mới xuất hiện ngay; đánh giá bị ẩn không còn trong thống kê công khai.
- [ ] Không đánh giá được hóa đơn người khác, hóa đơn chưa thanh toán hoặc hóa đơn đã đánh giá.
- [ ] Lịch chưa có hóa đơn không gây lỗi giao diện; lịch đã đánh giá không còn nút gửi mới.
- [ ] Thử email đã đăng ký đang hoạt động, nhận OTP thật, đặt lại mật khẩu rồi đăng nhập bằng mật khẩu mới.
- [ ] Thử OTP sai, hết hạn, dùng lại và gửi lại; không làm mất số 0 đầu mã.
- [ ] Khi hết hạn mức, hiển thị thời gian chờ; không gọi API lặp tự động.

## 10. Kết quả xác minh backend

Kết quả kiểm tra trước khi tổng hợp tài liệu này:

- 237/237 kiểm thử API đạt, bao gồm 14 trường hợp bổ sung cho luồng đánh giá.
- Build API: 0 cảnh báo, 0 lỗi.
- 13 kiểm tra trên SQL Server tạm đạt: thống kê/lọc combo, phân trang lịch hẹn, migration chạy lại và xử lý trùng; 12 yêu cầu đánh giá đồng thời chỉ một yêu cầu tạo thành công, còn lại 409.
- API chạy thực tế: đọc đánh giá 200 với hợp đồng mới, gửi đánh giá chưa đăng nhập 401, serviceId không hợp lệ 400. Swagger hiện có 80 thao tác.
- Migration 05 đã áp dụng local; số dòng và checksum dữ liệu đánh giá không đổi.
- Chưa kiểm thử giao email thật hoặc luồng giao diện mới trên Web/Flutter. Đây là phần hai thành viên cần kiểm tra tiếp khi tích hợp.

## 11. Thông báo trong ứng dụng và thông báo đẩy Firebase

### 11.1. Tổng quan thay đổi

Backend bổ sung hộp thư thông báo, đăng ký thiết bị Firebase Cloud Messaging (FCM), đánh dấu đã đọc riêng cho từng tài khoản và tự tạo thông báo từ nghiệp vụ. Phần này chỉ sửa backend; thành viên Flutter/Web tích hợp theo API dưới đây.

Tất cả 6 API thông báo cần `Authorization: Bearer <accessToken>` và tài khoản có hồ sơ khách hàng. Không đăng nhập/phiên không hợp lệ: 401; không có hồ sơ khách hàng: 403. Không có API công khai gửi thông báo tùy ý.

- Thông báo riêng chỉ hiện cho đúng tài khoản và khách hàng nhận.
- Thông báo khuyến mãi chung hiện trong hộp thư của các khách hàng; mỗi tài khoản có trạng thái đọc riêng. Khách A đọc không làm khách B bị đánh dấu đã đọc.
- Hộp thư hoạt động ngay cả khi chưa cấu hình Firebase hoặc gửi đẩy thất bại.
- Trong API hộp thư, `type` là `LichHen`, `KhuyenMai`, `Voucher` hoặc `HoaDon`; trong `data`/payload FCM, `type` định tuyến là `APPOINTMENT`, `PROMOTION`, `VOUCHER`, `INVOICE`.

### 11.2. Đăng ký thiết bị nhận thông báo

```http
POST /api/v1/notifications/device-token
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "token": "fcm-token-do-firebase-sdk-tra-ve",
  "deviceType": "android"
}
```

`token` bắt buộc, tối đa 500 ký tự, không chứa khoảng trắng. `deviceType` bắt buộc, nhận đúng `android`, `ios` hoặc `web`. Thành công trả 200 với thông báo xác nhận. Sai dữ liệu: 400.

Gọi sau khi đăng nhập và khi Firebase SDK báo token thay đổi. Backend cập nhật token đã tồn tại, gán lại đúng tài khoản/khách đang đăng nhập và bật nhận thông báo; không tạo bản ghi trùng cho cùng token. Không gửi mã JWT vào trường `token`: đây là token thiết bị FCM.

### 11.3. Hủy đăng ký khi đăng xuất

```http
DELETE /api/v1/notifications/device-token?token=<fcm-token-da-url-encode>
Authorization: Bearer <accessToken>
```

Gọi trước khi xóa phiên đăng nhập phía frontend. Thành công trả 204, không có body. Chỉ vô hiệu hóa token đang thuộc tài khoản hiện tại; tài khoản cũ không thể tắt token đã chuyển sang người khác. Gọi lại hoặc token không thuộc tài khoản vẫn trả 204. Endpoint hiện nhận token qua query, không nhận JSON body.

Mỗi lần người dùng khác đăng nhập trên cùng thiết bị, đăng ký lại token cho tài khoản mới. Thông báo đã được Firebase nhận để chuyển đi có thể đang trên đường đến thiết bị; phía ứng dụng cần tránh hiển thị dữ liệu phiên cũ sau khi đăng xuất/chuyển tài khoản.

### 11.4. Lấy hộp thư thông báo

```http
GET /api/v1/notifications?page=1&pageSize=20&unreadOnly=false
Authorization: Bearer <accessToken>
```

Ví dụ 200:

```json
{
  "items": [
    {
      "id": 105,
      "title": "Lịch hẹn #LH12 đã được xác nhận",
      "body": "HealthBeauty đã xác nhận lịch hẹn lúc 09:30 18/10/2026.",
      "type": "LichHen",
      "data": "{\"type\":\"APPOINTMENT\",\"appointmentId\":\"12\"}",
      "isRead": false,
      "createdAt": "2026-10-17T02:15:00Z"
    }
  ],
  "totalCount": 15,
  "unreadCount": 3,
  "page": 1,
  "pageSize": 20
}
```

- `data` là **chuỗi JSON hoặc null**, không phải đối tượng JSON lồng trực tiếp. Parse một lần nếu cần điều hướng tới lịch hẹn/hóa đơn/voucher/khuyến mãi.
- ID trong `data` là chuỗi; chuyển kiểu phù hợp khi gọi API chi tiết.
- `createdAt` dùng UTC; giao diện chuyển sang giờ Việt Nam khi hiển thị.
- Sắp xếp thời gian giảm dần, rồi ID giảm dần; `page` tối thiểu 1, `pageSize` giới hạn 1–100.
- `totalCount` tính theo bộ lọc hiện tại. Khi `unreadOnly=true`, đây là tổng chưa đọc. `unreadCount` luôn tính toàn bộ thông báo chưa đọc mà tài khoản được phép xem, không chỉ số dòng trang hiện tại.
- Chưa có thông báo trả `items=[]`, số lượng bằng 0.

### 11.5. Đếm và đánh dấu đã đọc

| Thao tác | Endpoint | Response thành công |
| --- | --- | --- |
| Lấy badge chưa đọc | `GET /api/v1/notifications/unread-count` | 200: `{ "unreadCount": 3 }` |
| Đọc một thông báo | `PATCH /api/v1/notifications/{id}/read` | 204, không có body |
| Đọc tất cả | `PATCH /api/v1/notifications/read-all` | 204, không có body |

Hai lệnh PATCH không cần body. Đọc lại thông báo đã đọc vẫn thành công. ID không tồn tại hoặc thuộc người khác trả 404. `read-all` chỉ tác động hộp thư của tài khoản hiện tại và các thông báo tồn tại tại thời điểm lấy danh sách xử lý; không đánh dấu thông báo đến sau đó.

Sau PATCH, tải lại số chưa đọc và cập nhật danh sách. Không gọi JSON decode khi response là 204.

### 11.6. Các sự kiện tự tạo thông báo

| Nghiệp vụ thành công | Loại thông báo | Dữ liệu điều hướng |
| --- | --- | --- |
| Xác nhận, check-in, đang thực hiện, hoàn thành, hủy lịch | `LichHen` | `type=APPOINTMENT`, `appointmentId` |
| Đổi giờ qua PUT hoặc POST reschedule; hủy qua DELETE | `LichHen` | `type=APPOINTMENT`, `appointmentId` |
| Tạo chương trình khuyến mãi mới | `KhuyenMai`, thông báo chung | `type=PROMOTION`, `promotionId` |
| Tạo voucher gán cho khách cụ thể | `Voucher`, thông báo riêng | `type=VOUCHER`, `code` |
| Thanh toán hóa đơn thành công, kể cả hóa đơn 0 đồng | `HoaDon` | `type=INVOICE`, `invoiceId`, `earnedPoints` |

Khách chưa liên kết tài khoản sẽ không nhận thông báo riêng; không biến trường hợp đó thành thông báo chung. Chỉ tạo voucher không gán khách thì không gửi thông báo riêng. Cập nhật/xóa khuyến mãi không tự tạo thông báo mới.

Thông báo và thay đổi nghiệp vụ được lưu trong cùng giao dịch SQL; lỗi lưu sẽ không để lại trạng thái nghiệp vụ thành công nhưng mất thông báo. Cột rowversion ở lịch hẹn/hóa đơn giúp chặn hai yêu cầu cập nhật/thanh toán đồng thời trên cùng bản ghi: yêu cầu thua xung đột nhận 409 và cần tải lại dữ liệu. Gửi đẩy diễn ra sau, không chặn response chờ Firebase.

### 11.7. Cấu hình Firebase cho backend

Cần file khóa **service account** của đúng dự án Firebase được ứng dụng Flutter sử dụng. File `google-services.json` của Android hoặc `GoogleService-Info.plist` của iOS không thay thế khóa service account của server.

Mặc định Firebase tắt. Từ thư mục `HealthBeauty.Api`, cấu hình bằng User Secrets:

```powershell
dotnet user-secrets set "Firebase:Enabled" "true"
dotnet user-secrets set "Firebase:CredentialsPath" "D:\duong-dan-rieng\firebase-service-account.json"
dotnet user-secrets set "Firebase:ProjectId" "firebase-project-id-cua-nhom"
```

`ProjectId` có thể bỏ nếu lấy từ service account. `Firebase:CredentialFile` cũng được hỗ trợ để tương thích tên cấu hình trong tài liệu đề xuất; ưu tiên dùng `CredentialsPath`.

Giữ file khóa ở vị trí riêng trên máy server, ngoài thư mục publish; không gửi lên Git và không đưa vào Flutter/Web. Tên file khóa thông dụng đã được Git bỏ qua, nhưng vẫn cần giữ khóa ngoài source. Mẫu `Configuration/notifications.example.json` chỉ để tham khảo, không tự nạp. Khởi động lại API sau khi đổi cấu hình.

Nếu tắt Firebase, thiếu file hoặc file không hợp lệ, API/hộp thư vẫn hoạt động; các thông báo chờ gửi được giữ trong database. Sau khi cấu hình hợp lệ và khởi động lại, worker tiếp tục xử lý hàng chờ. Chưa có khóa trong môi trường hiện tại nên chưa xác minh gửi đến điện thoại thật.

Theo [hướng dẫn Firebase Admin SDK](https://firebase.google.com/docs/admin/setup), tạo khóa trong Firebase Console → Project settings → Service accounts, và bật Cloud Messaging API theo [hướng dẫn gửi tin của Firebase](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).

### 11.8. Lưu ý cho Flutter khi nhận push

- Xin quyền nhận thông báo và lấy token bằng Firebase SDK của ứng dụng.
- Dùng cùng Firebase project với backend; cấu hình Android/iOS theo dự án nhóm.
- Tạo Android notification channel `spa_notifications`; payload có âm thanh mặc định.
- Payload FCM có `notificationId`, `type` định tuyến và ID nghiệp vụ trực tiếp, ví dụ `appointmentId`. Có thêm `payload` là chuỗi JSON dữ liệu gốc.
- Backend gửi trực tiếp tới các token khách hàng đang hoạt động, theo lô tối đa 500; không yêu cầu ứng dụng subscribe topic `promotions`.
- Hàng chờ SQL có retry tối đa 5 lần và khóa xử lý để các worker không cùng lấy một thông báo. Trường hợp retry một phần hoặc khôi phục sau gián đoạn có thể gửi lặp; dùng `notificationId` để tránh tạo thông báo cục bộ trùng.
- Chỉ token Firebase báo `Unregistered` mới bị tự vô hiệu hóa; các lỗi cấu hình/payload không làm tắt hàng loạt thiết bị.
- Không có thiết bị hoạt động thì vẫn có bản ghi hộp thư, nhưng không tự gửi lại push cũ khi đăng ký thiết bị sau đó.
- Việc app đang mở, chạy nền hay bị hệ điều hành chặn phụ thuộc cấu hình phía ứng dụng và quyền thiết bị. Token thử bất kỳ trong Swagger chỉ kiểm tra đăng ký, không chứng minh nhận push thật.

### 11.9. SQL mới và checklist tích hợp

Chạy thêm `DB_KLCN021/06_Notifications.sql` sau 04 và 05 trên database hiện có. Script thêm 3 bảng `ThietBiKhachHang`, `ThongBao`, `ThongBaoDaDoc` và cột rowversion vào lịch hẹn/hóa đơn; database đầy đủ hiện có 28 bảng nghiệp vụ. Schema gốc cũng được cập nhật cho database mới.

Bảng thứ ba giữ trạng thái đọc theo tài khoản. Nếu trước đó đã chạy mẫu 2 bảng trong file yêu cầu, migration bổ sung các cột còn thiếu, giữ cờ đọc của thông báo riêng; không dùng cờ đọc chung của broadcast cho tất cả khách. Thông báo cũ của mẫu không bị phát push lại tự động. Script không chèn dữ liệu demo và có thể chạy lại.

Checklist Flutter:

- [ ] Đăng ký FCM token sau đăng nhập và khi token thay đổi.
- [ ] Hủy token trước khi xóa phiên đăng xuất; đăng ký lại khi đổi tài khoản.
- [ ] Tải hộp thư, phân trang, lọc chưa đọc và badge bằng đúng 6 API.
- [ ] Parse `data` dạng chuỗi JSON; xử lý null và ID dạng chuỗi.
- [ ] Đánh dấu đã đọc khi mở thông báo; xử lý 204 không có body.
- [ ] Nhận push theo channel/type/notificationId ở trên; tránh nhân đôi thông báo cục bộ.
- [ ] Thử hai tài khoản: thông báo riêng không lộ sang nhau; đọc khuyến mãi chung độc lập.

Checklist Web/backend:

- [ ] Database đã chạy migration 06 trước khi dùng backend mới.
- [ ] Khi duyệt lịch, đổi giờ, hủy, tạo ưu đãi/voucher và thanh toán, kiểm tra thông báo xuất hiện ở tài khoản khách.
- [ ] Không tự tạo thêm thông báo từ frontend cho cùng sự kiện: backend đã làm.
- [ ] Nếu Web muốn nhận push cho khách hàng, đăng ký `deviceType=web` và cấu hình Firebase phía Web. Hộp thư hiện là API cho tài khoản có hồ sơ khách, không phải hộp thư nội bộ quản trị.
- [ ] Kiểm tra gửi thật sau khi có khóa server và token thiết bị thật, không coi đăng ký token 200 là đã gửi Firebase thành công.

### 11.10. Kết quả kiểm tra phần thông báo

- Tổng bộ kiểm thử backend sau cập nhật: **281/281 đạt**, gồm kiểm thử HTTP dùng JWT thật; build **0 cảnh báo, 0 lỗi**.
- **23 kiểm tra SQL Server tạm đạt**: migration mới/cũ chạy lại, 12 worker cùng lấy việc chỉ một lần gửi giả lập, retry/khôi phục lease, token đổi chủ, đọc độc lập, đăng ký/đánh dấu đọc đồng thời.
- Hai yêu cầu thanh toán đồng thời trên cùng hóa đơn: một thành công, một 409; chỉ một bản ghi thanh toán, một giao dịch tích điểm và một thông báo.
- Lỗi chèn thông báo giả lập làm rollback cả chương trình khuyến mãi và thông báo; không để nghiệp vụ lưu dở.
- Gửi Firebase dùng bộ gửi giả trong kiểm thử. Chưa kiểm tra nhận push thực tế trên thiết bị vì chưa cấu hình khóa service account.

Migration 06 đã áp dụng trên database local của máy đang phát triển: snapshot số dòng/checksum của 25 bảng cũ không đổi, tổng hiện có 28 bảng nghiệp vụ. API đã khởi động lại; Swagger có 86 thao tác, cả 6 route thông báo yêu cầu đăng nhập (401 khi không có token). Máy thành viên khác cần tự chạy script trước khi tích hợp.

## 12. Ảnh upload Cloudinary, nhắc lịch và voucher đổi điểm (18/10/2026)

Báo cáo ngắn cho thành viên Web: [BAO_CAO_5_CHUC_NANG_WEB.md](../BAO_CAO_5_CHUC_NANG_WEB.md). Đợt này chỉ bổ sung backend, không sửa nhánh Web của thành viên; chưa commit/push.

### 12.1. Upload ảnh dịch vụ/combo

`POST /api/v1/media/images`, có Bearer token; vai trò Admin/Manager/Reception cùng quyền `SERVICE.WRITE`. Gửi **multipart/form-data**, trường `file`. Chấp nhận PNG/JPEG/WebP tối đa 5 MiB, kiểm tra loại và chữ ký dữ liệu, không nhận SVG hay URL để server tự tải.

Ví dụ response 201:

```json
{
  "imageUrl": "https://res.cloudinary.com/your-cloud/image/upload/example.jpg",
  "publicId": "healthbeauty/catalog/example"
}
```

Sau upload, gửi `imageUrl` vào POST/PUT `/api/v1/services` hoặc `/api/v1/combos`. Các response danh sách, chi tiết và lưu của hai module đã có trường `imageUrl` nullable; lưu chung trong SQL thay cho localStorage.

- Tạo mới không gửi/null/rỗng: chưa có ảnh. Sửa bỏ trường/null: giữ ảnh cũ. Sửa với chuỗi rỗng: xóa liên kết ảnh.
- URL phải HTTP/HTTPS, tối đa 2048 ký tự, không chứa thông tin đăng nhập/ký tự điều khiển.
- Upload lỗi 400: file không hợp lệ; 413: quá dung lượng; 503: chưa cấu hình Cloudinary; 502: lỗi nhà cung cấp; 504: timeout.
- `publicId` là mã tài nguyên Cloudinary. Bản hiện tại lưu URL trong dịch vụ/combo; xóa liên kết không tự xóa file trên Cloudinary. Ảnh upload xong nhưng người dùng bỏ form vẫn nằm trên Cloudinary, cần dọn tài nguyên không dùng khi vận hành.
- Chưa có upload avatar của khách, album nhiều ảnh hoặc module sản phẩm trong phạm vi này.

Frontend dùng FormData phải bỏ header JSON mặc định của axios cho request này để trình duyệt tự tạo multipart boundary. Không đưa API secret Cloudinary vào Web/Flutter.

Cấu hình tại thư mục `HealthBeauty.Api` bằng User Secrets, rồi khởi động lại API:

```powershell
dotnet user-secrets set "Cloudinary:Enabled" "true"
dotnet user-secrets set "Cloudinary:CloudName" "<cloud-name>"
dotnet user-secrets set "Cloudinary:ApiKey" "<api-key>"
dotnet user-secrets set "Cloudinary:ApiSecret" "<api-secret>"
```

Cloudinary mặc định tắt; API vẫn chạy, riêng upload nhận 503 khi chưa cấu hình. `Configuration/cloudinary.example.json` chỉ là mẫu, không tự nạp. Upload có chữ ký phía server, không ghi file vào ổ đĩa API. Tham khảo [tài liệu upload Cloudinary](https://cloudinary.com/documentation/upload_images#authenticated_requests).

### 12.2. Nhắc lịch tự động

Mặc định worker quét mỗi 60 giây, tạo nhắc cho lịch `DaXacNhan` còn trong tương lai và trong 60 phút tới. Khách phải có tài khoản hoạt động. Cấu hình `AppointmentReminders:Enabled`, `LeadMinutes` (1–1440), `PollSeconds` (10–3600).

Khóa sự kiện lưu trong SQL chống tạo trùng khi nhiều worker/khởi động lại. Đổi giờ hẹn có khóa mới. Tại thời điểm gửi, backend kiểm tra lại lịch còn xác nhận, đúng khách/tài khoản/giờ và chưa quá hạn; nhắc lịch cũ bị bỏ qua nếu đã hủy hoặc đổi lịch. Dùng hàng đợi/Firebase hiện có, không cần Web gọi API gửi nhắc riêng.

Giờ lịch hẹn theo giờ địa phương của server như API cũ; triển khai phải đặt múi giờ Việt Nam (Asia/Ho_Chi_Minh hoặc múi giờ Windows tương ứng). Thời gian thông báo vẫn UTC. Chưa có khóa Firebase thì chỉ có hộp thư, chưa kiểm chứng push thật; gửi đẩy vẫn có thể lặp khi mạng gián đoạn, client dedup theo `notificationId`.

### 12.3. Cấu hình voucher đổi điểm

Thêm `pointsCost` (0–1.000.000) vào body tạo/sửa voucher:

```json
{
  "code": "DOIDIEM100",
  "promotionId": 1,
  "customerId": null,
  "discountValue": 50000,
  "expiresAt": "2027-12-31T23:59:59",
  "pointsCost": 100
}
```

- `pointsCost=0`: voucher tặng/khuyến mãi cũ, không tự trừ điểm.
- `pointsCost>0`: voucher cần đổi điểm; phải tạo chưa gán khách. Mỗi mã là một suất đổi một lần, không phải mẫu phát hành vô hạn; tạo nhiều mã nếu cần nhiều suất.
- Không gán trực tiếp voucher đổi điểm để bỏ qua thu điểm. Voucher đã gán/đổi không thay chủ hoặc giá điểm. Khi đã sử dụng thì không kích hoạt lại.

Khách xem ưu đãi đổi điểm qua `GET /api/v1/customers/me/voucher-offers`. Response là mảng `{id,promotionId,promotionName,discountValue,expiresAt,pointsCost}`, không lộ mã voucher trước khi đổi. Chỉ trả voucher còn hạn, hoạt động, khuyến mãi hợp lệ, chưa đổi/chưa dùng.

Khách đổi bằng `POST /api/v1/customers/me/vouchers/{id}/redeem`, có Bearer token và hồ sơ khách, **không body**. Thành công 200:

```json
{
  "voucherId": 1,
  "code": "DOIDIEM100",
  "pointsSpent": 100,
  "remainingPoints": 250
}
```

Thiếu điểm: 400; không có hồ sơ khách: 403; voucher không tồn tại/không hợp lệ: 404; đã đổi hoặc bị yêu cầu khác thay đổi số dư/voucher: 409. Đổi thành công trừ điểm, gán voucher và ghi `GIAODICHDIEM` loại `DoiVoucher` cùng `voucherId` trong một transaction. Đổi lại không trừ lần hai. Voucher chưa đổi không dùng được khi validate/lập hóa đơn; sử dụng voucher đã đổi không thu lại `pointsCost`.

Giữ luồng hiện có: thanh toán cộng `floor(tiền thực trả/10.000)` điểm; `pointsToRedeem` trên hóa đơn là đổi điểm trực tiếp (1 điểm = 1đ), được trừ khi lập hóa đơn. Đây là hai thao tác khác nhau, người dùng có thể chủ động chọn số điểm đổi trực tiếp nếu muốn, không mặc định trừ thêm khi dùng voucher.

### 12.4. Lịch sử điểm cho quản trị

`GET /api/v1/customers/{id}/points?page=1&pageSize=20`: vai trò Admin/Manager/Reception và quyền `CUSTOMER.READ`. Response `{customerId,diemThuong,transactions,totalCount,page,pageSize}`. Mỗi giao dịch có `giaoDichId,soDiem,loaiGiaoDich,ngayGiaoDich,ghiChu,hoaDonId,voucherId`. `soDiem` âm là trừ, dương là cộng. Khách không tồn tại: 404; page không hợp lệ: 400, pageSize 1–100.

API `/api/v1/customers/me/points` của khách giữ hợp đồng cũ, bổ sung `voucherId` trong lịch sử. Web cần thêm tab lịch sử điểm trong hồ sơ khách. Đã bổ sung kiểm soát đồng thời số dư/voucher và một hóa đơn cho một lịch hẹn; gặp 409 cần tải lại, không tự lặp request.

### 12.5. Database cập nhật

Trên database đã có 04–06, chạy **07 → 08 → 09 → 10**:

| File | Bổ sung |
| --- | --- |
| `07_ServiceImages.sql` | Cột URL ảnh dịch vụ và combo |
| `08_AppointmentReminders.sql` | Khóa sự kiện nhắc lịch và unique index chống trùng |
| `09_LoyaltyConsistency.sql` | RowVersion số dư/voucher, unique hóa đơn theo lịch hẹn |
| `10_VoucherPointExchange.sql` | Giá điểm, thời điểm đổi/dùng voucher, liên kết lịch sử điểm |

Cả bốn chạy lại được. File 09 dừng nếu có hóa đơn trùng lịch hẹn cũ để xử lý thủ công, không xóa dữ liệu. Voucher cũ có `pointsCost=0`; không tự trừ điểm cũ. Không thêm bảng mới, tổng vẫn 28 bảng nghiệp vụ. SQL gốc đã tích hợp cho database mới. Cloudinary không cần bảng riêng vì ảnh thực tế nằm trên dịch vụ lưu trữ, SQL giữ URL.

Kiểm chứng đợt 18/10: **361/361 test backend đạt**, build 0 cảnh báo/lỗi; **21 kiểm tra SQL ảnh/nhắc lịch + 22 kiểm tra SQL điểm/voucher đạt**. Database local đã chạy 07–10: 28 bảng và snapshot dữ liệu cũ (gồm điểm/tài khoản) không đổi. API mới đã khởi động lại, Swagger có 90 thao tác; lịch sử điểm quản trị 200, upload chưa cấu hình trả 503 đúng thiết kế. Chưa có khóa Cloudinary/Firebase nên chưa kiểm tra upload/gửi push thật.


## 13. Quản lý đánh giá dịch vụ (18/10/2026)

Bổ sung `GET /api/v1/reviews/management` lọc `serviceId`, `from`, `to`, `stars`, `status`, phân trang `page` mặc định 1, `pageSize` mặc định 20, tối đa 100. Các bộ lọc kết hợp AND; dịch vụ khớp cả thành phần combo; `from/to` bao gồm thời điểm đầu/cuối, ngày đánh giá theo thời gian máy chủ đang dùng. Thống kê toàn bộ kết quả phù hợp trước phân trang; tổng/sao trung bình lấy một truy vấn nhóm để tránh lỗi tập rỗng khi thao tác đồng thời. Danh sách gồm cả đánh giá ẩn/chờ duyệt, trừ bản xóa mềm; trả thông tin khách và dòng dịch vụ/combo, không trả liên hệ khách.

`PUT /api/v1/reviews/{id}/reply` nhận `{reply}` dài 1–2000 ký tự sau kiểm tra, không chỉ khoảng trắng; lưu phản hồi hiện tại, tài khoản thực hiện và thời điểm UTC. Gọi lại để thay phản hồi (chưa có lịch sử nhiều lần). `GET /reviews` giữ nguyên `{averageRating,totalReviews,items}` và bổ sung `reply/repliedAt`; không lộ mã tài khoản người phản hồi. Thời điểm phản hồi được gắn UTC khi đọc SQL, JSON có `Z`. Phản hồi chỉ xuất hiện công khai khi đánh giá đang `HienThi`; chưa tự phát push/email.

`PATCH /reviews/{id}/moderation?visible=true|false` duyệt/ẩn; `DELETE /reviews/{id}` xóa mềm. Các lệnh thành công `204`; không tồn tại/đã xóa `404`; tranh chấp cập nhật sau khi đọc `409` (tải lại/thử lại). GUID `Version` là concurrency token phía máy chủ; không yêu cầu client gửi version, không ngăn người dùng tuần tự ghi đè phản hồi cũ đang mở lâu. Xóa mềm không giải phóng hóa đơn, không đổi trạng thái `hasReviewed`, không cho duyệt hoặc phản hồi để hồi sinh bản đã xóa. Đánh giá mới vẫn hiện ngay như yêu cầu trước; không tự chuyển các đánh giá cũ sang hiển thị.

Danh sách quản trị, phản hồi, xóa và duyệt/ẩn cần vai trò `Admin,Manager,Reception` cùng quyền hiện hành `REVIEW.MODERATE`. Migration `11_ReviewManagement.sql` thêm `IsDeleted`, `Reply`, `ReplyAccountId` (FK tài khoản), `RepliedAt`, `Version`; chạy nhiều lần an toàn, tích hợp script gốc, không thêm bảng hay sửa bình luận cũ. Local đã chạy hai lần: 28 bảng, số dòng và checksum mọi cột cũ không đổi. Không thêm audit log riêng hoặc lưu lịch sử nội dung phản hồi trong phạm vi này.

Kiểm chứng: 373/373 kiểm thử đạt, build 0 cảnh báo/0 lỗi. Có HTTP tích hợp cô lập kiểm tra anonymous401, Customer403, Reception thiếu quyền403, Admin/Reception có quyền truy cập; các lệnh trên ID thiếu trả404 sau khi qua quyền. 9 kiểm tra SQL cô lập đạt, gồm tạo schema mới/idempotence, query/filter+aggregate quản trị, optimistic concurrency409 và xóa mềm không khôi phục. DB thử đã xóa; không chỉnh sửa đánh giá thật. Báo cáo ngắn gửi thành viên Web: `BAO_CAO_QUAN_LY_DANH_GIA_WEB.md`; Web hiện thiếu bộ lọc dịch vụ/thời gian, xem bản ẩn/xóa, phản hồi CSDL và adapter đọc `items`. Chưa sửa Web/Flutter, chưa commit/push.

Cập nhật cấu hình ảnh cùng ngày: đã điền khóa Cloudinary vào file local được Git bỏ qua; kiểm tra thật đăng nhập 200, upload 201 và URL ảnh trả 200. Không ghi khóa vào tài liệu/Git.

Kiểm tra HTTP cuối trên SQL local bằng API thử cổng 5242: đăng nhập 200; danh sách quản trị 200; số sao không hợp lệ 400; danh sách công khai 200; phản hồi/xóa trên ID không tồn tại 404; đăng xuất 204. Không đổi đánh giá thật, không gửi email/push; API thử đã dừng, giữ nguyên phiên người dùng ở cổng 5230. Tiến trình chính bị SSPI do ngữ cảnh Windows của môi trường chạy; kiểm chứng bằng worker kết nối SQL local thành công.


## 14. Thống kê và báo cáo

Chi tiết bàn giao thống kê:

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

Kiểm chứng: xem kết quả kiểm thử đợt báo cáo; không gửi thông báo, không sửa dữ liệu tài chính để thử nghiệm.

Kiểm chứng đợt này: **403/403 test đạt**, build 0 cảnh báo/0 lỗi; gồm HTTP phân quyền và thu hồi quyền `REPORT.READ`, bộ lọc, kỳ báo cáo và XLSX. File XLSX được đọc độc lập bằng openpyxl, giữ đúng tiếng Việt/số và nội dung bắt đầu bằng dấu `=` vẫn là văn bản.

**SQL12 CHƯA áp dụng vào database local.** Kết nối kiểm thử SQL Server bị `Failed to generate SSPI context` trước khi tạo database; chưa kiểm chứng truy vấn SQL thực hoặc chạy migration hai lần. Không sửa dữ liệu thật. Trước khi chạy API bản mới, anh mở `DB_KLCN021/12_ReportingCustomerCreatedAt.sql` trong SSMS, kết nối SQL Server đang dùng rồi Execute (F5); sau đó khởi động lại API. File có `USE KLCN021_HealthBeauty`, chỉ thêm cột/index, không gán ngày giả cho khách cũ.
