import 'package:dio/dio.dart';

/// Đổi lỗi Dio thành câu tiếng Việt cho người dùng.
///
/// Backend trả lỗi theo 2 dạng:
///  - `Conflict("Email đã tồn tại.")`, `Unauthorized("...")`, `BadRequest("...")`
///    -> body là CHUỖI thuần.
///  - Lỗi validate DataAnnotations ([ApiController]) -> ProblemDetails:
///    `{ "title": "...", "errors": { "Password": ["..."] } }`
class ApiError {
  static String message(DioException e) {
    final code = e.response?.statusCode;

    if (code == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Máy chủ phản hồi quá lâu, vui lòng thử lại';
        default:
          return 'Không kết nối được máy chủ';
      }
    }

    final data = e.response?.data;

    if (code == 400 && data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final keys = errors.keys.map((k) => k.toString().toLowerCase()).toList();
      if (keys.any((k) => k.contains('password'))) {
        return 'Mật khẩu phải từ 8 ký tự trở lên';
      }
      if (keys.any((k) => k.contains('email'))) return 'Email không hợp lệ';
      if (keys.any((k) => k.contains('hoten') || k.contains('fullname'))) {
        return 'Họ tên không hợp lệ';
      }
      if (keys.any((k) => k.contains('phone'))) {
        return 'Số điện thoại không hợp lệ';
      }
      return 'Dữ liệu không hợp lệ';
    }

    if ((code == 400 || code == 401 || code == 404 || code == 409) &&
        data is String &&
        data.trim().isNotEmpty) {
      return data.trim();
    }

    switch (code) {
      case 400:
        return 'Dữ liệu không hợp lệ';
      case 401:
        return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này';
      case 404:
        return 'Không tìm thấy dữ liệu';
      case 409:
        return 'Dữ liệu bị trùng';
      case 429:
        return 'Bạn thao tác quá nhanh, vui lòng thử lại sau';
      default:
        return 'Lỗi máy chủ ($code)';
    }
  }
}
