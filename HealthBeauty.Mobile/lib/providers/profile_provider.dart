import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/customer.dart';
import '../core/avatar_image.dart';
import '../core/token_storage.dart';

class ProfileProvider extends ChangeNotifier {
  final Dio _dio;
  ProfileProvider({Dio? dio}) : _dio = dio ?? ApiClient().dio;
  int? _accountId;
  int _epoch = 0;
  int _revision = 0;
  bool _disposed = false;
  Customer? customer;
  List<PointTransaction> transactions = [];
  bool loading = false;
  bool saving = false;
  bool avatarSaving = false;
  String? error;

  void bind(int? accountId) {
    if (_accountId == accountId) return;
    _accountId = accountId;
    _epoch++;
    customer = null;
    transactions = [];
    error = null;
    loading = false;
    saving = false;
    avatarSaving = false;
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;
  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }

  Future<void> load() async {
    if (_accountId == null || loading || _disposed) return;
    final epoch = _epoch;
    final revision = _revision;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final responses = await Future.wait([
        _dio.get('/customers/me'),
        _dio.get('/customers/me/points'),
      ]);
      if (!_current(epoch) || revision != _revision) return;
      final profile = Customer.fromJson(
        Map<String, dynamic>.from(responses[0].data as Map),
      );
      final points = Map<String, dynamic>.from(responses[1].data as Map);
      final parsed = ((points['transactions'] as List?) ?? [])
          .map(
            (item) => PointTransaction.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      customer = profile;
      transactions = parsed;
    } on DioException catch (exception) {
      if (_current(epoch) && revision == _revision) {
        error = ApiError.message(exception);
      }
    } catch (_) {
      if (_current(epoch) && revision == _revision) {
        error = 'Dữ liệu hồ sơ trả về không đúng định dạng';
      }
    } finally {
      if (_current(epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> update({
    required String fullName,
    String? phone,
    String? gender,
  }) async {
    if (_accountId == null || saving || avatarSaving || _disposed) return false;
    final epoch = _epoch;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final response = await _dio.put(
        '/customers/me',
        data: {
          'fullName': fullName.trim(),
          'phone': phone?.trim().isEmpty == false ? phone!.trim() : null,
          'gender': gender?.trim().isEmpty == false ? gender!.trim() : null,
        },
      );
      if (!_current(epoch)) return false;
      customer = Customer.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _revision++;
      return true;
    } on DioException catch (exception) {
      if (_current(epoch)) error = ApiError.message(exception);
      return false;
    } catch (_) {
      if (_current(epoch)) error = 'Dữ liệu hồ sơ trả về không đúng định dạng';
      return false;
    } finally {
      if (_current(epoch)) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateAvatar({List<int>? bytes, bool remove = false}) async {
    if (_accountId == null || saving || avatarSaving || _disposed) return false;
    final epoch = _epoch;
    final session = TokenStorage.sessionGeneration;
    avatarSaving = true;
    error = null;
    notifyListeners();
    try {
      late final Response<dynamic> response;
      if (remove) {
        response = await _dio.delete(
          '/customers/me/avatar',
          options: Options(extra: {'sessionGeneration': session}),
        );
      } else {
        if (bytes == null ||
            bytes.isEmpty ||
            bytes.length > maximumAvatarBytes) {
          throw const FormatException(
            'Ảnh đại diện phải có dung lượng từ 1 byte đến 5 MB.',
          );
        }
        final type = avatarImageContentType(bytes);
        if (type == null) {
          throw const FormatException('Vui lòng chọn ảnh JPG, PNG hoặc WebP.');
        }
        final extension = type == 'image/jpeg' ? 'jpg' : type.split('/').last;
        response = await _dio.post(
          '/customers/me/avatar',
          data: FormData.fromMap({
            'File': MultipartFile.fromBytes(
              bytes,
              filename: 'avatar.$extension',
              contentType: DioMediaType.parse(type),
            ),
          }),
          options: Options(extra: {'sessionGeneration': session}),
        );
      }
      if (!_current(epoch)) return false;
      customer = Customer.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _revision++;
      return true;
    } on FormatException catch (exception) {
      if (_current(epoch)) error = exception.message;
      return false;
    } on DioException catch (exception) {
      if (_current(epoch)) {
        error = switch (exception.response?.statusCode) {
          400 => 'Ảnh không hợp lệ. Vui lòng chọn ảnh JPG, PNG hoặc WebP.',
          413 => 'Ảnh vượt quá 5 MB. Vui lòng chọn ảnh nhỏ hơn.',
          409 => 'Hồ sơ vừa thay đổi. Vui lòng tải lại rồi thử lại.',
          503 => 'Dịch vụ tải ảnh chưa được cấu hình. Vui lòng liên hệ Spa.',
          502 || 504 => 'Dịch vụ lưu ảnh đang bận. Vui lòng thử lại.',
          _ => ApiError.message(exception),
        };
      }
      return false;
    } catch (_) {
      if (_current(epoch)) {
        error = 'Không cập nhật được ảnh đại diện. Vui lòng thử lại.';
      }
      return false;
    } finally {
      if (_current(epoch)) {
        avatarSaving = false;
        notifyListeners();
      }
    }
  }
}
