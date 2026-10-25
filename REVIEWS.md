# Tổng hợp bàn giao bản hợp nhất 24/10/2026

## Flutter gói dịch vụ

- Thêm danh mục/tìm kiếm gói đang bán, đăng ký mua Pending, gói của tôi, chi tiết số lượt và lịch sử, hủy đăng ký chưa thanh toán. Khách không tự xác nhận thu tiền.
- Nối đặt lịch bằng gói đã thanh toán: chọn dịch vụ/số lượt thuộc gói, `customerPackageId`, kiểm tra hạn/lượt và tải lại trước submit; không trộn combo/voucher/thu tiền riêng.
- Hiển thị lượt được cấp/đã dùng/đang giữ/còn lại/có thể đặt; cập nhật sau đặt/hủy và phân biệt nguồn gói trong lịch hẹn.
- Provider gắn với tài khoản/phiên, loại kết quả cũ và ngăn bấm lặp. Không API/Web/SQL mới, chưa push.
- Kiểm chứng:66file Dart không diagnostic,25/25 kiểm tra độc lập;10Fluttertests mới chưa chạy vì CreateFile5, chưa test emulator/giao dịch thật. Chi tiết và luồng test: [Gói dịch vụ Flutter](docs/GOI_DICH_VU_FLUTTER.md).

## Ảnh đại diện và đổi mật khẩu khách hàng — chờ áp dụng API gốc

Flutter đã có đổi/xóa ảnh trong sửa hồ sơ, hiển thị ảnh tài khoản, và màn hình đổi mật khẩu hiện tại/mới/xác nhận. Upload Cloudinary qua endpoint riêng đúng chủ; đổi mật khẩu204 rồi đăng xuất. Bổ sung bảo vệ phiên để không replay request cũ sang tài khoản mới khi refresh token.

Backend đã hoàn chỉnh và kiểm thử **523/523** tại worktree tạm, đóng gói15file có manifest. Chưa đưa vào API gốc vì **4file gốc bị Windows từ chối ghi**; SQL15 mới được chép, **chưa chạy**. Không áp dụng dở API. Anh cần mở PowerShell quản trị chạy `D:\KhoaLuan\AP_DUNG_HO_SO_KHACH_HANG.ps1 -ApplySql`, hoặc chạy SQL15 bằng SSMS rồi dùng `-SqlAlreadyApplied`. Script có backup/hash/preflight/test.

Chi tiết, giới hạn và cách test: [Hồ sơ khách hàng](docs/HO_SO_KHACH_HANG.md). Flutter56file static sạch, purecontract12/12; chưa Fluttertest/emulator/Cloudinary thực. Không push.

## Bổ sung: ngày còn lịch theo nhân viên

- API mới `/api/v1/appointments/availability/days` lấy ngày/giờ còn chỗ theo khoảng tối đa 61 ngày, nhân viên và toàn bộ thời lượng dịch vụ; API ngày cũ dùng chung quy tắc và giữ hợp đồng.
- Flutter đánh dấu ngày còn giờ phù hợp, vô hiệu hóa ngày không có chỗ, thêm **Lịch trống gần nhất** và **Cập nhật lịch trống**. Lọc lịch riêng của khách và hiệu lực combo; đổi lựa chọn không giữ kết quả cũ.
- Không cần SQL hay sửa web. Phải khởi động lại API và Flutter từ thư mục chung.
- API **500/500 test đạt**, gồm HTTP xác minh endpoint/JSON thật trong database test cô lập. Logic lịch Flutter **6/6 kiểm tra độc lập đạt**; kết quả phân tích mã và giới hạn test Flutter được cập nhật trong lịch sử bên dưới.
- Hướng dẫn và luồng test: [Lịch trống nhân viên](docs/LICH_TRONG_NHAN_VIEN.md).

Toàn bộ code đang dùng nằm trong thư mục dự án này: một `HealthBeauty.Api`, một `HealthBeauty.Web`, một `HealthBeauty.Mobile` và bộ SQL `DB_KLCN021`. Đây là hợp nhất source local, chưa commit/push lên GitHub.

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

## Chẩn đoán không mở thư viện ảnh Android
Flutter đã có dependency image_picker nhưng native metadata/registrant tại máy chưa có plugin. Cần q/dừng hẳn phiên app cũ rồi chạy CHAY_FLUTTER.ps1 đểpubget/rebuild. Đã sửa lỗi MissingPlugin/channel-error/quyền ảnh/already_active thành thông báo rõ vàSnackBar. Static56file0diagnostics; chưa build/emulatorverify vì toolCreateFile5. APIavatar5230 đã có route, không phải cấu hình CloudinarytrongFlutter. Chưa push đợt thông báo lỗi này.

## Đồng bộ Firebase Android mới có SHA
Áp dụng google-services.json mới ở D:/KhoaLuan vào Flutter/android/app và bảnnhóm. SHA1máyanh đã có trong2Androidcertificates; package/project/appId/OAuthclient đều khớp. AndroidAPIkey đổi nên đã cập nhật riêng FirebaseOptions.android; web giữ nguyên. Backup ở D:/KhoaLuan/_Backups/firebase-config-20261024-203940. Cần q/chạy lạiFlutter đểnativeconfigcó hiệu lực; chưa kiểm thửOAuththật, chưa pushcậpnhậtlocalnày.
