# KLCN021 HealthBeauty

Repository chứa ASP.NET Core Web API, SQL Server schema và danh mục API cho hệ thống quản lý spa HealthBeauty. Web React và ứng dụng di động dùng chung API này.

## Công nghệ

- .NET 8 / ASP.NET Core Web API
- SQL Server
- Entity Framework Core
- JWT access token và refresh token

## Yêu cầu

- .NET 8 SDK
- SQL Server (LocalDB, SQL Server Express hoặc SQL Server instance)
- SQL Server Management Studio hoặc công cụ chạy script tương đương

## Cài đặt lần đầu

1. Clone repository và mở solution:

   ```powershell
   git clone https://github.com/HoaiNam2k5/KLCN021-HealthBeauty.git
   cd KLCN021-HealthBeauty
   ```

2. Chạy script `DB_KLCN021/KLCN021_HealthBeauty.sql` trong SQL Server Management Studio. Script tạo database `KLCN021_HealthBeauty` và các bảng cần thiết.

   Để nạp dữ liệu mẫu cho giao diện và luồng nghiệp vụ, tiếp tục chạy `DB_KLCN021/02_SeedData.sql`. Script seed có thể chạy lại an toàn.

   Tài khoản demo local sau khi chạy seed:

   | Vai trò | Email | Mật khẩu |
   | --- | --- | --- |
   | Admin | `admin@healthbeauty.local` | `HealthBeauty@123` |
   | Reception | `reception@healthbeauty.local` | `HealthBeauty@123` |
   | Customer | `customer@healthbeauty.local` | `HealthBeauty@123` |

   Các tài khoản trên chỉ dùng phát triển local. Không nạp seed này vào môi trường production và phải đổi mật khẩu nếu dùng trong môi trường dùng chung.

3. Cấu hình connection string và JWT key bằng User Secrets ở project API. Ví dụ với SQL Server Express:

   ```powershell
   cd HealthBeauty.Api
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost\SQLEXPRESS;Database=KLCN021_HealthBeauty;Trusted_Connection=True;TrustServerCertificate=True;"
   dotnet user-secrets set "Jwt:Key" "<chuoi-bi-mat-ngau-nhien-it-nhat-32-ky-tu>"
   dotnet restore
   dotnet run
   ```

   Thay `localhost\SQLEXPRESS` theo SQL Server instance của máy. Không commit connection string có thông tin đăng nhập, JWT key, hoặc User Secrets.

   Có thể tạo secret ngẫu nhiên bằng PowerShell: `[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))`.

4. Mở Swagger tại `http://localhost:5230/swagger`. Nếu cổng 5230 bận, chọn cổng khác bằng:

   ```powershell
   dotnet run --urls http://localhost:5231
   ```

## Luồng làm việc Web/App

- API base URL khi chạy local: `http://localhost:5230/api/v1`.
- Web/app gọi `auth/register` hoặc `auth/login`, sau đó gửi access token trong header `Authorization: Bearer <token>` cho endpoint cần đăng nhập.
- Khi web/app chạy trên thiết bị khác, `localhost` phải được thay bằng địa chỉ IP máy chạy API; cấu hình CORS và HTTPS phù hợp trước khi triển khai dùng chung.
- Danh mục endpoint: xem Swagger hoặc file `KLCN021_API_Catalog.xlsx`.

## Lưu ý

- Một số endpoint nghiệp vụ cần SQL Server đang chạy và database đã được tạo từ script.
- Endpoint thanh toán hiện ghi nhận trạng thái thanh toán trong hệ thống, chưa tích hợp cổng thu tiền VNPay/MoMo.
- JWT secret phải được tạo riêng cho từng môi trường; không dùng ví dụ placeholder làm secret thật.
