import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/token_storage.dart';
import '../models/account.dart';

class AuthProvider extends ChangeNotifier {
  final _dio = ApiClient().dio;

  Account? account;
  bool isLoading = false;
  bool isInitializing = true; // đang kiểm tra token khi mở app
  String? error;

  bool get isLoggedIn => account != null;

  AuthProvider() {
    // Khi refresh bị từ chối -> tự về màn đăng nhập
    ApiClient().onSessionExpired = () {
      account = null;
      error = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
      notifyListeners();
    };
  }

  /// Gọi lúc mở app: có token + account đã lưu thì khôi phục phiên.
  /// Token hết hạn sẽ được interceptor tự refresh ở request đầu tiên.
  Future<void> tryAutoLogin() async {
    try {
      if (await TokenStorage.access != null) {
        final savedAcc = await TokenStorage.accountJson;
        if (savedAcc != null) {
          account = Account.fromJson(jsonDecode(savedAcc));
        }
      }
    } catch (_) {
      account = null;
    }
    isInitializing = false;
    notifyListeners();
  }

  /// Lưu phiên từ response của /auth/login và /auth/register
  /// (backend trả cùng một dạng AuthResponse).
  Future<void> _saveSession(Map<String, dynamic> data) async {
    await TokenStorage.save(
      data['accessToken'],
      data['refreshToken'],
      accountJson: jsonEncode(data['account']),
    );
    account = Account.fromJson(data['account']);
  }

  Future<bool> login(String email, String password) {
    return _run(() async {
      final res = await _dio.post('/auth/login',
          data: {'email': email, 'password': password});
      await _saveSession(res.data);
    });
  }

  /// Backend /auth/register đã trả luôn token -> không cần gọi login lần nữa.
  Future<bool> register(
      String hoTen, String email, String sdt, String password) {
    return _run(() async {
      final res = await _dio.post('/auth/register', data: {
        'hoTen': hoTen,
        'email': email,
        'soDienThoai': sdt,
        'password': password,
      });
      await _saveSession(res.data);
    });
  }

  Future<void> logout() async {
    try {
      final rt = await TokenStorage.refresh;
      if (rt != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': rt});
      }
    } catch (_) {}
    await TokenStorage.clear();
    account = null;
    error = null;
    notifyListeners();
  }

  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DioException catch (e) {
      error = e.response?.statusCode == 401 && e.requestOptions.path.contains('login')
          ? 'Sai email hoặc mật khẩu'
          : ApiError.message(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
