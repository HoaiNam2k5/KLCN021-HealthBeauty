import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/customer.dart';

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
    if (_accountId == null || saving || _disposed) return false;
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
}
