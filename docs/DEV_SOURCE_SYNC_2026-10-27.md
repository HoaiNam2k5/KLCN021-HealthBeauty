# Đồng bộ code mới về DEV

Thư mục làm việc chính: `D:/KhoaLuan/DEV/KLCN021_HealthBeauty`.
Nguồn đối chiếu: main `d9d2d0b5b15cd90f117bdc8dd4857a1439c7af12` trong worktree `D:/KhoaLuan/_Work/aws-release-20261025`, giữ worktree chỉ đọc.

Đã đối chiếu229 đường dẫn:150 đã khớp (gồm5 tài liệu đã vắng ở cả hai phía),55 file mới/cập nhật/ghép sạch,21 file ghép thủ công và3 file cấu hình/dump được giữ riêng. Bản trước khi ghép và manifest nằm trong `.local-integration/dev-sync-20261026-214127`.

## Nội dung hiện có tại DEV

- API: đầy đủ SePay hóa đơn/gói, xác nhận/bắt đầu/hoàn thành lịch, hủy có lý do/audit, hóa đơn tự động, tên khách/KTV, quyền và kiểm tra đổi lịch/đổi voucher mới.
- Flutter: lịch ngày trước chuyển sang lịch sử và cảnh báo khi cửa hàng chưa cập nhật; đổi lịch an toàn khi timeout; voucher/điểm; lọc giá; mốc điểm tham khảo; QR mua gói; lịch sử hóa đơn/thông báo; booking bằng gói không thu thêm.
- Giữ giao diện Flutter riêng tại DEV: hero/banner/shimmer, nhóm giờ sáng–chiều–tối, ảnh trước/sau, đánh giá và giao diện hội viên.
- Web: giữ KPI/lối tắt/ma trận KTV/modal QR mới và các sửa lỗi vừa làm; tích hợp thêm primary actions lịch hẹn, lý do hủy, liên kết đúng hóa đơn, thu tiền mặt/thẻ/để sau và kiểm tra thanh toán mới nhất. Gộp luồng thu ngân vào modal nâng cấp để tránh hai modal trùng nhau.
- Source deploy và các file SQL mới được đồng bộ khi cần; không thực thi SQL hay migration.

## Xác minh tại thư mục DEV

- API:618/618 test đạt; root đã chạy lại.
- Web:76/76 test đạt; root chạy lại test, lint exit0 và production build exit0 (3847 modules).
- Flutter: toàn bộ163/163 test đạt; analyzer `No issues found`. Test review trước đây được sửa để cuộn đến vùng đánh giá trong lazy list, không bỏ assertion.
- APK debug build thành công, assembleDebug59giây; file `HealthBeauty.Mobile/build/app/outputs/flutter-apk/app-debug.apk`,189912346bytes.
- Guard triển khai8/8 đạt với thư mục fixture trong workspace. Lần đầu chạy bị giới hạn quyền tạo thư mục tạm ngoài workspace; không sửa runtime triển khai để né kiểm tra.
- Không còn conflict marker trong source API/Mobile/Web; hash cấu hình riêng, env, Firebase và dump database không thay đổi.
- `git diff --check` toàn phạm vi còn whitespace EOF có sẵn ở `ReportingWorkbook.cs`; không phải lỗi build. Vite có cảnh báo bundle lớn; Flutter có cảnh báo tương thích KGP tương lai của firebase_core.

Rà soát độc lập đã xác nhận sơ bộ API/Mobile và hash cấu hình không có lỗi chặn; lượt review tổng cuối bị dừng bởi giới hạn quota agent. Main agent hoàn tất kiểm tra source, manifest, test/build và hash nêu trên. Chưa chạy browser E2E hay giao dịch thật.

## Chạy từ thư mục chính

```powershell
cd D:\KhoaLuan\DEV\KLCN021_HealthBeauty
.\CHAY_FLUTTER.ps1
```

Script mặc định dùng emulator-5554 và API production `https://healthbeauty.duckdns.org/api/v1`. Chọn thiết bị khác bằng `-Device <id>` nếu cần.

Đợt này chỉ đồng bộ file source trong working tree. Giữ nguyên nhánh và lịch sử Git hiện tại; không commit/push/reset/clean/checkout, không sửa hoặc chạy database, không deploy lại AWS. Những thay đổi riêng chưa commit của DEV vẫn được giữ, không coi Git working tree là sạch hoặc đã chuyển sang nhánh main.
