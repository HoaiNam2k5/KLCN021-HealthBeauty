# Tích hợp chọn lọc đề xuất mobile — 26/10/2026

Đã lấy từng phần phù hợp từ commit `ae12e66` của `feature/mobile-app`, chỉnh các điểm trong bản review trước khi ghép vào app hiện tại. Không merge đè toàn nhánh. Giữ nguyên QR hóa đơn, QR mua gói, đặt lịch bằng gói, thông tin đánh giá và bản sửa lịch qua ngày.

## Đổi lịch

- Có màn hình chọn ngày/giờ cho lịch chờ xác nhận hoặc đã xác nhận; không đổi dịch vụ, nhân viên đã phân công hoặc ghi chú.
- Đọc đúng DTO chi tiết từ API sau đổi lịch, giữ `customerPackageId`, hóa đơn và dữ liệu đánh giá.
- Ngày focus không nằm ngoài giới hạn lịch, kể cả lịch cũ đã qua ngày hoặc lịch được đặt xa hơn 60 ngày.
- Tải lại danh sách, thông tin gói và nhắc hẹn local sau thành công.
- Nếu mạng/parse phản hồi không xác định được kết quả, đọc lại bằng GET. Lần bấm tiếp theo kiểm tra kết quả, không tự gửi POST đổi lịch lần nữa. Nếu vẫn chưa xác minh được, hiển thị hướng dẫn kiểm tra/liên hệ lễ tân.
- API `/appointments/availability` thêm `excludeAppointmentId` tùy chọn: khách chỉ được loại lịch của chính mình, quản lý cần quyền đọc đang được cấp. Chỉ lịch đủ điều kiện đổi mới được loại; lịch khác vẫn chặn giờ. Request tạo lịch cũ không truyền tham số này vẫn hoạt động như trước.
- Backend tiếp tục kiểm tra ca làm, trùng lịch, quyền sở hữu và hạn gói khi ghi thay đổi. App không quyết định thay các điều kiện này.

Các file chính: `models/appointment.dart`, `providers/appointment_provider.dart`, `screens/reschedule_screen.dart`, `screens/appointments_screen.dart`, API `SupplementControllers.cs`.

## Đổi điểm lấy voucher

- Hiển thị voucher khả dụng, điểm cần đổi và điểm hiện có; yêu cầu xác nhận trước khi đổi.
- Chụp tài khoản/phiên khi mở xác nhận và kiểm tra lại trước POST/sau refresh. Khóa gửi đồng thời.
- App gửi `{ "expectedPointsCost": ... }`. Backend trả `409`, không trừ điểm nếu giá đổi đã thay đổi; yêu cầu người dùng tải lại/xác nhận lại.
- API vẫn hỗ trợ client cũ không gửi body. Phiên bản app mới luôn gửi giá điểm đã xác nhận.
- Sau giao dịch, tải mới ví/ưu đãi/điểm và ngăn phản hồi cũ ghi đè. Số dư được xác nhận trong kết quả đổi có thể hiển thị ngay trong lúc tải lại hồ sơ.
- Khi timeout, không tự gửi đổi lại; làm mới ví và số dư để đối chiếu trước khi người dùng quyết định bước tiếp theo.

Các file chính: `models/catalog.dart`, `providers/catalog_provider.dart`, `providers/profile_provider.dart`, `screens/offers_screen.dart`, API `VoucherRedemptionController.cs`.

## Lọc giá dịch vụ

- Có min/max và nút xóa; ô trống nghĩa là không giới hạn.
- Cho phép bắt đầu từ 0, không cấm min thấp hơn giá rẻ nhất catalog.
- Giá không âm, hữu hạn; min không lớn hơn max. Giới hạn độ dài nhập để tránh số quá lớn.
- Kết hợp cùng tìm kiếm tên và danh mục; không làm mất nút mua/xem gói dịch vụ.
- Chỉ áp dụng bộ lọc này cho tab dịch vụ, không tự thay đổi giá hoặc logic combo/gói.

Các file chính: `models/service_price_filter.dart`, `widgets/service_price_filter.dart`, `screens/services_screen.dart`.

## Mốc điểm thành viên

- Nội dung tĩnh được trình bày như mốc tham khảo theo **số dư điểm hiện có**. Đổi điểm có thể làm thay đổi mốc hiển thị; chưa có hạng chính thức hay giảm giá/ưu tiên tự động.
- Bỏ các cam kết phần trăm giảm giá, quà tặng hoặc ưu tiên chưa được backend thực thi.
- Điểm hiện tại vẫn lấy từ server; không tạo thêm API hạng, không đổi cấu trúc database để lưu hạng.

Các file chính: `models/membership_tier.dart`, `screens/account_screen.dart`.

## Kiểm tra

- API đầy đủ: **618/618 đạt**, gồm kiểm tra giá điểm thay đổi không trừ điểm, request cũ không body và quyền loại lịch cũ khi chọn giờ.
- Flutter đầy đủ: **156 đạt, 1 không đạt**. Test không đạt là `reviews_section_test.dart:76`, đang tìm nhãn cũ `Đánh giá & Nhận xét`; lỗi này đã tồn tại trước đợt tích hợp. Không sửa chức năng đánh giá trong đợt này.
- Các kiểm thử mới cho đổi lịch, voucher, lọc giá và mốc điểm đều đạt; analyzer: **No issues found**.
- APK debug build thành công (`assembleDebug` 20,3 giây). APK được tạo để kiểm tra build; cần cập nhật API trước khi phát hành bản app này.
- Rà soát độc lập không phát hiện lỗi chặn về tài chính, phân quyền hay trạng thái trong phần đã tích hợp.

## Triển khai

Chưa commit/push hoặc triển khai bản tích hợp này. Không có migration/schema mới, không thay đổi dữ liệu production.

**Cần triển khai API mới trước khi phát hành APK mới.** Backend hiện đang chạy chưa có kiểm tra `expectedPointsCost` và tham số loại lịch cũ khỏi khung giờ; chỉ cài app mới sẽ chưa có đầy đủ bảo vệ/luồng mới. Sau cập nhật API, kiểm tra đổi lịch và đổi voucher bằng tài khoản kiểm thử được cho phép trước khi phát hành app.

Không coi bản tích hợp là bản phát hành lên AWS; source đang được giữ trong worktree `D:/KhoaLuan/_Work/aws-release-20261025`.
