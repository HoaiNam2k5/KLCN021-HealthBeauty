import 'dart:convert';
import 'package:dio/dio.dart';
import 'constants.dart';
import 'token_storage.dart';

enum _RefreshResult { ok, rejected, networkError }

class ApiClient {
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;

  late final Dio dio;

  /// AuthProvider gán callback này để biết khi phiên hết hạn -> về màn login
  void Function()? onSessionExpired;

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: Constants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.access;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) async {
        final req = e.requestOptions;
        final isAuthCall = req.path.contains('/auth/');
        final alreadyRetried = req.extra['retried'] == true;

        if (e.response?.statusCode == 401 && !isAuthCall && !alreadyRetried) {
          final result = await _refresh();

          if (result == _RefreshResult.ok) {
            // Thử lại đúng 1 lần với token mới
            req.extra['retried'] = true;
            req.headers['Authorization'] =
                'Bearer ${await TokenStorage.access}';
            try {
              return handler.resolve(await dio.fetch(req));
            } on DioException catch (err) {
              return handler.next(err);
            }
          }

          if (result == _RefreshResult.rejected) {
            // Refresh token sai/hết hạn -> hết phiên thật sự
            await TokenStorage.clear();
            onSessionExpired?.call();
          }
          // networkError: chỉ báo lỗi mạng, KHÔNG đăng xuất người dùng
        }
        handler.next(e);
      },
    ));
  }

  Future<_RefreshResult>? _refreshing;

  /// Nhiều request cùng 401 chỉ gọi refresh 1 lần (token xoay vòng, gọi 2 lần
  /// bằng cùng 1 refresh token cũ sẽ bị từ chối).
  Future<_RefreshResult> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshResult> _doRefresh() async {
    final rt = await TokenStorage.refresh;
    if (rt == null) return _RefreshResult.rejected;
    try {
      final res = await Dio(BaseOptions(
        baseUrl: Constants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      )).post('/auth/refresh', data: {'refreshToken': rt});
      await TokenStorage.save(
        res.data['accessToken'],
        res.data['refreshToken'], // phải lưu token mới (rotation)
        accountJson: jsonEncode(res.data['account']),
      );
      return _RefreshResult.ok;
    } on DioException catch (e) {
      if (e.response == null) return _RefreshResult.networkError;
      return _RefreshResult.rejected;
    } catch (_) {
      return _RefreshResult.rejected;
    }
  }
}
