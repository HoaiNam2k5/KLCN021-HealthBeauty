String googleLoginErrorMessage(String code) => switch (code) {
  'canceled' => 'Đăng nhập Google chưa hoàn tất. Nếu đã chọn tài khoản, hãy kiểm tra SHA-1/SHA-256 của ứng dụng trong Firebase.',
  'clientConfigurationError' => 'Cấu hình Google của ứng dụng chưa hợp lệ. Vui lòng kiểm tra mã ứng dụng, SHA-1 và mã khách Google.',
  'providerConfigurationError' => 'Dịch vụ Google trên thiết bị chưa sẵn sàng. Vui lòng kiểm tra Google Play Services và cấu hình đăng nhập.',
  'interrupted' => 'Đăng nhập Google bị gián đoạn. Vui lòng thử lại.',
  'uiUnavailable' => 'Không mở được màn hình đăng nhập Google. Vui lòng thử lại khi ứng dụng đang mở.',
  _ => 'Không thể hoàn tất đăng nhập Google. Vui lòng thử lại.',
};
