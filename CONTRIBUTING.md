# Quy ước đóng góp

## Branch

- `main`: phiên bản ổn định; không phát triển trực tiếp trên branch này.
- `feature/<ten-ngan>`: tính năng mới, ví dụ `feature/customer-profile`.
- `fix/<ten-ngan>`: sửa lỗi, ví dụ `fix/appointment-validation`.
- `docs/<ten-ngan>`: tài liệu, ví dụ `docs/api-setup`.
- `chore/<ten-ngan>`: cấu hình/công việc bảo trì, ví dụ `chore/update-packages`.

Tên branch viết thường, không dấu, dùng dấu gạch ngang; mỗi branch chỉ giải quyết một mục tiêu. Tạo branch từ `main` đã cập nhật:

```bash
git switch main
git pull origin main
git switch -c feature/<ten-ngan>
```

## Commit

Dùng Conventional Commits, subject ngắn, viết tiếng Anh và không kết thúc bằng dấu chấm:

```text
feat(api): add customer profile endpoint
fix(auth): reject expired refresh token
docs: clarify local database setup
chore: update api dependencies
```

Các type thường dùng: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

## Pull request

- Không push trực tiếp lên `main`; push branch công việc và mở Pull Request vào `main`.
- Nêu mục tiêu, endpoint/schema bị ảnh hưởng, cách kiểm thử và thay đổi cấu hình trong PR.
- Build phải thành công; thay đổi nghiệp vụ cần kiểm thử tương ứng.
- Thay đổi SQL phải cập nhật script trong `DB_KLCN021` và mô tả thứ tự triển khai.
- Không commit secret, file cấu hình cá nhân, `bin/`, `obj/`, `.vs/` hoặc file `.user`.

## API contract

- Giữ route dưới prefix `/api/v1`.
- Không đổi request/response đang được web/app sử dụng mà không cập nhật API catalog và thông báo trong PR.
- Dùng DTO trong `Contracts`; không bind trực tiếp entity EF cho request ghi dữ liệu.
- Kiểm tra quyền truy cập và quyền sở hữu dữ liệu ở server, không dựa vào kiểm tra phía client.
