import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/account.dart';
import 'constants.dart';
import 'token_storage.dart';

enum _RefreshResult { ok, rejected, networkError, stale }

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  final Dio dio;
  final Dio _refreshDio;
  void Function()? onSessionExpired;
  Future<_RefreshResult>? _refreshing;

  static BaseOptions _options() => BaseOptions(
    baseUrl: Constants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
  ApiClient._()
    : this.withDio(dio: Dio(_options()), refreshDio: Dio(_options()));

  ApiClient.withDio({required this.dio, required Dio refreshDio})
    // ignore: prefer_initializing_formals
    : _refreshDio = refreshDio {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final session = options.extra.putIfAbsent(
              'sessionGeneration',
              () => TokenStorage.sessionGeneration,
            );
            if (session != TokenStorage.sessionGeneration) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'Session changed before request.',
                ),
              );
            }
            final token = await TokenStorage.access;
            if (session != TokenStorage.sessionGeneration) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'Session changed while loading credentials.',
                ),
              );
            }
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.extra['skipAuth'] != true &&
              request.extra['sessionGeneration'] ==
                  TokenStorage.sessionGeneration &&
              (!request.path.contains('/auth/') ||
                  request.path == '/auth/change-password') &&
              request.extra['retried'] != true) {
            final result = await (_refreshing ??= _doRefresh().whenComplete(
              () => _refreshing = null,
            ));
            if (result == _RefreshResult.ok &&
                request.extra['sessionGeneration'] ==
                    TokenStorage.sessionGeneration) {
              request.extra['retried'] = true;
              request.headers['Authorization'] =
                  'Bearer ${await TokenStorage.access}';
              if (request.extra['sessionGeneration'] !=
                  TokenStorage.sessionGeneration) {
                return handler.next(error);
              }
              if (request.data is FormData) {
                request.data = (request.data as FormData).clone();
              }
              try {
                return handler.resolve(await dio.fetch(request));
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  // Logout may run after access expiry. Rotate only the captured session and
  // revoke its replacement immediately, without saving or restoring credentials.
  Future<void> revokeSession(String accessToken, String refreshToken) async {
    Future<void> revoke(String access, String refresh) async {
      await dio.post(
        '/auth/logout',
        data: {'refreshToken': refresh},
        options: Options(
          headers: {'Authorization': 'Bearer $access'},
          extra: {'skipAuth': true},
        ),
      );
    }

    try {
      await revoke(accessToken, refreshToken);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data is! Map ||
          data['accessToken'] is! String ||
          (data['accessToken'] as String).isEmpty ||
          data['refreshToken'] is! String ||
          (data['refreshToken'] as String).isEmpty) {
        throw const FormatException('Invalid logout refresh response.');
      }
      await revoke(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
    }
  }

  Future<_RefreshResult> _reject(int generation, {bool notify = true}) async {
    if (!await TokenStorage.clearIfCurrent(generation)) {
      return _RefreshResult.stale;
    }
    if (notify) {
      onSessionExpired?.call();
    }
    return _RefreshResult.rejected;
  }

  Future<_RefreshResult> _doRefresh() async {
    final generation = TokenStorage.generation;
    final token = await TokenStorage.refresh;
    if (TokenStorage.generation != generation) return _RefreshResult.stale;
    if (token == null) return _reject(generation, notify: false);
    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': token},
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['accessToken'] is! String ||
          (data['accessToken'] as String).isEmpty ||
          data['refreshToken'] is! String ||
          (data['refreshToken'] as String).isEmpty ||
          data['account'] is! Map<String, dynamic>) {
        return await _reject(generation);
      }
      final account = Account.fromJson(data['account']);
      if (account.role != 'Customer') return await _reject(generation);
      final saved = await TokenStorage.saveIfCurrent(
        generation,
        data['accessToken'],
        data['refreshToken'],
        accountJson: jsonEncode(data['account']),
      );
      if (!saved) {
        // The server rotated this session while logout/account switching won
        // locally. Revoke only this response's credentials, never stored ones.
        try {
          await dio.post(
            '/auth/logout',
            data: {'refreshToken': data['refreshToken']},
            options: Options(
              headers: {'Authorization': 'Bearer ${data['accessToken']}'},
              extra: {'skipAuth': true},
            ),
          );
        } catch (_) {
          // Cleanup is best effort when the server cannot be reached.
        }
        return _RefreshResult.stale;
      }
      return _RefreshResult.ok;
    } on DioException catch (error) {
      if (TokenStorage.generation != generation) return _RefreshResult.stale;
      final status = error.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        return await _reject(generation);
      }
      // Transient network/server/rate-limit errors preserve a valid saved session.
      return _RefreshResult.networkError;
    } catch (_) {
      return await _reject(generation);
    }
  }
}
