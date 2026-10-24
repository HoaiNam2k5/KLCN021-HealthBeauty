String? validatePasswordChange(String currentPassword, String newPassword) {
  if (currentPassword.trim().isEmpty || currentPassword.length > 4096) {
    return 'Vui lòng nhập mật khẩu hiện tại hợp lệ.';
  }
  if (newPassword.trim().isEmpty ||
      newPassword.length < 8 ||
      newPassword.length > 128) {
    return 'Mật khẩu mới phải từ 8 đến 128 ký tự.';
  }
  if (newPassword == currentPassword) {
    return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
  }
  return null;
}
