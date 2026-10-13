> **Cập nhật mới nhất:** các lỗi token/khóa đăng nhập, quyền động, điểm/hóa đơn0, voucher, combo và Staff đã được sửa tiếp. Kết quả146test pass và trạng thái còn tồn tại hiện tại xem `API_FOLLOWUP_FIXES.md`. Nội dung đợt trước bên dưới là lịch sử, không phải trạng thái mới nhất.

> **Cập nhật sau sửa API ưu tiên (13/10/2026):** đã sửa lỗi JSON chi tiết lịch hẹn/nhân viên, xác nhận thanh toán chỉ dành cho Admin/Manager/Reception, đối chiếu hóa đơn với lịch hoàn thành, chặn hủy/đổi lịch sai trạng thái, tính giờ trống theo thời lượng và kiểm tra ca làm. Chi tiết hiện tại: `API_PRIORITY_FIXES.md`. Nội dung audit bên dưới là bằng chứng **trước khi sửa**; số dòng và mô tả lỗi đã sửa không còn phản ánh mã hiện tại. `API_AUDIT_HTTP.json` chứa kết quả HTTP mới nhất. Lỗi token tài khoản bị khóa, quyền động, điểm/voucher và các mục khác chưa được xử lý trong đợt này.

# Rà soát API HealthBeauty — 13/10/2026

## Phạm vi và phương pháp

Repo: `D:/KhoaLuan/DEV/KLCN021_HealthBeauty`, branch `fix/appointment-api-contract`.
Đã rà 9 file controller, DTO, auth/middleware, mô hình EF và schema SQL; đối chiếu catalog và nghiệp vụ hiện tại. **Không xét kho và bán sản phẩm.** Không sửa mã nguồn ứng dụng trong lượt rà này; giữ nguyên các thay đổi từ lần sửa Flutter trước.

Swagger hiện công bố **71 thao tác**: 31 GET, 17 POST, 11 PUT, 4 PATCH, 8 DELETE. Đã gọi toàn bộ 31 GET qua HTTP với SQL Server local: **28 trả 200, 2 trả 500, 1 trả 404**. 404 ở quyền của role ID 1 chỉ phản ánh ID thử không có dữ liệu, không coi là lỗi. GET thành công không chứng minh mọi trường hợp lọc/phân quyền đều đúng.

Đã chạy **12 test chứng minh hành vi lỗi** trên các database EF InMemory tách biệt. Các test này pass vì xác nhận lỗi hiện đang xảy ra, không có nghĩa API đã được sửa. 17 test regression của lần sửa trước vẫn là bộ kiểm tra riêng. Không POST/PUT/PATCH/DELETE vào database SQL đang dùng của nhóm.

Bằng chứng HTTP: `API_AUDIT_HTTP.json`. Bộ tái hiện: `.audit/AuditEvidenceTests.cs`; chạy `dotnet test .audit/HealthBeauty.Api.Audit.csproj`. Script đọc HTTP: `.audit/HttpAudit.ps1` (chỉ dùng key kiểm tra ngẫu nhiên trong process, không thay cấu hình lưu trên máy).

## Lỗi cần sửa trước

| Mức | API/vị trí | Lỗi và ảnh hưởng | Bằng chứng |
|---|---|---|---|
| P1 | GET `/appointments/{id}` — `SupplementControllers.cs:19–23` | Trả entity chứa khách/nhân viên/chi tiết với navigation ngược, JSON có vòng tham chiếu; màn hình chi tiết không dùng được. Cần response DTO có cấu trúc hữu hạn. | HTTP 500; test `Evidence_AppointmentDetailHasJsonCycle` ném JsonException. |
| P1 | GET `/staff/{id}` — `SupplementControllers.cs:99` | Có ca làm thì entity nhân viên ↔ ca làm tạo vòng JSON. | HTTP 500; test `Evidence_StaffDetailWithShiftHasJsonCycle`. |
| P1 | POST `/invoices/{id}/payments` — `InvoicesController.cs:73–88` | Khách tự gửi `method=TienMat,status=ThanhCong` thì hóa đơn được đánh dấu đã trả và có thể cộng điểm, không cần xác nhận từ lễ tân hay cổng thanh toán. Phải phân biệt yêu cầu thanh toán của khách và quyền xác nhận đã thu tiền. | Test khách tự xác nhận thành công. README xác nhận chưa tích hợp cổng thu tiền. |
| P1 | POST `/invoices` — `InvoicesController.cs:31–45` | Cho khách tạo hóa đơn cho lịch đã hủy/chưa hoàn thành, chọn dịch vụ khác rẻ hơn dịch vụ đã đặt. Không đối chiếu item với chi tiết lịch/chi phí phục vụ. | Test: lịch chứa dịch vụ giá 1.000, đã hủy; khách tạo hóa đơn dịch vụ khác giá 100 rồi tự xác nhận thanh toán. |
| P1 | DELETE `/appointments/{id}` — `SupplementControllers.cs:78–83` | Bỏ qua state machine ở PATCH; khách hủy được lịch đang thực hiện/đã hoàn thành. | Test hủy lịch HoanThanh thành DaHuy, trả 204. |
| P1 | POST reschedule / PUT appointment — `SupplementControllers.cs:27–35,62–74` | Đổi thời gian của lịch đã hoàn thành/đã hủy, vẫn giữ trạng thái cũ. Cần giới hạn trạng thái được sửa. | Test khách đổi lịch HoanThanh sang ngày/giờ tương lai, trả 200. |
| P1 | GET availability — `SupplementControllers.cs:87–91` | Một lịch 09:00–10:00 làm biến mất cả ca 09:00–17:00. Không tính thời lượng dịch vụ cần đặt, khoảng rảnh còn lại và lịch kéo từ hôm trước. | Test một lịch che toàn bộ ca; không còn slot dù sau 10:00 vẫn trống. |
| P1 | POST create / reschedule / PUT appointment | Chỉ kiểm tra nhân viên tồn tại và lịch va chạm; không kiểm tra có ca làm, nghỉ phép, giờ hoạt động hay chuyên môn. | Test đặt nhân viên lúc 03:00 ngoài ca 09:00–17:00 vẫn trả 201. |
| P1 | Khóa tài khoản — `AdministrationController.cs:55`, `Program.cs:23–36` | Khóa chỉ thu hồi refresh token. Access token đã cấp vẫn qua xác thực đến khi hết hạn vì middleware không kiểm tra trạng thái tài khoản. | Đối chiếu code; chưa thay trạng thái tài khoản thật để thử HTTP. |
| P1/P2 | API gán/thu hồi quyền — `AdministrationController.cs:26–38` | Bảng quyền được sửa nhưng quyền không được dùng khi authorize endpoint; hệ thống kiểm tra tên role cố định. Thu hồi SERVICE.WRITE chưa ngăn Manager sửa dịch vụ. | Tìm kiếm toàn code: không có authorization policy/handler thực thi QUYEN/VAITRO_QUYEN. |

## Lỗi nghiệp vụ và dữ liệu khác

| Mức | Vị trí | Phát hiện | Bằng chứng/đề nghị |
|---|---|---|---|
| P2 | `InvoicesController.cs:63–65` | Điểm giảm bị giới hạn bằng số tiền còn lại nhưng số điểm trừ không bị giới hạn. Ví dụ bill 100, dùng 200 điểm: giảm 100 mà mất 200. | Test số dư 500 → 300. Trừ đúng số điểm được áp dụng hoặc từ chối vượt giới hạn. |
| P2 | `InvoicesController.cs:67,83`; SQL:257 | Bill sau giảm bằng 0 được tạo nhưng thanh toán ghi SoTien=0, trái CHECK SoTien > 0 → lỗi SQL. | Test chứng minh insert amount 0; kết luận lỗi constraint từ schema, chưa ghi giao dịch vào SQL thật. |
| P2 | `AppointmentsController.cs:55` | GiaDuKien vẫn nhận giá client nếu >0; app có thể gửi 1 cho dịch vụ giá 1.000. Giá combo chưa được xác minh/tính thống nhất trên server. | Test lưu expectedPrice=1. Giá hóa đơn lấy lại DB nên không đồng nhất giá dự kiến/giá thu. |
| P2 | `AppointmentsController.cs:55`; SQL:217 | ComboId không được kiểm tra tồn tại/hiệu lực/dịch vụ thành phần. ID không tồn tại gây FK500; combo ngừng hoạt động hoặc không chứa dịch vụ có thể được nhận. | Code/schema; cần validate trước SaveChanges. |
| P2 | `CombosController.cs:32–36,47–51`; SQL:197 | Hai item trùng ServiceId qua kiểm tra Distinct rồi được thêm cả hai, trái UNIQUE(ComboID,DichVuID). | Code/schema; từ chối trùng hoặc gộp số lượng. |
| P2 | `SupplementControllers.cs:102` | PUT ca làm không kiểm tra nhân viên tồn tại hoặc trùng ca như POST; có thể tạo ca chồng lấn hoặc FK500. | Code/schema; dùng cùng validation cho create/update và loại trừ ca hiện tại. |
| P2 | `SupplementControllers.cs:100`; SQL:169,208 | Xóa nhân viên có ca làm hoặc chỉ có lịch đã hủy vẫn vướng FK; hiện chỉ kiểm tra lịch chưa hủy. | Code/schema; ưu tiên ngừng hoạt động, bảo toàn lịch sử. |
| P2 | `PromotionsController.cs:73` | PUT voucher thiếu kiểm tra FK, mã trùng, hạn sử dụng và quy tắc tương tự POST. | Sai promotion/customer ID hoặc duplicate Code có thể gây SQL500. |
| P2 | `PromotionsController.cs:37`; SQL:233 | Xóa khuyến mãi chỉ chặn voucher đang hoạt động; voucher đã dùng/đã khóa vẫn có FK và khiến xóa thất bại. | Code/schema; ngừng hiệu lực hoặc xử lý đúng mọi tham chiếu. |
| P2 | `CustomersController.cs:66` | Reception không được GET danh sách nhân viên dù được tạo lịch và phân công StaffId. | Attribute chỉ cho Admin, Manager, Customer. Cần bổ sung Reception để giao diện phân công hoạt động. |
| P2 | `AppointmentsController.cs:20–23`; `SupplementControllers.cs:22,95` | Role Staff không xem được lịch được phân công/ca cá nhân; trả [] hoặc 403. | Role đã có trong seed và báo cáo yêu cầu kỹ thuật viên tham gia. Cần API tự tra cứu theo hồ sơ nhân viên và kiểm tra quyền sở hữu. |
| P2 | `AppointmentsController.cs:23`, `SupplementControllers.cs:21`, `InvoicesController.cs:20,33,79` | Người quản trị/lễ tân có hồ sơ khách bị lọc/cấm theo customerId trước khi xét đầy đủ quyền quản trị. | Trường hợp nâng role từ Customer nhưng giữ hồ sơ. Cần xác định ưu tiên vai trò và phạm vi dữ liệu. |
| P2 | `AuthController.cs:36–38` | Đăng nhập sai không tăng bộ đếm, không khóa tạm, không ghi login log thất bại. | Test 5 lần sai: counter=0, KhoaDen=null, số log=0. |
| P2 | Tạo lịch/lập hóa đơn/thanh toán/voucher | Kiểm tra rồi SaveChanges không khóa hoặc kiểm soát concurrency xuyên suốt. Hai yêu cầu đồng thời có thể cùng vượt qua kiểm tra trùng lịch/hóa đơn/thanh toán hoặc dùng cùng voucher. | Rủi ro từ code/schema, **chưa tái hiện race**. Không coi các test tuần tự là bằng chứng chống race. |
| P2 | `InvoicesController.cs:57,64` | Voucher bị đánh dấu đã dùng và điểm bị trừ ngay khi lập bill; chưa có cơ chế hủy bill chưa thanh toán/khôi phục quyền lợi. | Cần xác định thời điểm dùng voucher/điểm và workflow hủy/hoàn tiền. |

Ngoài các lỗi trên, danh sách voucher của khách chưa đồng bộ việc kiểm tra ngày hiệu lực chương trình với validate/áp dụng voucher; khuyến mãi và điều kiện áp dụng mới chủ yếu là mô tả text. Cần thống nhất chính sách trước khi bổ sung logic, tránh gọi mọi chương trình trong thời gian hiệu lực là chắc chắn áp dụng được.

## API cần bổ sung cho phạm vi hiện tại

Ưu tiên các workflow đang bị đứt:

1. **Danh sách đánh giá chờ duyệt cho quản lý:** GET `/reviews` hiện luôn chỉ HienThi, kể cả Admin; đánh giá mới ChoDuyet không có API danh sách để tìm. Đề nghị GET `/admin/reviews?status=ChoDuyet` hoặc endpoint privileged riêng. Test xác nhận Admin nhận mảng rỗng khi có đánh giá chờ duyệt. Thêm detail/filter để quản lý xem và phản hồi nếu UI yêu cầu.
2. **Tạo khách vãng lai tại quầy:** POST `/customers` cho Reception/Manager/Admin, cho phép hồ sơ chưa có tài khoản; hiện chỉ có đăng ký tài khoản khách và sửa/list hồ sơ.
3. **API nhân viên tự xem việc:** GET `/staff/me/appointments`, GET `/staff/me/schedules`; quy định quyền kỹ thuật viên cập nhật các bước dịch vụ được giao. Không mở toàn bộ dữ liệu nhân viên cho role Staff.
4. **Cấp/liên kết tài khoản nhân viên và đổi role:** hiện tạo nhân viên không gắn tài khoản, Admin chỉ list/khóa tài khoản và gán quyền theo role; chưa có workflow cấp tài khoản kỹ thuật viên hoặc gán role người dùng.
5. **Chi tiết hóa đơn:** GET `/invoices/{id}` có quyền theo chủ sở hữu/nhân viên. List chỉ lấy 100 hóa đơn mới nhất nên không thay thế API lấy một hóa đơn lịch sử cụ thể.
6. **Đổi/quên/đặt lại mật khẩu:** chưa có `/auth/change-password`, `/auth/forgot-password`, `/auth/reset-password`. Có DTO ChangePasswordRequest nhưng chưa có controller action. Nếu giữ quên mật khẩu trên app cần token reset, hạn dùng và kênh gửi xác thực; không trả token bí mật cho client trong production.
7. **Hủy hóa đơn chưa trả/điều chỉnh giao dịch:** có kiểm tra quyền, trạng thái và khôi phục điểm/voucher khi phù hợp; thanh toán thực cần xác nhận bởi lễ tân hoặc callback được xác minh.
8. **Quản lý danh mục đã ngừng hoạt động:** list quản trị và mở lại service/category/combo. Public list chỉ hiển thị active; update hiện không có trường để mở lại.

Các bổ sung tùy phạm vi giao diện: upload/URL hình ảnh dịch vụ, phân hạng thành viên, phản hồi/sửa đánh giá, lọc báo cáo theo thời gian/nhân viên và xuất Excel/PDF. Xuất báo cáo có thể làm ở frontend nếu nhóm chọn cách đó. Thông báo từ server/FCM chỉ cần nếu nhóm muốn đẩy thông báo ngoài nhắc lịch cục bộ trên Flutter; không tự xem đây là phân hệ bắt buộc mới. Không cần bổ sung OAuth hoặc các endpoint của kho/bán sản phẩm cho lần rà này.

## Swagger và API Catalog

- Chỉ **12/71 thao tác** có schema cho response thành công trong Swagger; nhiều IActionResult không được khai báo response DTO/ProducesResponseType. Không phải mọi endpoint này đều lỗi runtime, nhưng ảnh hưởng sinh client và tích hợp.
- PATCH trạng thái vẫn nhận string không có enum/luồng chuyển trong Swagger.
- Catalog còn nhiều route/request/schema dự kiến khác code: password/account thay cho matKhau/user; combos thay service-combos; customers/me thay me; lịch làm việc dưới staff/schedules; trạng thái lịch dùng PATCH thay PUT; voucher validate dưới promotions và dùng POST; quyền/log/account dưới admin. Một số mục là chưa cài đặt, một số chỉ khác route, không nên báo tất cả là thiếu API.
- Cần tái sinh danh mục endpoint từ Swagger, thêm trạng thái “đã triển khai/dự kiến” và ghi schema đúng theo JSON thực tế; không bắt web/app dùng catalog cũ.

## Thứ tự xử lý đề nghị

1. Sửa hai GET500 bằng DTO; bảo vệ ghi nhận thanh toán và nguồn dữ liệu hóa đơn.
2. Chặn hủy/đổi lịch ở trạng thái cuối; sửa availability và kiểm tra ca làm; xử lý quyền Reception/Staff.
3. Sửa điểm thưởng/zero-total/voucher/constraint và thêm kiểm soát concurrency.
4. Hoàn thiện queue duyệt đánh giá, khách vãng lai, tài khoản nhân viên, chi tiết hóa đơn và mật khẩu.
5. Đồng bộ Swagger/catalog và kiểm thử xuyên suốt Flutter + web.

## Giới hạn của kết quả

Không tuyên bố đã kiểm thử mọi payload của 71 thao tác. 31 GET được thử trên SQL local; mutation được đọc code và chọn 12 ca tái hiện bằng InMemory. InMemory không thực thi constraint SQL nên các kết luận FK/UNIQUE/CHECK được ghi rõ là bằng chứng schema. Không thay trạng thái/tài chính hay thêm dữ liệu vào SQL đang dùng. Chưa test concurrency, cổng thanh toán, email/OTP hoặc app/web end-to-end. Mã nguồn API chưa được sửa thêm trong lượt rà này.
