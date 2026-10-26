import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/token_storage.dart';
import '../models/catalog.dart';
import '../models/review.dart';

class CatalogProvider extends ChangeNotifier {
  final Dio _dio;
  CatalogProvider({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  List<ServiceCategory> categories = [];
  List<Service> services = [];
  List<Combo> combos = [];
  List<Promotion> promotions = [];
  List<CustomerVoucher> myVouchers = [];
  List<VoucherOffer> voucherOffers = [];
  List<Staff> staffList = [];

  bool loading = false;
  bool loaded = false;
  String? error;
  bool vouchersLoading = false;
  String? voucherError;
  bool offersLoading = false;
  String? offerError;
  int? redeemingVoucherId;
  bool staffLoading = false;
  String? staffError;
  int? _accountId;
  int get accountVersion => _accountVersion;
  int? get accountId => _accountId;
  int _accountVersion = 0;
  int _voucherRequest = 0;
  int _offerRequest = 0;
  int _staffRequest = 0;
  bool _disposed = false;

  /// Public catalog survives account changes; authenticated data never does.
  void bind(int? accountId) {
    if (_disposed || _accountId == accountId) return;
    _accountId = accountId;
    final version = ++_accountVersion;
    _voucherRequest++;
    _offerRequest++;
    _staffRequest++;
    myVouchers = [];
    voucherOffers = [];
    staffList = [];
    vouchersLoading = false;
    offersLoading = false;
    redeemingVoucherId = null;
    staffLoading = false;
    voucherError = null;
    offerError = null;
    staffError = null;
    // ProxyProvider may bind while building. Notify and refresh after that build.
    scheduleMicrotask(() {
      if (!_isCurrent(version)) return;
      _notify();
      if (_accountId != null) {
        unawaited(loadMyVouchers());
        unawaited(loadVoucherOffers());
        unawaited(loadStaff());
      }
    });
  }

  bool _isCurrent(int version) => !_disposed && version == _accountVersion;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (_disposed || loading || (loaded && !force)) return;
    loading = true;
    error = null;
    _notify();
    try {
      final r = await Future.wait([
        _dio.get('/service-categories'),
        _dio.get('/services'),
        _dio.get('/combos'),
        _dio.get('/promotions'),
      ]);
      final nextCategories = (r[0].data as List)
          .map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      final nextServices = (r[1].data as List)
          .map((e) => Service.fromJson(e as Map<String, dynamic>))
          .toList();
      final nextCombos = (r[2].data as List)
          .map((e) => Combo.fromJson(e as Map<String, dynamic>))
          .where((c) => c.active && c.isCurrent)
          .toList();
      final nextPromotions = (r[3].data as List)
          .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_disposed) return;
      categories = nextCategories;
      services = nextServices;
      combos = nextCombos;
      promotions = nextPromotions;
      loaded = true;
      await Future.wait([loadMyVouchers(), loadVoucherOffers(), loadStaff()]);
    } on DioException catch (e) {
      if (!_disposed) error = ApiError.message(e);
    } catch (e) {
      if (!_disposed) error = 'Dữ liệu danh mục trả về không đúng định dạng';
      if (kDebugMode) debugPrint('CatalogProvider parse error: $e');
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadStaff() async {
    if (_disposed || _accountId == null || staffLoading) return;
    final version = _accountVersion;
    final request = ++_staffRequest;
    staffList = [];
    staffError = null;
    staffLoading = true;
    _notify();
    try {
      final res = await _dio.get('/staff');
      final next = (res.data as List)
          .map((e) => Staff.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!_isCurrent(version) || request != _staffRequest) return;
      staffList = next;
    } on DioException catch (e) {
      if (_isCurrent(version) && request == _staffRequest) {
        staffError = ApiError.message(e);
      }
    } catch (_) {
      if (_isCurrent(version) && request == _staffRequest) {
        staffError = 'Dữ liệu nhân viên trả về không đúng định dạng';
      }
    } finally {
      if (_isCurrent(version) && request == _staffRequest) {
        staffLoading = false;
        _notify();
      }
    }
  }

  Staff? staffById(int id) {
    for (final s in staffList) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> loadMyVouchers({bool force = false}) async {
    if (_disposed || _accountId == null || (vouchersLoading && !force)) return;
    final version = _accountVersion;
    final session = TokenStorage.sessionGeneration;
    final request = ++_voucherRequest;
    myVouchers = [];
    voucherError = null;
    vouchersLoading = true;
    _notify();
    try {
      final res = await _dio.get(
        '/customers/me/vouchers',
        options: Options(extra: {'sessionGeneration': session}),
      );
      final now = DateTime.now();
      final next = (res.data as List)
          .map((e) => CustomerVoucher.fromJson(e as Map<String, dynamic>))
          .where((voucher) => voucher.isAvailableAt(now))
          .toList();
      if (!_isCurrent(version) ||
          session != TokenStorage.sessionGeneration ||
          request != _voucherRequest) {
        return;
      }
      myVouchers = next;
    } on DioException catch (e) {
      if (_isCurrent(version) &&
          session == TokenStorage.sessionGeneration &&
          request == _voucherRequest) {
        voucherError = ApiError.message(e);
      }
    } catch (_) {
      if (_isCurrent(version) &&
          session == TokenStorage.sessionGeneration &&
          request == _voucherRequest) {
        voucherError = 'Dữ liệu voucher trả về không đúng định dạng';
      }
    } finally {
      if (_isCurrent(version) &&
          session == TokenStorage.sessionGeneration &&
          request == _voucherRequest) {
        vouchersLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadVoucherOffers({bool force = false}) async {
    if (_disposed || _accountId == null || (offersLoading && !force)) return;
    final version = _accountVersion, session = TokenStorage.sessionGeneration;
    final request = ++_offerRequest;
    offersLoading = true;
    offerError = null;
    _notify();
    try {
      final response = await _dio.get(
        '/customers/me/voucher-offers',
        options: Options(extra: {'sessionGeneration': session}),
      );
      final now = DateTime.now();
      final next =
          (response.data as List)
              .map(
                (x) =>
                    VoucherOffer.fromJson(Map<String, dynamic>.from(x as Map)),
              )
              .where((offer) => offer.isAvailableAt(now))
              .toList()
            ..sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
      if (!_isCurrent(version) ||
          session != TokenStorage.sessionGeneration ||
          request != _offerRequest) {
        return;
      }
      voucherOffers = next;
    } on DioException catch (e) {
      if (_isCurrent(version) &&
          session == TokenStorage.sessionGeneration &&
          request == _offerRequest) {
        offerError = ApiError.message(e);
      }
    } catch (_) {
      if (_isCurrent(version) &&
          session == TokenStorage.sessionGeneration &&
          request == _offerRequest) {
        offerError = 'Không đọc được danh sách voucher đổi điểm.';
      }
    } finally {
      if (_isCurrent(version) &&
          session == TokenStorage.sessionGeneration &&
          request == _offerRequest) {
        offersLoading = false;
        _notify();
      }
    }
  }

  Future<VoucherRedemption?> redeemVoucher(
    int voucherId, {
    required int expectedPointsCost,
    required int expectedAccountVersion,
  }) async {
    if (_disposed ||
        _accountId == null ||
        redeemingVoucherId != null ||
        expectedAccountVersion != _accountVersion ||
        expectedPointsCost <= 0) {
      return null;
    }
    final version = _accountVersion, session = TokenStorage.sessionGeneration;
    bool current() =>
        _isCurrent(version) && session == TokenStorage.sessionGeneration;
    redeemingVoucherId = voucherId;
    offerError = null;
    _notify();
    try {
      final response = await _dio.post(
        '/customers/me/vouchers/$voucherId/redeem',
        data: {'expectedPointsCost': expectedPointsCost},
        options: Options(extra: {'sessionGeneration': session}),
      );
      if (!current()) return null;
      final result = VoucherRedemption.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (result.voucherId != voucherId ||
          result.pointsSpent != expectedPointsCost) {
        throw const FormatException('Unexpected redemption result');
      }
      // A pre-redemption wallet request must not win over this fresh read.
      await Future.wait([
        loadMyVouchers(force: true),
        loadVoucherOffers(force: true),
      ]);
      return current() ? result : null;
    } on DioException catch (e) {
      if (current()) {
        final uncertain =
            e.response == null || (e.response?.statusCode ?? 0) >= 500;
        final message = uncertain
            ? 'Chưa xác nhận được kết quả đổi voucher. Kiểm tra lại ví và điểm trước khi thử lại.'
            : switch (e.response?.statusCode) {
                400 => 'Số điểm hiện có không đủ để đổi voucher này.',
                404 => 'Voucher đã hết hạn hoặc không còn khả dụng.',
                409 => 'Voucher hoặc mức điểm vừa thay đổi. Vui lòng kiểm tra và xác nhận lại.',
                _ => ApiError.message(e),
              };
        await Future.wait([
          loadMyVouchers(force: true),
          loadVoucherOffers(force: true),
        ]);
        if (current()) offerError = message;
      }
    } catch (_) {
      if (current()) {
        await Future.wait([
          loadMyVouchers(force: true),
          loadVoucherOffers(force: true),
        ]);
        if (current()) offerError = 'Chưa đọc được kết quả. Vui lòng kiểm tra ví và điểm trước khi thử lại.';
      }
    } finally {
      if (current()) {
        redeemingVoucherId = null;
        _notify();
      }
    }
    return null;
  }

  Future<VoucherCheck> validateVoucher(String code) async {
    final normalized = code.trim().toUpperCase();
    if (_disposed || _accountId == null) {
      return const VoucherCheck(
        valid: false,
        message: 'Vui lòng đăng nhập để kiểm tra voucher.',
      );
    }
    if (normalized.isEmpty) {
      return const VoucherCheck(
        valid: false,
        message: 'Vui lòng nhập mã voucher.',
      );
    }
    final version = _accountVersion;
    try {
      final response = await _dio.post(
        '/promotions/vouchers/validate',
        queryParameters: {'code': normalized},
      );
      if (!_isCurrent(version)) {
        return const VoucherCheck(
          valid: false,
          message: 'Phiên đăng nhập đã thay đổi, vui lòng kiểm tra lại.',
        );
      }
      return VoucherCheck.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (!_isCurrent(version)) {
        return const VoucherCheck(
          valid: false,
          message: 'Phiên đăng nhập đã thay đổi, vui lòng kiểm tra lại.',
        );
      }
      if (e.response?.statusCode == 404) {
        return const VoucherCheck(
          valid: false,
          message: 'Mã không hợp lệ hoặc đã hết hạn.',
        );
      }
      return VoucherCheck(valid: false, message: ApiError.message(e));
    } catch (_) {
      return const VoucherCheck(
        valid: false,
        message: 'Dữ liệu kiểm tra voucher trả về không đúng định dạng.',
      );
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

  Future<ReviewSummary> loadServiceReviews(int serviceId) async {
    try {
      final res = await _dio.get(
        '/reviews',
        queryParameters: {'serviceId': serviceId},
      );
      if (res.data is Map) {
        return ReviewSummary.fromJson(
          Map<String, dynamic>.from(res.data as Map),
        );
      }
      return const ReviewSummary();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading reviews for service $serviceId: $e');
      }
      return const ReviewSummary();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _accountVersion++;
    super.dispose();
  }
}
