# Healthbeauty Web

Web quản trị Healthbeauty xây dựng bằng React, TypeScript, Vite và Ant Design, dành cho Admin, Manager, Reception và Staff. Web, API và Flutter cùng nằm trong repository `KLCN021_HealthBeauty`: `HealthBeauty.Web`, `HealthBeauty.Api` và `HealthBeauty.Mobile`.

## Yêu cầu

- Node.js `20.19+` (nhánh 20), `22.13+` (nhánh 22) hoặc `24+`; Node 24 đã được kiểm tra.
- npm và backend đang chạy tại `http://localhost:5230`.
- Chạy các lệnh dưới đây trong thư mục `HealthBeauty.Web`.

## Cài đặt và chạy

```powershell
npm ci
Copy-Item .env.example .env
npm run dev
```

Trên macOS/Linux dùng `cp .env.example .env`. Để `VITE_API_BASE_URL` trống nếu dùng proxy phát triển mặc định: Vite chuyển `/api` tới API cổng 5230. Nếu triển khai không dùng proxy, đặt URL API đầy đủ, kết thúc bằng `/api/v1`; máy chủ web cần chuyển các route của ứng dụng về `index.html`. Không đặt mật khẩu hoặc khóa bí mật trong biến `VITE_*` vì chúng được đưa vào mã trình duyệt.

```powershell
npm test
npm run lint
npm run build
npm run preview
```

`preview` xem bản build, không cung cấp proxy `/api` của chế độ phát triển; cần cấu hình URL API hoặc reverse proxy trước khi build để gọi backend.

Nếu Windows báo `spawn EPERM` khi Vite tải cấu hình, dùng `npm run dev -- --configLoader native` hoặc `npm run build -- --configLoader native` trên Node 24.

## Cấu trúc

- `src/api/`: HTTP client, phiên đăng nhập và API nghiệp vụ.
- `src/types/`: DTO và kiểm tra phản hồi API.
- `src/features/`: các trang dịch vụ, lịch hẹn, khách hàng, nhân viên, hóa đơn, khuyến mãi, đánh giá, báo cáo, tài khoản, phân quyền và nhật ký.
- `src/components/`, `src/layouts/`: giao diện dùng chung và bố cục responsive.
- `src/routes/`, `src/hooks/`, `src/utils/`: bảo vệ route, hook và quy tắc quyền.
- `tests/`: kiểm thử hợp đồng dữ liệu và phân quyền.

## Tài khoản và phân quyền

Access token lưu trong bộ nhớ, refresh token trong localStorage để khôi phục phiên. Cần bảo vệ ứng dụng khỏi XSS khi triển khai. Khách hàng sử dụng Flutter, không đăng nhập web quản trị. Tài khoản khởi tạo được cấu hình ở API; xem README tại thư mục gốc repository.

Admin dùng **Tài khoản** để tạo tài khoản, gán vai trò hoặc khóa/mở tài khoản. Khi gán vai trò nhân viên, có thể chọn hồ sơ nhân viên hiện có chưa liên kết để giữ nguyên lịch hẹn. **Nhân viên → Thêm nhân viên** yêu cầu email và mật khẩu: API tạo đồng thời tài khoản Staff và hồ sơ liên kết. `TaiKhoanId` và `NhanVienId` là hai mã riêng; Staff chỉ xem lịch được phân công cho hồ sơ của mình.

**Phân quyền** cấu hình quyền theo vai trò. Menu, route và nút thao tác sử dụng `GET /api/v1/auth/permissions`, làm mới khi quay lại cửa sổ hoặc mỗi 30 giây. API kiểm tra quyền và phạm vi dữ liệu độc lập với giao diện. Quyền xem và quyền sửa tách riêng; ví dụ `INVOICE.READ`, `INVOICE.WRITE`, `PAYMENT.WRITE`.

## Nhật ký hoạt động

Admin có `ACCOUNT.READ` xem **Nhật ký hoạt động**, sử dụng `/admin/audit-logs`. Trang hỗ trợ tìm kiếm, lọc và chọn 100/200/500 bản ghi gần nhất; bộ lọc áp dụng trên dữ liệu đã tải. Chỉ hiển thị các sự kiện API đã ghi nhận.
