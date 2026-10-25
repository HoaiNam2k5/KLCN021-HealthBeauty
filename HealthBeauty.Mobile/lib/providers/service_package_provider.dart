import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/token_storage.dart';
import '../models/service_package.dart';

class ServicePackageProvider extends ChangeNotifier {
  ServicePackageProvider({Dio? dio}) : _dio = dio ?? ApiClient().dio;
  final Dio _dio;
  int? _accountId;
  int get accountVersion => _epoch;
  int? get accountId => _accountId;
  int _epoch = 0, _revision = 0, _mineRequest = 0, _detailRequest = 0;
  bool _disposed = false;
  List<ServicePackageOffer> catalog = [];
  List<CustomerServicePackage> mine = [];
  final Map<int, CustomerPackageDetail> details = {};
  bool catalogLoading = false,
      mineLoading = false,
      detailLoading = false,
      purchasing = false,
      cancelling = false;
  String? catalogError, mineError, detailError, actionError;
  bool _current(int epoch) =>
      !_disposed && epoch == _epoch && _accountId != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void bind(int? accountId) {
    if (_disposed || accountId == _accountId) return;
    _accountId = accountId;
    _epoch++;
    _revision++;
    _mineRequest++;
    _detailRequest++;
    mine = [];
    details.clear();
    mineLoading = false;
    detailLoading = false;
    purchasing = false;
    cancelling = false;
    mineError = null;
    detailError = null;
    actionError = null;
    final epoch = _epoch;
    scheduleMicrotask(() {
      if (!_disposed && epoch == _epoch) _notify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }

  Future<void> loadCatalog() async {
    if (_disposed || catalogLoading) return;
    catalogLoading = true;
    catalogError = null;
    _notify();
    try {
      final response = await _dio.get(
        '/service-packages',
        options: Options(extra: {'skipAuth': true}),
      );
      final next = (response.data as List)
          .map(
            (x) => ServicePackageOffer.fromJson(
              Map<String, dynamic>.from(x as Map),
            ),
          )
          .where((x) => x.active)
          .toList();
      if (!_disposed) catalog = next;
    } on DioException catch (e) {
      if (!_disposed) catalogError = ApiError.message(e);
    } catch (_) {
      if (!_disposed) catalogError = 'Không đọc được danh sách gói dịch vụ.';
    } finally {
      if (!_disposed) {
        catalogLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMine() async {
    if (_disposed || _accountId == null || mineLoading) return;
    final epoch = _epoch, revision = _revision, request = ++_mineRequest;
    final session = TokenStorage.sessionGeneration;
    mineLoading = true;
    mineError = null;
    _notify();
    try {
      final response = await _dio.get(
        '/service-packages/mine',
        options: Options(extra: {'sessionGeneration': session}),
      );
      final next = (response.data as List)
          .map(
            (x) => CustomerServicePackage.fromJson(
              Map<String, dynamic>.from(x as Map),
            ),
          )
          .toList();
      if (_current(epoch) && revision == _revision && request == _mineRequest) {
        mine = next;
      }
    } on DioException catch (e) {
      if (_current(epoch) && revision == _revision && request == _mineRequest) {
        mineError = ApiError.message(e);
      }
    } catch (_) {
      if (_current(epoch) && revision == _revision && request == _mineRequest) {
        mineError = 'Không đọc được gói đã mua.';
      }
    } finally {
      if (_current(epoch) && request == _mineRequest) {
        mineLoading = false;
        _notify();
      }
    }
  }

  Future<CustomerPackageDetail?> loadDetail(int id) async {
    if (_disposed || _accountId == null) return null;
    final epoch = _epoch, revision = _revision, request = ++_detailRequest;
    final session = TokenStorage.sessionGeneration;
    detailLoading = true;
    detailError = null;
    _notify();
    try {
      final response = await _dio.get(
        '/service-packages/purchases/$id',
        options: Options(extra: {'sessionGeneration': session}),
      );
      final detail = CustomerPackageDetail.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!_current(epoch) ||
          revision != _revision ||
          request != _detailRequest) {
        return null;
      }
      if (detail.package.id != id) {
        throw const FormatException('Wrong purchase.');
      }
      details[id] = detail;
      _replace(detail.package);
      return detail;
    } on DioException catch (e) {
      if (_current(epoch) &&
          revision == _revision &&
          request == _detailRequest) {
        detailError = ApiError.message(e);
      }
    } catch (_) {
      if (_current(epoch) &&
          revision == _revision &&
          request == _detailRequest) {
        detailError = 'Không đọc được chi tiết gói đã mua.';
      }
    } finally {
      if (_current(epoch) && request == _detailRequest) {
        detailLoading = false;
        _notify();
      }
    }
    return null;
  }

  void _replace(CustomerServicePackage p) {
    mine = [p, ...mine.where((x) => x.id != p.id)]
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  String _actionMessage(DioException e) => switch (e.response?.statusCode) {
    null =>
      'Chưa xác nhận được kết quả. Hãy cập nhật Gói của tôi trước khi thử lại.',
    400 => 'Gói không còn phù hợp để thực hiện yêu cầu. Vui lòng cập nhật lại.',
    404 => 'Gói dịch vụ không còn khả dụng.',
    409 => 'Gói vừa thay đổi hoặc đã được thanh toán. Vui lòng cập nhật lại.',
    _ => ApiError.message(e),
  };
  Future<CustomerServicePackage?> purchase(int packageId) async {
    if (_disposed || _accountId == null || purchasing || cancelling) {
      return null;
    }
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    purchasing = true;
    actionError = null;
    _notify();
    try {
      if (!_current(epoch)) return null;
      final response = await _dio.post(
        '/service-packages/purchases',
        data: {'packageId': packageId},
        options: Options(extra: {'sessionGeneration': session}),
      );
      final owned = CustomerServicePackage.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!_current(epoch)) return null;
      _revision++;
      _mineRequest++;
      mineLoading = false;
      _replace(owned);
      return owned;
    } on DioException catch (e) {
      if (_current(epoch)) actionError = _actionMessage(e);
    } catch (_) {
      if (_current(epoch)) actionError = 'Chưa xác nhận được kết quả đăng ký. Hãy kiểm tra Gói của tôi trước khi thử lại.';
    } finally {
      if (_current(epoch)) {
        purchasing = false;
        _notify();
      }
    }
    return null;
  }

  Future<bool> cancelPurchase(int id) async {
    if (_disposed || _accountId == null || purchasing || cancelling) {
      return false;
    }
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    cancelling = true;
    actionError = null;
    _notify();
    try {
      if (!_current(epoch)) return false;
      await _dio.delete(
        '/service-packages/purchases/$id',
        options: Options(extra: {'sessionGeneration': session}),
      );
      if (!_current(epoch)) return false;
      _revision++;
      _mineRequest++;
      _detailRequest++;
      mineLoading = false;
      detailLoading = false;
      details.remove(id);
      mine = mine.where((x) => x.id != id).toList();
      return true;
    } on DioException catch (e) {
      if (_current(epoch)) actionError = _actionMessage(e);
    } catch (_) {
      if (_current(epoch)) {
        actionError = 'Không hủy được đăng ký gói. Vui lòng kiểm tra lại.';
      }
    } finally {
      if (_current(epoch)) {
        cancelling = false;
        _notify();
      }
    }
    return false;
  }

  void invalidateOwned() {
    if (_disposed) return;
    _revision++;
    _mineRequest++;
    _detailRequest++;
    mineLoading = false;
    detailLoading = false;
    details.clear();
    mine = [];
    _notify();
    if (_accountId != null) unawaited(loadMine());
  }
}
