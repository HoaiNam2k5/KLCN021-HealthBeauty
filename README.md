# HealthBeauty Web

Ứng dụng quản trị cơ sở làm đẹp, xây dựng bằng React, TypeScript và Vite. Web phục vụ Admin, Manager, Reception và Staff; ứng dụng Flutter cho khách hàng nằm ngoài repository này.

## Yêu cầu

- Node.js và npm tương thích với phiên bản Vite của dự án
- Backend local đang chạy tại cổng 5230 nếu cần dùng API khi phát triển

## Cài đặt và chạy

```sh
npm install
Copy-Item .env.example .env
npm run dev
```

Trên macOS/Linux dùng `cp .env.example .env`. Để dùng proxy dev mặc định, để `VITE_API_BASE_URL` trống: Vite chuyển tiếp `/api` tới backend local. Nếu môi trường không dùng proxy, đặt biến này thành base URL phù hợp (đường dẫn API kết thúc bằng `/api/v1`). Không đưa URL/secret môi trường thật vào Git.

Lệnh kiểm tra/đóng gói:

```sh
npm run build
npm run lint
npm run preview
```

## Cấu trúc chính

- `src/api/`: axios client và API theo nghiệp vụ
- `src/types/`: kiểu DTO và kiểm tra phản hồi API
- `src/features/`: trang nghiệp vụ (auth, services, appointments, customers/staff, billing, promotions, reviews, reports)
- `src/components/`: component dùng chung
- `src/layouts/`: layout đăng nhập và quản trị
- `src/routes/`: định nghĩa route và bảo vệ quyền truy cập
- `src/hooks/`, `src/utils/`: hook và tiện ích dùng chung

## Xác thực và an toàn

Access token được giữ trong bộ nhớ; refresh token lưu trong localStorage để duy trì phiên. Cách lưu refresh token này có rủi ro bị đọc nếu xảy ra XSS, cần cân nhắc khi triển khai thực tế. Không hardcode tài khoản demo; chỉ sử dụng thông tin demo được cung cấp riêng cho môi trường local.

Vai trò trên giao diện chỉ giúp điều hướng/trải nghiệm; backend vẫn là nơi quyết định quyền truy cập cuối cùng. Khách hàng dùng ứng dụng di động, không đăng nhập web quản trị.

## Giao diện

Theme Ant Design đặt tại `src/theme/theme.ts`; phong cách giao diện theo `DESIGN.md` ở thư mục gốc.


This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])

```

You can also install [eslint-plugin-react-x](https://npmx.dev/package/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://npmx.dev/package/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])

```
