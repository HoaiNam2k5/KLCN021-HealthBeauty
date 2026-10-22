import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/token_storage.dart';
import '../models/account.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _client;
  Dio get _dio => _client.dio;
  int _operation = 0;
  bool _disposed = false;
  late final void Function() _sessionExpired;

  Account? account;
  bool isLoading = false;
  bool isInitializing = true; // đang kiểm tra token khi mở app
  String? error;
  bool requiresTwoFactor = false;
  String? twoFactorEmail;

  bool get isLoggedIn => account != null;

  AuthProvider({ApiClient? client}) : _client = client ?? ApiClient() {
    // Khi refresh bị từ chối -> tự về màn đăng nhập
    _sessionExpired = () {
      if (_disposed) return;
      _operation++;
      final hadAccount = account != null;
      account = null;
      if (hadAccount) {
        error = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
      }
      notifyListeners();
    };
    _client.onSessionExpired = _sessionExpired;
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    if (identical(_client.onSessionExpired, _sessionExpired)) {
      _client.onSessionExpired = null;
    }
    super.dispose();
  }

  /// Gọi lúc mở app: có token + account đã lưu thì khôi phục phiên.
  /// Token hết hạn sẽ được interceptor tự refresh ở request đầu tiên.
  Future<void> tryAutoLogin() async {
    final operation = _operation;
    error = null;
    try {
      if (await TokenStorage.access != null) {
        final savedAcc = await TokenStorage.accountJson;
        if (savedAcc != null) {
          final restored = Account.fromJson(jsonDecode(savedAcc));
          if (operation != _operation) return;
          if (restored.role != 'Customer') {
            await TokenStorage.clear();
          } else {
            account = restored;
          }
        }
      }
    } catch (_) {
      if (operation == _operation) account = null;
    } finally {
      if (!_disposed) {
        isInitializing = false;
        notifyListeners();
      }
    }
  }

  /// Lưu phiên từ response của /auth/login và /auth/register
  /// (backend trả cùng một dạng AuthResponse).
  Future<void> _saveSession(Map<String, dynamic> data, int operation) async {
    if (data['accessToken'] is! String ||
        (data['accessToken'] as String).isEmpty ||
        data['refreshToken'] is! String ||
        (data['refreshToken'] as String).isEmpty ||
        data['account'] is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi đăng nhập không hợp lệ.');
    }
    final incoming = Account.fromJson(data['account']);
    if (incoming.role != 'Customer') {
      try {
        await _dio.post(
          '/auth/logout',
          data: {'refreshToken': data['refreshToken']},
          options: Options(
            headers: {'Authorization': 'Bearer ${data['accessToken']}'},
            extra: {'skipAuth': true},
          ),
        );
      } catch (_) {}
      throw const FormatException(
        'Ứng dụng dành cho khách hàng. Tài khoản quản trị và nhân viên vui lòng dùng web.',
      );
    }
    if (operation != _operation) return;
    await TokenStorage.save(
      data['accessToken'],
      data['refreshToken'],
      accountJson: jsonEncode(data['account']),
    );
    if (operation == _operation) account = incoming;
  }

  Future<bool> login(String email, String password) {
    requiresTwoFactor = false;
    twoFactorEmail = null;
    return _run((operation) async {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['requiresTwoFactor'] == true) {
        if (operation != _operation) return;
        requiresTwoFactor = true;
        twoFactorEmail = data['email'] as String? ?? email.trim();
        return;
      }
      await _saveSession(data, operation);
    });
  }

  Future<bool> verifyTwoFactor(String otp) {
    final email = twoFactorEmail;
    if (email == null) return Future.value(false);
    return _run((operation) async {
      final res = await _dio.post(
        '/auth/verify-2fa',
        data: {'email': email, 'otp': otp.trim()},
        options: Options(extra: {'skipAuth': true}),
      );
      await _saveSession(Map<String, dynamic>.from(res.data as Map), operation);
      if (operation == _operation) {
        requiresTwoFactor = false;
        twoFactorEmail = null;
      }
    });
  }

  Future<bool> resendTwoFactor() async {
    final email = twoFactorEmail;
    if (email == null || isLoading) return false;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _dio.post(
        '/auth/resend-2fa',
        data: {'email': email},
        options: Options(extra: {'skipAuth': true}),
      );
      return true;
    } on DioException catch (e) {
      error = ApiError.message(e);
      return false;
    } catch (_) {
      error = 'Không thể gửi lại mã xác thực';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void cancelTwoFactor() {
    requiresTwoFactor = false;
    twoFactorEmail = null;
    error = null;
    notifyListeners();
  }

  /// Gửi thông tin Google về backend để tạo hoặc liên kết tài khoản và cấp JWT
  Future<bool> loginWithGoogleToken({
    required String email,
    required String googleId,
    String? fullName,
    String? photoUrl,
    String? idToken,
  }) {
    requiresTwoFactor = false;
    twoFactorEmail = null;
    return _run((operation) async {
      final res = await _dio.post(
        '/auth/google',
        data: {
          'email': email.trim(),
          'googleId': googleId.trim(),
          'fullName': fullName?.trim(),
          'photoUrl': photoUrl,
          'idToken': idToken,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      await _saveSession(data, operation);
    });
  }

  /// Khởi chạy SDK Google Sign-In trên thiết bị và đăng nhập
  Future<bool> loginWithGoogle() async {
    requiresTwoFactor = false;
    twoFactorEmail = null;
    try {
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '748230119172-th8nb34i0qm1f9qvv995opsdr5120qkm.apps.googleusercontent.com',
        );
      } catch (_) {}

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return false;
        }
        rethrow;
      }

      final idToken = googleUser.authentication.idToken;
      return await loginWithGoogleToken(
        email: googleUser.email,
        googleId: googleUser.id,
        fullName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
        idToken: idToken,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return false;
      }
      error = 'Đăng nhập Google thất bại: ${e.description ?? e.code.name}';
      notifyListeners();
      return false;
    } catch (_) {
      error = 'Không thể kết nối dịch vụ Google Sign-In';
      notifyListeners();
      return false;
    }
  }

  /// Backend /auth/register đã trả luôn token -> không cần gọi login lần nữa.
  Future<bool> register(
    String hoTen,
    String email,
    String sdt,
    String password,
  ) {
    return _run((operation) async {
      final res = await _dio.post(
        '/auth/register',
        data: {
          'hoTen': hoTen.trim(),
          'email': email.trim(),
          'soDienThoai': sdt.trim().isEmpty ? null : sdt.trim(),
          'password': password,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      await _saveSession(Map<String, dynamic>.from(res.data as Map), operation);
    });
  }

  Future<void> logout() async {
    _operation++;
    final token = await TokenStorage.refresh;
    final access = await TokenStorage.access;
    await TokenStorage.clear();
    account = null;
    error = null;
    isLoading = false;
    notifyListeners();
    try {
      if (token != null && access != null) {
        await _client.revokeSession(access, token);
      }
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> forgotPassword(String email) async {
    if (isLoading) return null;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.post(
        '/auth/forgot-password',
        data: {'email': email.trim()},
        options: Options(extra: {'skipAuth': true}),
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      error = ApiError.message(e);
      return null;
    } catch (_) {
      error = 'Không thể gửi yêu cầu đặt lại mật khẩu';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (isLoading) return false;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _dio.post(
        '/auth/reset-password',
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      return true;
    } on DioException catch (e) {
      error = ApiError.message(e);
      return false;
    } catch (_) {
      error = 'Không thể đặt lại mật khẩu';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<void> Function(int operation) action) async {
    if (isLoading) return false;
    final operation = ++_operation;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action(operation);
      return operation == _operation && account != null;
    } on DioException catch (e) {
      if (operation != _operation) return false;
      error =
          e.response?.statusCode == 401 &&
              e.requestOptions.path.contains('login')
          ? 'Sai email hoặc mật khẩu'
          : ApiError.message(e);
      return false;
    } on FormatException catch (e) {
      if (operation == _operation) error = e.message;
      return false;
    } catch (_) {
      if (operation == _operation) {
        error = 'Không đọc được phản hồi đăng nhập từ máy chủ';
      }
      return false;
    } finally {
      if (operation == _operation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }
}
