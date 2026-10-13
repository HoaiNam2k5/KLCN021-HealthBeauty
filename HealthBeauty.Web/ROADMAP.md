# ROADMAP – HealthBeauty Web (KLCN021)
Cập nhật 10/10/2026. Hạn nộp 08/11/2026. File này + HANDOFF.md + .clinerules là toàn bộ "bộ nhớ" của dự án.

## 0. Cách dùng
Mỗi task: (1) làm "Git đầu task", (2) mở TASK MỚI trong Cline (dấu +, chế độ Act), (3) gửi MỘT câu: `Đọc .clinerules, HANDOFF.md, ROADMAP.md (mục 1 Quy tắc chung). Làm Task <số> trong ROADMAP.md.` (4) test theo checklist, (5) "Git cuối task".
Nếu Cline đứng quá 3 phút: xem 9Router > Console Log (dòng đỏ `stream stall timeout` = lỗi nhà cung cấp). Cancel, mở task mới, chia nhỏ task.

## 1. Quy tắc chung (Cline phải tuân theo ở MỌI task)
- Đọc swagger.json bằng `curl.exe` (chỉ GET) để lấy đường dẫn và body thật của nhóm endpoint liên quan; Swagger là chuẩn, KHÔNG đoán tên trường; báo cáo endpoint nào còn thiếu. Response danh sách của API là mảng trơn.
- Dùng lại ManagementTable, apiError, React Query, theme (src/theme/theme.ts), mẫu của Dịch vụ/Lịch hẹn.
- Tên trường giữ nguyên theo API (có chỗ tiếng Anh, có chỗ tiếng Việt như Staff), ánh xạ ở lớp API nếu cần.
- Mỗi trang đủ trạng thái loading, lỗi, rỗng. Ghi thành công/thất bại có thông báo; xóa có xác nhận. 403 hiện "Bạn không có quyền thực hiện thao tác này"; 400/409 hiện thông báo từ API.
- Quyền hiển thị theo role (Admin, Manager, Reception, Staff). Quyền cụ thể trong từng task là GIẢ ĐỊNH, backend vẫn là nơi kiểm tra thật.
- Tiền hiển thị VND, ngày dd/MM/yyyy HH:mm. Số tiền do backend tính, frontend chỉ hiển thị.
- KHÔNG gọi POST/PUT/PATCH/DELETE từ terminal/script, NGOẠI TRỪ một lần POST /auth/login bằng tài khoản demo trong .clinerules để lấy token vào biến tạm cho các lệnh GET (xóa biến sau khi dùng). Không lưu token/mật khẩu vào file.
- KHÔNG cài package ngoài .clinerules (trừ khi task cho phép rõ), KHÔNG sửa backend, KHÔNG git push, KHÔNG git switch/checkout. Ghi file bằng công cụ sửa file, không dùng Set-Content/Out-File.
- Cuối task: chạy `npm run build` và `npm run lint`, sửa hết lỗi, báo kết quả ngắn gọn: đã làm gì, chưa làm gì, giả định nào. Gợi ý commit message.

## 2. Bật môi trường (mỗi lần mở máy)
1. 9Router (xem Console Log không có dòng đỏ).
2. API: PowerShell NGOÀI VS Code: `cd C:\Users\PC\KLCN021-HealthBeauty\HealthBeauty.Api` rồi `dotnet run` (cổng 5230). Nếu lỗi SQL: bật dịch vụ `SQL Server (SQLEXPRESS)`.
3. VS Code: File > Open Recent > KLCN021-HealthBeauty-Web (thanh tiêu đề phải đúng tên). Tab powershell: `git status`, `git branch`, `npm run dev` (cổng 5173).
4. Khôi phục dữ liệu demo: SSMS, mở `DB_KLCN021\02_SeedData.sql`, Execute.
Tài khoản demo (local): admin@, reception@, customer@healthbeauty.local, mật khẩu như trong .clinerules.

## 3. Git
- Đầu task: `git switch main` > `git switch -c feature/<ten>` > `git branch` (dấu * đúng nhánh).
- Cuối task: `git status`, `git add .`, `git commit -m "<type>(<scope>): <mô tả tiếng Anh>"`, rồi `git switch main` > `git merge feature/<ten>`.
- Không push khi chưa hỏi Nam (repo web chưa lên GitHub). Không commit .env, token.

## 4. Lịch gợi ý (web xong tuần 11, tuần 12 dành cho báo cáo)
- Tuần 9 (12–18/10): 3c, 4a, 4b, 5
- Tuần 10 (19–25/10): 6, 7, 8
- Tuần 11 (26/10–1/11): 3b (nếu Nam xong), 9, 10, ghép với app Flutter
- Tuần 12 (2–8/11): 11 kiểm thử + báo cáo + slide, nộp 08/11

## 4b. Tiến độ và sự thật đã xác nhận (cập nhật sau Task 4b)
- Đã xong: Task 1 (auth), 2 (dịch vụ), 3a (Lịch hẹn: danh sách, chi tiết, đổi trạng thái, đổi lịch, sửa, xóa), 4a (Khách hàng chỉ đọc, Nhân viên CRUD), 4b (Lịch làm việc, cần test rồi commit).
- Khách hàng: backend chỉ có GET /customers?keyword= và PUT /customers/me (khách tự sửa). KHÔNG có PUT/DELETE theo id, nên màn Khách hàng chỉ đọc. Task 4a ở dưới đã được thay bằng phạm vi này.
- Lịch làm việc: GET trả tên TIẾNG VIỆT (lichLamViecId, nhanVienId, staffName, ngayLam yyyy-MM-dd, gioBatDau/gioKetThuc HH:mm:ss, trangThai); WorkScheduleRequest ghi tên TIẾNG ANH (staffId, workDate, startAt, endAt, status). Giá trị status duy nhất xác nhận: HoatDong. Seed có 15 ca (05/10 đến 09/10, 09:00–17:00), đều đã qua nên thử Đổi lịch phải thêm ca ngày tương lai.
- Sự cố Cline: nếu báo "PLAN MODE ... file modifications are blocked" dù nút Act đang sáng: bấm Plan rồi Act lại; hoặc Cancel, mở task mới, hỏi "Bạn đang ở Plan hay Act?"; hoặc Developer: Reload Window; hoặc cập nhật phần mở rộng Cline.
- Commit/merge xong mỗi task trước khi mở task mới. Đặt ROADMAP.md và HANDOFF.md đã commit để `git add .` không kéo file lạ.

## 5. Danh sách task

### Task 3c – Chốt Lịch hẹn (nhánh feature/appointments)
Việc cần làm: kiểm tra ký tự lạ (`Select-String -Path src\features\appointments\*.tsx -Pattern "[\x00-\x08\x0B\x0C\x0E-\x1F]"`, `git diff --check`), test Phần B, rồi commit `feat(appointments): complete appointment details and actions`, merge main.
Test (admin): B1 mở chi tiết lịch id 3; B2 bấm Xác nhận lịch id 3 (nếu backend báo lỗi, GHI NGUYÊN VĂN để tìm giá trị trạng thái thật); B3 chỉ hiện nút bước tiếp theo; B4 lịch id 2 (đã hoàn thành) không có nút xóa/đổi trạng thái; B5 sửa ghi chú id 4; B6 đổi lịch id 4 (available-slots rỗng thì phải cho nhập giờ tự do); B7 xóa rồi Hủy: không mất; B8 xóa thật; B9 reception thử đổi trạng thái (cho ghi hay 403, ghi lại). Test xong chạy lại 02_SeedData.sql.

### Task 4a – Khách hàng + Nhân viên (nhánh feature/customers-staff)
Prompt bổ sung:
```
Làm màn hình Khách hàng và Nhân viên.
- Customer (GET /customers?keyword=): id, fullName, phone, gender, rewardPoints; UpdateCustomerRequest { fullName, phone, gender }.
- Staff GET trả tên TIẾNG VIỆT: nhanVienId, hoTen, chucVu, chuyenMon, soDienThoai, ngayVaoLam (yyyy-MM-dd). StaffRequest (POST /staff, PUT /staff/{id}) dùng tên TIẾNG ANH: fullName, position, specialty, phone, hireDate. Ánh xạ: fullName←hoTen, position←chucVu, specialty←chuyenMon, phone←soDienThoai, hireDate←ngayVaoLam, gửi chuỗi yyyy-MM-dd. Tạo trường id = nhanVienId ở lớp ánh xạ cho ManagementTable.
1) Khách hàng: danh sách, tìm theo tên/SĐT, hiện điểm thưởng, sửa (fullName, phone, gender); xóa chỉ khi Swagger có endpoint.
2) Nhân viên: danh sách, tìm theo tên, lọc theo chức vụ, thêm, sửa, xóa (nếu Swagger có), kiểm tra bắt buộc và SĐT hợp lệ.
3) Menu và route. Quyền (giả định): Khách hàng: Admin/Manager/Reception xem và sửa, Staff chỉ xem. Nhân viên: Admin/Manager thêm/sửa/xóa, còn lại xem.
```
Test: 4 khách (có asd123, Nguyễn Minh Anh 155 điểm), tìm "Mai"; 3 nhân viên; thêm 1 nhân viên rồi F5 xem dữ liệu đúng (chỗ dễ lỗi nhất vì đọc/ghi khác tên trường); sửa; reception: sửa được khách, bị chặn ở nhân viên.
Commit: `feat(customers): add customer and staff management`.

### Task 4b – Lịch làm việc (nhánh feature/work-schedules)
Prompt bổ sung:
```
Làm màn hình Lịch làm việc nhân viên. Swagger: GET /staff/schedules (query staffId, from, to kiểu DateOnly), POST /staff/schedules, PUT và DELETE /staff/schedules/{id}. WorkScheduleRequest: staffId, workDate (DateOnly), startAt (TimeOnly), endAt (TimeOnly), status (string). Swagger khai DateOnly/TimeOnly dạng object nhưng JSON thật có thể là chuỗi "yyyy-MM-dd" / "HH:mm:ss": hãy kiểm tra bằng curl.exe GET một lịch làm việc thật rồi gửi đúng định dạng đó.
1) Danh sách theo nhân viên và khoảng ngày (mặc định tuần hiện tại), nhóm theo ngày.
2) Thêm, sửa, xóa ca làm (chọn nhân viên, ngày, giờ bắt đầu/kết thúc; kiểm tra giờ kết thúc sau giờ bắt đầu và không trùng ca của cùng nhân viên cùng ngày).
3) Quyền: Admin/Manager ghi; Reception/Staff chỉ xem. status: lấy giá trị từ dữ liệu seed (đừng tự đặt).
```
Test: xem lịch tuần; thêm ca; thêm ca trùng giờ phải bị chặn; sửa; xóa. Sau khi có lịch làm việc cho ngày 12/10 trở đi, mở lại Lịch hẹn > đổi lịch: xem available-slots còn rỗng không (nếu vẫn rỗng, ghi vào danh sách báo Nam).
Commit: `feat(staff): add work schedule management`.

### Task 5 – Hóa đơn + Thanh toán (nhánh feature/billing)
Prompt bổ sung:
```
Làm màn hình Hóa đơn và Thanh toán. Đọc Swagger nhóm invoices/payments, báo endpoint thật. Đã biết: CreateInvoiceRequest { appointmentId, items[{ serviceId|null, comboId|null, quantity }], voucherCode, pointsToRedeem }; PaymentRequest { method, status }. Thanh toán hiện chỉ ghi nhận trạng thái, chưa tích hợp VNPay/MoMo.
1) Danh sách hóa đơn (tìm theo khách, lọc theo trạng thái thanh toán và ngày), chi tiết hóa đơn (dòng dịch vụ, giảm giá, điểm đã dùng, tổng tiền, phương thức).
2) Tạo hóa đơn từ lịch hẹn đã hoàn thành (chọn lịch HoanThanh, dòng dịch vụ lấy từ lịch, nhập voucher và điểm đổi nếu muốn). Tiền do backend tính, chỉ hiển thị kết quả.
3) Ghi nhận thanh toán (method, status) cho hóa đơn. method/status lấy giá trị thật từ dữ liệu seed.
4) Nút "In/Xuất" có thể dùng window.print() cho trang chi tiết hóa đơn (không cài package).
5) Quyền (giả định): Admin/Manager/Reception tạo và thanh toán; Staff chỉ xem.
```
Test: 2 hóa đơn demo hiện đúng; tạo hóa đơn từ lịch id 2 (lưu ý có thể đã có hóa đơn: nếu 409 thì thông báo rõ); ghi nhận thanh toán; điểm thưởng khách đổi theo (kiểm tra ở trang Khách hàng).
Commit: `feat(billing): add invoice and payment screens`.

### Task 6 – Khuyến mãi + Voucher + Điểm thưởng (nhánh feature/promotions)
```
Làm màn hình Khuyến mãi và Voucher. Đọc Swagger nhóm promotions/vouchers. Đã biết: PromotionRequest { name, discountType, discount, condition, startsAt, endsAt }; VoucherRequest { code, promotionId, customerId|null, discountValue, expiresAt }. discountType lấy giá trị từ dữ liệu seed.
1) Khuyến mãi: danh sách, thêm/sửa/xóa, lọc đang diễn ra/hết hạn (tính từ startsAt/endsAt), kiểm tra endsAt sau startsAt.
2) Voucher: danh sách, thêm/sửa/xóa (nếu Swagger có), chọn khuyến mãi và (tùy chọn) khách, hiện trạng thái đã dùng/hết hạn, mã voucher không trùng.
3) Điểm thưởng: hiển thị ở trang Khách hàng (rewardPoints); chỉ thêm tính năng đổi/cộng điểm nếu Swagger có endpoint riêng.
Quyền (giả định): Admin/Manager ghi; còn lại xem.
```
Test: tạo khuyến mãi, tạo voucher gắn khuyến mãi, thử nhập voucher đó ở Task 5, thử voucher hết hạn.
Commit: `feat(promotions): add promotion and voucher management`.

### Task 7 – Đánh giá (nhánh feature/reviews)
```
Làm màn hình Đánh giá dịch vụ/nhân viên. Đọc Swagger nhóm reviews (ReviewRequest { stars, comment } có thể là phía khách hàng). Chỉ làm những gì có endpoint đọc danh sách: danh sách đánh giá, lọc theo số sao, theo dịch vụ/nhân viên (nếu dữ liệu có), thống kê sao trung bình, ẩn/xóa đánh giá nếu Swagger có endpoint. Nếu không có endpoint GET danh sách, dừng và báo tôi để nhờ backend, đừng giả lập.
```
Commit: `feat(reviews): add review management`.

### Task 8 – Báo cáo / Dashboard (nhánh feature/reports)
```
Làm trang Báo cáo và Trang chủ dashboard. Đọc Swagger nhóm reports/statistics. Nếu có endpoint thống kê thì dùng; nếu không, tính trên giao diện từ danh sách hiện có (lịch hẹn, hóa đơn, khách hàng) và GHI RÕ trong giao diện là "tính ở phía giao diện".
Hiển thị: tổng lịch hẹn theo trạng thái, doanh thu theo ngày/tháng (từ hóa đơn đã thanh toán), top dịch vụ, khách mới. Bộ lọc khoảng ngày. Được phép cài đúng gói `recharts` (đã có trong .clinerules) để vẽ biểu đồ; không cài gì khác.
Quyền (giả định): Admin/Manager xem; còn lại không thấy menu.
```
Commit: `feat(reports): add dashboard and reports`.

### Task 9 – Phân quyền (tùy chọn, nhánh feature/permissions)
```
Nếu Swagger có nhóm roles/permissions (RolePermissionRequest { permissionId, granted }): làm màn hình ma trận Vai trò x Quyền (5 vai trò, 18 quyền trong seed), bật/tắt quyền, chỉ Admin truy cập. Nếu thiếu endpoint thì báo, không làm.
```
Commit: `feat(permissions): add role permission matrix`.

### Task 3b – Form tạo lịch hẹn (CHỜ NAM)
Điều kiện: backend thêm `customerId` và `staffId` vào `CreateAppointmentRequest`, sửa `GET /appointments/{id}` (đang 500), thêm schema `available-slots`. Khi có: form chọn khách, dịch vụ/combo (kèm expectedPrice), nhân viên, ngày giờ; gọi available-slots trước khi lưu; 409 trùng lịch báo rõ; quyền Admin/Manager/Reception. Commit `feat(appointments): add create appointment form`.

### Task 10 – Hoàn thiện (nhánh chore/polish)
```
1) Giảm bundle (hiện >1MB): React.lazy + Suspense cho từng trang, đo lại bằng npm run build.
2) Trang 404, trang 403, tiêu đề tab theo trang, favicon.
3) Responsive cơ bản (sidebar thu gọn trên màn hình hẹp).
4) Rà soát: mọi trang đủ loading/lỗi/rỗng, thông báo tiếng Việt nhất quán, không còn console.log, không có chỗ hardcode URL/mật khẩu.
5) Tạo .env.example (VITE_API_BASE_URL), viết README.md cho web: cài đặt, chạy, cấu trúc thư mục.
Không đổi hành vi nghiệp vụ.
```
Commit: `chore: polish ui, lazy load and docs`.

### Task 11 – Kiểm thử + báo cáo
- Chạy lại toàn bộ checklist của Task 3c đến 8 trên dữ liệu seed mới. Với mỗi task lập bảng: Mã TC | Chức năng | Các bước | Kết quả mong đợi | Kết quả thực tế | Đạt/Không | Ghi chú. Chụp màn hình lưu vào thư mục `report-screens/` (đặt tên theo task). Có thể nhờ Claude xuất bảng này ra Excel.
- Chạy `npm run build` và `npm run lint` lần cuối, chạy thử bản build bằng `npm run preview`.

## 6. Xử lý sự cố
- `ERR_CONNECTION_REFUSED` ở localhost:5173: chưa chạy `npm run dev` hoặc VS Code mở sai thư mục. localhost:5230 lỗi: API chưa chạy.
- Terminal báo `Missing script: dev` hoặc `not a git repository`: đang đứng sai thư mục (kiểm tra dấu nhắc `PS C:\Users\PC\KLCN021-HealthBeauty-Web>`).
- Trang trắng: F12 > Console đọc dòng đỏ; nhờ Cline sửa kèm dòng lỗi đó.
- Cline hỏng giữa chừng: `git status`, rồi `git restore .` (bỏ thay đổi file đã sửa) và `git clean -fd src` (xóa file mới), CHỈ dùng khi chắc chắn không cần gì từ lượt đó.
- Chữ lạ kiểu `TÃ¬m` trong terminal: chỉ là lỗi hiển thị của PowerShell 5.1, file vẫn đúng.
- Mất dữ liệu demo: chạy lại 02_SeedData.sql.
- Đừng gửi cho ai (kể cả chat) khóa JWT, connection string thật, token. Mật khẩu demo trong .clinerules chỉ dùng local.

## 7. Cần Nam xử lý (gửi nguyên văn)
1) POST /appointments thiếu customerId và staffId. 2) GET /appointments thiếu bộ lọc (from, to, status, staffId, keyword) và phân trang. 3) Cần danh sách trạng thái lịch hẹn và luồng chuyển hợp lệ (enum trong Swagger); xác nhận giá trị DaXacNhan, KhachDaDen, DangThucHien, DaHuy. 4) GET /appointments/{id} trả 500 (id 3, 4). 5) StaffRequest tên tiếng Anh nhưng GET /staff tên tiếng Việt: thống nhất. 6) available-slots luôn rỗng và thiếu schema response (cả appointments/{id}, staff, staff/{id}/appointments). 7) Catalog lệch code; chưa có API đổi/quên mật khẩu, kho, báo cáo (nếu thiếu). 8) Dữ liệu thử "asd123". 9) Cần PUT /customers/{id} (lễ tân sửa khách; hiện chỉ có PUT /customers/me), tùy chọn DELETE. 10) GET /staff/schedules: Swagger thiếu schema response; response tên tiếng Việt nhưng WorkScheduleRequest tên tiếng Anh. 11) available-slots vẫn rỗng ngay cả ngày có ca làm (08/10, nhân viên 2).

## 8. Báo cáo (chương còn thiếu)
- Chương 4 – Cài đặt: kiến trúc triển khai (Web React + API ASP.NET Core + SQL Server + Flutter), môi trường, cấu trúc mã nguồn web, luồng xác thực JWT + refresh, các màn hình (mỗi task một mục, ảnh chụp từ report-screens/), đoạn mã tiêu biểu (interceptor refresh, phân quyền route, ánh xạ dữ liệu).
- Chương 5 – Kiểm thử: bảng test case từ Task 11, thống kê đạt/không đạt, lỗi tìm thấy và cách xử lý (kể cả lỗi backend đã báo).
- Chương 6 – Kết luận: đã làm được gì, hạn chế (thanh toán chưa tích hợp cổng, kho/đổi mật khẩu chưa có API, refresh token lưu localStorage có rủi ro XSS, bundle lớn), hướng phát triển.
- Điểm cần nhất quán: tài liệu ghi React (không phải Angular); sửa mục 2.1.3 và các sơ đồ kiến trúc trong báo cáo HK1 cho khớp. Tên trường API theo Swagger, cập nhật lại API Catalog.
- Khi bảo vệ: chuẩn bị giải thích được luồng refresh token, phân quyền ở web vs backend, vì sao lọc phía client (API chưa hỗ trợ), và vì sao thanh toán chỉ ghi nhận trạng thái.

## 9. Khi quay lại chat với Claude
Dán: "Mình đang làm khóa luận KLCN021 (HealthBeauty, web React + API ASP.NET). Đây là HANDOFF.md và ROADMAP.md. Mình đã xong đến Task __. Hiện gặp: __ (kèm ảnh hoặc dòng lỗi)." rồi đính kèm hai file.
