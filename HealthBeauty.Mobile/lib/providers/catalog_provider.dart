import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/catalog.dart';

/// Dịch vụ, loại dịch vụ, combo, khuyến mãi (cả 4 đều là API công khai).
class CatalogProvider extends ChangeNotifier {
  final _dio = ApiClient().dio;

  List<ServiceCategory> categories = [];
  List<Service> services = [];
  List<Combo> combos = [];
  List<Promotion> promotions = [];
  List<CustomerVoucher> myVouchers = [];
  List<Staff> staffList = [];

  bool loading = false;
  bool loaded = false;
  String? error;

  Future<void> load({bool force = false}) async {
    if (loading || (loaded && !force)) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        _dio.get('/service-categories'),
        _dio.get('/services'),
        _dio.get('/combos'),
        _dio.get('/promotions'),
      ]);
      categories = (r[0].data as List)
          .map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      services = (r[1].data as List)
          .map((e) => Service.fromJson(e as Map<String, dynamic>))
          .toList();
      combos = (r[2].data as List)
          .map((e) => Combo.fromJson(e as Map<String, dynamic>))
          .where((c) => c.active && c.isCurrent)
          .toList();
      promotions = (r[3].data as List)
          .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
          .toList();
      loaded = true;
      await Future.wait([
        loadMyVouchers(),
        loadStaff(),
      ]);
    } on DioException catch (e) {
      error = ApiError.message(e);
    } catch (e) {
      error = 'Dữ liệu trả về không đúng định dạng';
      if (kDebugMode) debugPrint('CatalogProvider parse error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Tải danh sách nhân viên thực hiện (GET /staff)
  Future<void> loadStaff() async {
    try {
      final res = await _dio.get('/staff');
      if (res.data is List) {
        staffList = (res.data as List)
            .map((e) => Staff.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Bỏ qua nếu có lỗi
    }
  }

  Staff? staffById(int id) {
    for (final s in staffList) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Tải danh sách voucher cá nhân của khách hàng (GET /customers/me/vouchers)
  Future<void> loadMyVouchers() async {
    try {
      final res = await _dio.get('/customers/me/vouchers');
      if (res.data is List) {
        myVouchers = (res.data as List)
            .map((e) => CustomerVoucher.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Bỏ qua nếu chưa đăng nhập hoặc lỗi tải voucher
    }
  }

  /// Kiểm tra mã voucher của khách đang đăng nhập.
  Future<VoucherCheck> validateVoucher(String code) async {
    try {
      final r = await _dio.post('/promotions/vouchers/validate',
          queryParameters: {'code': code.trim()});
      final d = r.data as Map<String, dynamic>;
      return VoucherCheck(
        valid: true,
        title: d['tenKhuyenMai'] as String?,
        value: (d['giaTriGiam'] as num?)?.toDouble(),
        expiresAt: DateTime.tryParse(d['hanSuDung']?.toString() ?? ''),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const VoucherCheck(
            valid: false, message: 'Mã không hợp lệ hoặc đã hết hạn');
      }
      return VoucherCheck(valid: false, message: ApiError.message(e));
    }
  }

  Service? serviceById(int id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  String categoryName(int id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return '';
  }
}
