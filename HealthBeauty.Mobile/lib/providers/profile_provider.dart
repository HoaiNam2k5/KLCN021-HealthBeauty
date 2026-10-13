import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/customer.dart';

/// Hồ sơ khách hàng + điểm thưởng.
class ProfileProvider extends ChangeNotifier {
  final _dio = ApiClient().dio;

  int? _accountId;
  Customer? customer;
  List<PointTransaction> transactions = [];
  bool loading = false;
  bool saving = false;
  String? error;

  void bind(int? accountId) {
    if (accountId == _accountId) return;
    _accountId = accountId;
    customer = null;
    transactions = [];
    error = null;
    loading = false;
    saving = false;
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        _dio.get('/customers/me'),
        _dio.get('/customers/me/points'),
      ]);
      customer = Customer.fromJson(r[0].data as Map<String, dynamic>);
      final pts = r[1].data as Map<String, dynamic>;
      transactions = ((pts['transactions'] as List?) ?? [])
          .map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      error = ApiError.message(e);
    } catch (e) {
      error = 'Dữ liệu trả về không đúng định dạng';
      if (kDebugMode) debugPrint('ProfileProvider parse error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> update({
    required String fullName,
    String? phone,
    String? gender,
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.put('/customers/me', data: {
        'fullName': fullName,
        'phone': (phone == null || phone.isEmpty) ? null : phone,
        'gender': (gender == null || gender.isEmpty) ? null : gender,
      });
      customer = Customer.fromJson(res.data as Map<String, dynamic>);
      return true;
    } on DioException catch (e) {
      error = ApiError.message(e);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
