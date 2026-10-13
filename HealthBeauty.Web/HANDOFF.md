# HANDOFF – HealthBeauty Web (cập nhật 04/10/2026)

## 1. Bật môi trường sau khi mở máy
1. Bật 9Router. Nếu Cline đứng ở "Thinking...", xem 9Router > Console Log: dòng đỏ `stream stall timeout` là lỗi nhà cung cấp (chờ rồi thử lại, hoặc đổi model).
2. API (PowerShell NGOÀI VS Code): `cd C:\Users\PC\KLCN021-HealthBeauty\HealthBeauty.Api` rồi `dotnet run` (cổng 5230). SQL Server: dịch vụ `SQL Server (SQLEXPRESS)` phải chạy.
3. Web: mở thư mục `C:\Users\PC\KLCN021-HealthBeauty-Web`, tab powershell: `npm run dev` (cổng 5173).
4. Mẹo Cline: mỗi tính năng mở TASK MỚI (dấu +), chia nhỏ, lệnh chỉ đọc thì duyệt; từ chối git push, Remove-Item, npm install, `-Method Post/Put/Patch/Delete`. Dấu tiếng Việt lạ (TÃ¬m...) trong output PowerShell 5.1 chỉ là lỗi hiển thị. Yêu cầu Cline ghi file bằng công cụ sửa file, không dùng Set-Content.

## 2. Git
- Quy ước theo CONTRIBUTING.md: nhánh `feature/<ten>`, commit Conventional (tiếng Anh), không commit trực tiếp lên main, không push.
- Đã có: `feature/app-foundation` (auth), `feature/service-management` (dịch vụ), `feature/appointments` (đang làm).
- Kiểm tra: `git status`, `git log --oneline -8`. Task 2 chưa commit/merge thì commit trước.

## 3. Tiến độ
- Task 1 xong: đăng nhập, refresh token, đăng xuất, phân quyền, layout.
- Task 2 xong và đã test: loại dịch vụ, dịch vụ, combo (phân trang/lọc phía client).
- Task 3 (Lịch hẹn) đang dở, chưa chắc đã có file nào. Làm 3a-1 → 3a-2 → 3a-3, form tạo lịch (3b) chờ backend.
- Task kế tiếp gợi ý: Khách hàng; Nhân viên + lịch làm việc; Hóa đơn/thanh toán; Khuyến mãi/voucher; Đánh giá; Báo cáo; Kho (backend chưa có).

## 4. Sự thật về API (Swagger là chuẩn, catalog lệch)
- `GET /appointments` trả MẢNG TRƠN (dạng {value,Count} thấy trong PowerShell 5.1 chỉ là hiện tượng ConvertTo-Json).
- AppointmentResponse: id, customerId, staffId (có thể null), appointmentAt (ISO), status (string), note, items[{id, serviceId, serviceName, comboId|null, expectedPrice}].
- PUT `/appointments/{id}` và POST `/appointments/{id}/reschedule` cùng body `{ appointmentAt, staffId|null, note|null }`.
- PATCH `/appointments/{id}/status` body `{ status }`.
- GET `/appointments/available-slots?date=yyyy-MM-dd&staffId=` (response chưa có schema; thử 2 ngày đều rỗng).
- Staff GET trả tên trường TIẾNG VIỆT: nhanVienId, hoTen, chucVu, chuyenMon, soDienThoai, ngayVaoLam. Customer: id, fullName, phone, gender, rewardPoints.
- Trạng thái xác nhận từ seed: `ChoXacNhan`, `HoanThanh`. Còn lại (DaXacNhan, KhachDaDen, DangThucHien, DaHuy) CHƯA xác nhận, ghi TODO.
- Quyền "chỉ Admin/Manager ghi" (dịch vụ) là giả định, chưa kiểm chứng với backend.

## 5. Gửi Nam (lỗi/thiếu backend)
1. `POST /appointments` thiếu `customerId` và `staffId` (lễ tân chưa đặt lịch hộ khách được).
2. `GET /appointments` chưa có bộ lọc (from, to, status, staffId, keyword) và phân trang.
3. Cần danh sách trạng thái hợp lệ và luồng chuyển (enum trong Swagger).
4. `GET /appointments/{id}` trả 500 với id seed 3 và 4.
5. `GET /staff` đọc tiếng Việt nhưng `StaffRequest` ghi tiếng Anh (fullName, position...): thống nhất tên trường.
6. `available-slots` luôn trả rỗng; thiếu schema response cho available-slots, appointments/{id}, staff, staff/{id}/appointments.
7. Catalog lệch code (password/account...); API auth chưa có đổi mật khẩu, quên mật khẩu; chưa có API kho.
8. Có khách thử "asd123" trong dữ liệu.

## 6. Task 3a-1 (dán vào Cline TASK MỚI, chế độ Act)
Đọc `.clinerules` và mục 4 của HANDOFF.md. Nhánh `feature/appointments`. Chỉ làm phần 1, chưa làm giao diện:
1) `src/types/appointments.ts` theo mục 4.
2) `src/api/appointments.ts`: GET list/staff/customers/available-slots; PUT, PATCH status, POST reschedule, DELETE theo mục 4. Đọc danh sách giống `src/api/services.ts`.
3) `src/features/appointments/appointmentQueries.ts` (React Query, theo mẫu serviceQueries.ts).
4) `src/features/appointments/appointmentStatus.ts`: nhãn tiếng Việt, màu theo bảng trạng thái trong `.clinerules`, luồng ChoXacNhan → DaXacNhan → KhachDaDen → DangThucHien → HoanThanh, hủy được trước khi hoàn thành; giá trị lạ hiển thị nguyên chuỗi màu trung tính.
Không gọi lại API khảo sát, không gọi mutation thật, không cài package, không sửa backend, không git push. Chạy `npm run build` và `npm run lint` rồi báo kết quả.

## 7. Task 3a-2 / 3a-3 (sau khi 3a-1 đạt)
- 3a-2: trang danh sách `AppointmentsPage` (lọc ngày/trạng thái/nhân viên, tìm theo khách, hiện tên khách và tên nhân viên thay vì id, thẻ trạng thái), route và menu, dùng lại ManagementTable/apiError.
- 3a-3: chi tiết (mở từ dòng danh sách), đổi trạng thái (chỉ nút hợp lệ), đổi lịch (nếu available-slots rỗng thì cho nhập giờ tự do và báo rõ), sửa ghi chú/nhân viên, xóa có xác nhận. Quyền: Admin/Manager/Reception được ghi, Staff chỉ xem.
- Test: admin thấy 3 lịch (2 chờ xác nhận, 1 hoàn thành); thử xác nhận một lịch để biết `DaXacNhan` có đúng không; reception ghi được, staff chỉ xem. Chạy lại `02_SeedData.sql` để khôi phục dữ liệu demo.

## 8. Lưu ý cho báo cáo
- Refresh token lưu localStorage: nêu rủi ro XSS. Catalog API lệch code và đã báo backend. Thanh toán chỉ ghi trạng thái, chưa có VNPay/MoMo.
- Backend chưa có kho, đổi/quên mật khẩu: ghi rõ phạm vi và hướng phát triển.
