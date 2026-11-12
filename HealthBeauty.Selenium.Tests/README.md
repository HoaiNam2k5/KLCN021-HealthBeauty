# Kiểm thử Selenium cho HealthBeauty Web

Project xUnit và Selenium kiểm thử giao diện web thông qua ChromeDriver. `mock-server.mjs` phục vụ bản build React và giả lập API trên `127.0.0.1` với dữ liệu trong bộ nhớ. Browser bị giới hạn kết nối trong máy; các thao tác xác nhận lịch chỉ tác động vào fixture, không gọi EC2, SePay hoặc SQL Server.

## Chạy trong Visual Studio

1. Mở `KLCN021_HealthBeauty.sln` và chọn project `HealthBeauty.Selenium.Tests` trong Test Explorer.
2. Cài Node.js, .NET 8 SDK và khôi phục các gói NuGet. Trong PowerShell chạy:

   ```powershell
   cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty\HealthBeauty.Web
   $env:VITE_API_BASE_URL='/api/v1'
   npm ci
   npm run build
   ```

3. ChromeDriver được ghim phiên bản 148. Trình duyệt Chromium/Chrome chạy test phải có cùng phiên bản chính. Project tự tìm Chromium 148 của Playwright ở đường dẫn đã cài trên máy này; cũng có thể chỉ định đường dẫn khi chạy trong PowerShell:

   ```powershell
   cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty
   $env:HEALTHBEAUTY_SELENIUM_CHROME=Join-Path $env:LOCALAPPDATA 'ms-playwright\chromium-1223\chrome-win64\chrome.exe'
   dotnet test .\HealthBeauty.Selenium.Tests\HealthBeauty.Selenium.Tests.csproj --logger 'trx;LogFileName=selenium.trx'
   ```

   Để chạy từ Visual Studio, mở Visual Studio từ PowerShell sau khi đặt biến trên, hoặc cấu hình biến môi trường tương ứng. Nếu dùng Chrome phiên bản khác, cập nhật gói `Selenium.WebDriver.ChromeDriver` lên phiên bản tương thích và khôi phục NuGet; không đặt biến thì Selenium dùng trình duyệt mặc định.

Kết quả TRX nằm trong `HealthBeauty.Selenium.Tests/TestResults`. Sáu trường hợp hiện tại kiểm tra validate đăng nhập, sai mật khẩu, bảo vệ đường dẫn, xem và xác nhận lịch, xem dịch vụ. Đây là kiểm thử giao diện với API giả lập; không chứng minh thanh toán hoặc các tích hợp production hoạt động đầu cuối.
