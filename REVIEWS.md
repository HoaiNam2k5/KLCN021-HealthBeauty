# Tổng hợp bàn giao bản hợp nhất 24/10/2026

## Bản tích hợp main ngày 24/10/2026

- Đã ghép đầy đủ API/SQL15 ảnh đại diện và đổi mật khẩu cùng Flutter trong repository; không cần script apply cục bộ sau clone. Database có sẵn phải cập nhật SQL còn thiếu, đặc biệt SQL15.
- Web gồm quản lý gói dịch vụ, sửa đánh giá/voucher/báo cáo, Việt hóa và STT tài khoản. Flutter gồm thông báo/hồ sơ/xác thực, ảnh dịch vụ theo API, ngày còn chỗ và cập nhật nhân viên khi đặt lịch.
- Khách đổi/xóa ảnh đại diện qua endpoint riêng đúng chủ, đổi mật khẩu với mật khẩu hiện tại, thu hồi phiên cũ. Client chặn gửi lại request cũ dưới tài khoản mới khi refresh token.
- Cấu hình máy cá nhân, khóa bí mật và cache/build không đưa lên Git. Firebase client config là cấu hình công khai; file Android và service account lấy riêng từ nhóm/Console.
- Kết quả kiểm chứng bản xuất bản được ghi cuối tài liệu; chưa coi kiểm tra tĩnh Flutter là kiểm thử thiết bị thực.
- Chi tiết: [Hồ sơ khách hàng](docs/HO_SO_KHACH_HANG.md), [lịch trống nhân viên](docs/LICH_TRONG_NHAN_VIEN.md).

Các mục lịch sử phía dưới mô tả những đợt làm việc trước; bản main hiện đã tích hợp đầy đủ source API thay cho các bản worktree cục bộ được nhắc trong lịch sử.

## Bổ sung: ngày còn lịch theo nhân viên

- API mới `/api/v1/appointments/availability/days` lấy ngày/giờ còn chỗ theo khoảng tối đa 61 ngày, nhân viên và toàn bộ thời lượng dịch vụ; API ngày cũ dùng chung quy tắc và giữ hợp đồng.
- Flutter đánh dấu ngày còn giờ phù hợp, vô hiệu hóa ngày không có chỗ, thêm **Lịch trống gần nhất** và **Cập nhật lịch trống**. Lọc lịch riêng của khách và hiệu lực combo; đổi lựa chọn không giữ kết quả cũ.
- Không cần SQL hay sửa web. Phải khởi động lại API và Flutter từ thư mục chung.
- API **500/500 test đạt**, gồm HTTP xác minh endpoint/JSON thật trong database test cô lập. Logic lịch Flutter **6/6 kiểm tra độc lập đạt**; kết quả phân tích mã và giới hạn test Flutter được cập nhật trong lịch sử bên dưới.
- Hướng dẫn và luồng test: [Lịch trống nhân viên](docs/LICH_TRONG_NHAN_VIEN.md).

Toàn bộ code đang dùng nằm trong thư mục dự án này: một `HealthBeauty.Api`, một `HealthBeauty.Web`, một `HealthBeauty.Mobile` và bộ SQL `DB_KLCN021`. Bản phát hành main chứa source tích hợp dùng chung.

## API và CSDL

- Giữ API mới đã áp dụng về thư mục gốc, gồm Google ID token, OTP đăng nhập tùy chọn, dữ liệu chi tiết đánh giá trong lịch hẹn và thu hồi đăng ký push khi đăng xuất.
- Giữ các module đã có: quên mật khẩu, thông báo, Cloudinary, điểm/voucher, báo cáo, quản lý gói dịch vụ.
- Giữ cấu hình máy cá nhân và sửa đổi `ReportingWorkbook.cs`; không ghi đè bằng API cũ trong các nhánh frontend.
- Chỉ có một bộ database tại `DB_KLCN021`, gồm SQL14. Không chạy SQL trong đợt hợp nhất; OTP vẫn tắt đến khi xác nhận SQL14/SMTP đầy đủ.
- Chi tiết: [API REVIEWS](HealthBeauty.Api/REVIEWS.md), [hợp đồng xác thực mobile](HealthBeauty.Api/MOBILE_AUTH_INTEGRATION.md).

## Web

- Lấy bản mới nhất của nhánh `feature/huynh-web`, commit `2ca4f83`, gồm quản lý gói dịch vụ và cập nhật đánh giá/voucher/báo cáo của thành viên.
- Giữ các sửa đổi local: đồng bộ tiếng Việt, nhật ký hoạt động, nhãn quyền/vai trò/trạng thái, thông báo API và cột STT trang tài khoản.
- Web gọi API chung cổng 5230. Không dùng API cũ trong clone frontend.

## Flutter

- Lấy bản mới nhất của nhánh `feature/mobile-app`, commit `b1bbb99`, cùng cấu hình Firebase nhóm.
- Giữ sửa ảnh dịch vụ/combo theo `imageUrl` API, ảnh chi tiết, kéo tải lại danh sách và trạng thái ảnh dự phòng.
- Giữ sửa đăng nhập Google: hiện tiến trình/lỗi tiếng Việt, kiểm tra ID token, chặn bấm lặp và bỏ phản hồi cũ sau đổi phiên.
- Google OAuth thực còn cần kiểm tra SHA trên Firebase Console; copy JSON cũ không tự đăng ký SHA.
- Flutter yêu cầu Dart ^3.13.4; dùng SDK mới 3.47.7 / Dart 3.13.5 đã cài. Không hạ ràng buộc SDK.
- Các chức năng Flutter chưa có như mua/quản lý gói và đổi điểm voucher được ghi trong [báo cáo review](docs/BAO_CAO_KIEM_TRA_FLUTTER_2026-10-23.md); việc hợp nhất không tự bổ sung giao diện này.

## Chạy và kiểm chứng

- Lệnh chạy chung: [README](README.md), các script `CHAY_API.ps1`, `CHAY_WEB.ps1`, `CHAY_FLUTTER.ps1`.
- API: **487/487 test đạt** tại thư mục gốc.
- Web: **40/40 test đạt**, build production thành công; có cảnh báo chunk lớn.
- Flutter: **47 file lib/test không có diagnostic** qua analysis server trực tiếp; **6/6 kiểm tra contract ảnh đạt**.
- Chưa chạy được trọn `flutter test`/build Android trong môi trường agent vì lỗi Windows `CreateFile failed 5`. Dependency đã resolve bằng Dart trực tiếp, nhưng lệnh kết thúc lỗi ghi telemetry ngoài workspace. Không coi các kiểm tra tĩnh là test thiết bị thật.
- Chưa xác nhận Google OAuth/SMTP/push thật, chưa áp dụng SQL14 trong đợt này.

Các clone/worktree cũ và dữ liệu kiểm tra tạm được dọn sau khi sao lưu có đối chiếu SHA256. Bản sao lưu nằm ngoài repository, chứa cả cấu hình local nên không gửi lên GitHub.

## Nhân viên mới không hiện khi đặt lịch

Đã sửa Flutter tải lại `/staff` mỗi lần vào bước chọn nhân viên; bổ sung nút cập nhật, loading và thông báo lỗi/retry. API hiện trả toàn bộ nhân viên, không lọc ca làm, nên không đổi backend/database. Quy tắc bảo vệ dữ liệu khi đổi tài khoản và xử lý refresh lỗi của provider giữ nguyên. Nhân viên cần ca làm để có giờ đặt. Phân tích50Dartfile không diagnostic; chưa kiểm tra trực quan trên emulator do giới hạn Flutter tool đã ghi ở trên.

## Kiểm chứng bản xuất bản main

- API: 523/523 test đạt tại bản xuất bản, gồm HTTP và avatar/đổi mật khẩu/ngày trống.
- Web: 40/40 test đạt, build production thành công; npm audit production không báo lỗ hổng. Build có cảnh báo chunk lớn.
- Flutter: 56 file phân tích trực tiếp không diagnostic; 24/24 kiểm tra độc lập (ảnh dịch vụ6, lịch trống6, hồ sơ/mật khẩu12). Chưa chạy trọn Flutter test/build Android do CreateFile5; static/pure checks không thay thế kiểm thử thiết bị.
- File publish đã được rà soát và đối chiếu bí mật local: không credential, service account, cache/build hoặc tài liệu tạm trong commit. Không chạy SQL thật/Cloudinary/SMTP/Google OAuth/push trong đợt xuất bản.
- Database có sẵn phải cập nhật SQL15 trước API này; các migration còn thiếu khác theo README.
