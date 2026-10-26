# Sửa lỗi giao diện Web 2026-10-26

Đã sửa bản giao diện mới trong `D:/KhoaLuan/DEV/KLCN021_HealthBeauty/HealthBeauty.Web`. Worktree `D:/KhoaLuan/_Work/aws-release-20261025` chỉ được đọc để tham khảo bảo vệ nghiệp vụ hiện tại. Không commit/push/deploy; không sửa Backend, database, Compose, secrets hoặc cấu hình production.

## 1. QR, thanh toán và phiếu in

- `BankTransferModal.tsx`: phiên hiển thị riêng theo tài khoản/hóa đơn; đóng hoặc đổi mục tiêu hủy request qua AbortSignal/Axios. Phản hồi cũ không cập nhật sang hóa đơn khác. Mở lại cùng hóa đơn cần đọc server lại.
- React Query kiểm tra hóa đơn mỗi 3 giây, tránh request polling chồng nhau và dừng polling khi đã thanh toán. Lỗi đọc trạng thái/QR sẽ ẩn mã, có nút thử lại.
- `transferSafety.ts`: chỉ hiện QR khi ID, trạng thái, số tiền nguyên dương, nội dung HB và URL VietQR/ngân hàng/tài khoản/số tiền khớp hóa đơn vừa đọc. Số tiền thay đổi chuyển sang tải hướng dẫn theo số tiền mới.
- `BillingPage.tsx`: hủy request danh sách/detail cũ, ghi snapshot hóa đơn đã thanh toán vào cache trước khi mở phiếu in, kiểm tra phiên đăng nhập sau await. Thông báo dùng “Hóa đơn đã được thanh toán”, không quy mọi thanh toán tiền mặt/thẻ cho SePay.
- `api/billing.ts`: thêm AbortSignal tùy chọn, các lời gọi cũ vẫn tương thích.

## 2. Ma trận lịch KTV

- `timelineModel.ts`, `appointmentQueries.ts`, `api/appointments.ts`: tải đủ các trang theo giới hạn API100, không lấy status/keyword/staff filter của bảng. Dữ liệu trùng ID, thiếu trang, metadata đổi hoặc request lỗi đều không được coi là dữ liệu trống đã xác minh.
- Query riêng theo tài khoản/ngày, tải thêm ngày trước để thể hiện lịch qua nửa đêm, cập nhật khi quay lại cửa sổ và mỗi30giây.
- `StaffTimelineMatrix.tsx`: thể hiện mọi ô giao với khoảng bận `[bắt đầu,kết thúc)`, cộng đầy đủ thành phần dịch vụ/combo lặp. Lịch hủy vẫn hiển thị nhưng không khóa thời gian. Tự mở rộng hàng khi có lịch ngoài08:00–20:00.
- Dựng cột từ danh bạ được phép đọc cộng tên/ID trong lịch đã được API phân quyền. Không cần cấp thêm quyền đọc toàn bộ nhân viên cho KTV. Khi mất STAFF.READ, dữ liệu/lỗi/loading danh bạ cache không còn dùng để dựng ma trận.
- Không cho đặt nhanh khi đang tải/cập nhật/lỗi, trong ô bận hoặc thời gian đã qua; handler kiểm tra lại lúc click. Ô chưa có lịch chỉ mở form dự kiến, không khẳng định ca làm hay đủ thời lượng dịch vụ; Backend tiếp tục kiểm tra khi lưu.
- `AppointmentsPage.tsx`: bỏ timer60ms khi điền form, dùng drawer forceRender để form sẵn sàng; giữ bảng, dịch vụ/combo và booking bằng gói hiện tại. Tên khách/KTV ưu tiên dữ liệu lịch khi thiếu quyền đọc danh bạ.

## 3. Lối tắt và KPI

- `QuickActionsBar.tsx`, `quickActions.ts`, `ReportsPage.tsx`: thanh lối tắt có ở trang chủ dù không REPORT.READ; không mount truy vấn báo cáo khi thiếu quyền.
- Kiểm tra quyền truy cập trang và quyền tạo tương ứng. Người chỉ đọc không được quảng cáo thao tác tạo; lịch làm việc dùng nhãn xem lịch, không hứa quyền phân ca.
- `useCreateIntent.ts`: lối tắt mở form bằng `?action=create` trên lịch hẹn, hóa đơn và khách hàng; chờ quyền tải xong, đóng form sẽ tiêu thụ intent và giữ các tham số khác. Nút tạo thông thường vẫn hoạt động.
- Giữ thiết kế KPI mới, bỏ ép kiểu any gây lỗi lint.

## Xác minh

- `npm test`: **71 passed, 0 failed**. Bổ sung23 kiểm thử: QR9, ma trận10, lối tắt4; đã đăng ký trong `tests/all.test.mjs`.
- `npm run lint`: **exit0, không lỗi/cảnh báo**.
- `npm run build`: **exit0, 3847 modules**; vẫn có cảnh báo chunk lớn hơn500kB, không chặn build.
- `git diff --check -- HealthBeauty.Web`: đạt, chỉ có thông báo chuyển đổi LF/CRLF.
- Rà soát độc lập các luồng tài chính, phân quyền và ma trận: không còn lỗi chặn trong phạm vi thay đổi.

Các test QR dùng component source thực với QueryObserver và promise trì hoãn, không phải giao dịch thật. Ma trận kiểm tra101lịch/phân trang50, metadata/ID lỗi, lỗi trang sau, khoảng bận/chính xác giờ kết thúc, qua đêm, KTV thiếu danh bạ, lịch hủy, thời gian đã qua. Test lối tắt kiểm tra trang chủ không có quyền báo cáo, quyền tạo, chờ quyền và tiêu thụ intent.

## Kiểm tra thực tế trước khi phát hành

Chưa chạy browser E2E hoặc chuyển khoản thật. Trên tài khoản kiểm thử được phép, kiểm tra:

1. Mở QR A rồi đổi B/đóng mở lại khi giả lập mạng chậm: không nhảy QR hoặc thông báo của A sang B.
2. Hai cửa sổ quầy: đổi số tiền ở cửa sổ kia, xác nhận QR cũ bị ẩn và mã mới có đúng số tiền; sau thanh toán mở/in phiếu với đúng trạng thái/phương thức.
3. Ma trận ngày nhiều lịch và lịch kéo dài: không còn ô đặt nhanh trong khoảng bận; đăng nhập KTV để xem lịch của mình.
4. Lễ tân không REPORT.READ vẫn thấy lối tắt được cấp; bấm tạo mở đúng form, đóng rồi tải lại không tự mở lại.

Ma trận xử lý lịch qua đêm từ ngày trước; trường hợp bất thường chưa phân công kéo dài hơn24giờ chưa được bảo đảm bởi cửa sổ truy vấn này. Không mở rộng Backend/schema trong đợt sửa giao diện.

Khi đưa lên main, cần tích hợp chọn lọc với bản mới nhất để giữ luồng xác nhận/bắt đầu/hoàn thành, lý do hủy và các bảo vệ thu ngân đã triển khai. Không chép đè nguyên repo local đang có nhiều thay đổi chưa đồng bộ.
