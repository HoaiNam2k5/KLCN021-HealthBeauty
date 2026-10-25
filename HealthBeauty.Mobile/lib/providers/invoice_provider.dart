import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/token_storage.dart';
import '../models/invoice.dart';

class InvoiceProvider extends ChangeNotifier {
  InvoiceProvider({Dio? dio}) : _dio = dio ?? ApiClient().dio;
  final Dio _dio;
  static const pageSize = 50;
  int? _accountId;
  int _epoch = 0, _listRequest = 0;
  bool _disposed = false;
  int _offset = 0;
  int get accountVersion => _epoch;
  int? get accountId => _accountId;
  List<CustomerInvoice> invoices = [];
  final Map<int, CustomerInvoice> details = {};
  final Map<int, BankTransferInstructions> transfers = {};
  final Map<int, String> detailErrors = {}, transferErrors = {};
  final Set<int> loadingDetails = {}, loadingTransfers = {};
  bool loading = false, hasMore = true;
  String? error;
  CustomerInvoice? pendingInvoice;
  bool pendingLoading = false;
  String? pendingError;

  bool _current(int epoch, int session) =>
      !_disposed &&
      _accountId != null &&
      epoch == _epoch &&
      session == TokenStorage.sessionGeneration;

  void bind(int? accountId) {
    if (_disposed || _accountId == accountId) return;
    _accountId = accountId;
    _epoch++;
    _listRequest++;
    invoices = [];
    details.clear();
    transfers.clear();
    detailErrors.clear();
    transferErrors.clear();
    loadingDetails.clear();
    loadingTransfers.clear();
    loading = false;
    hasMore = true;
    _offset = 0;
    error = null;
    pendingInvoice = null;
    pendingLoading = false;
    pendingError = null;
    final epoch = _epoch;
    scheduleMicrotask(() {
      if (!_disposed && epoch == _epoch) notifyListeners();
    });
  }

  /// Query unpaid invoices separately so older unpaid invoices are not hidden
  /// behind the first page of newer paid invoices.
  Future<void> refreshPending() async {
    if (_disposed || _accountId == null || pendingLoading) return;
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    pendingLoading = true;
    pendingError = null;
    notifyListeners();
    try {
      final response = await _dio.get(
        '/invoices',
        queryParameters: {'status': 'ChuaThanhToan', 'offset': 0, 'limit': 1},
        options: Options(extra: {'sessionGeneration': session}),
      );
      final rows = (response.data as List)
          .map(
            (x) =>
                CustomerInvoice.fromJson(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
      if (!_current(epoch, session)) return;
      if (rows.any((x) => x.status != 'ChuaThanhToan')) {
        throw const FormatException('Unexpected pending invoice status');
      }
      final candidate = rows.firstOrNull;
      // A detail refresh may already have confirmed this invoice while the
      // pending-summary request was in flight. Never restore its stale banner.
      pendingInvoice =
          candidate != null && details[candidate.id]?.isPaid != true
          ? candidate
          : null;
    } on DioException catch (e) {
      if (_current(epoch, session)) pendingError = ApiError.message(e);
    } catch (_) {
      if (_current(epoch, session)) {
        pendingError = 'Không cập nhật được hóa đơn chờ thanh toán.';
      }
    } finally {
      if (_current(epoch, session)) {
        pendingLoading = false;
        notifyListeners();
      }
    }
  }

  /// Resolves an atomic completion notification using the appointment's
  /// already-persisted ID; invoice IDs do not exist until SaveChanges.
  Future<CustomerInvoice?> findForAppointment(int appointmentId) async {
    if (_disposed || _accountId == null || appointmentId <= 0) return null;
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    try {
      final response = await _dio.get(
        '/invoices',
        queryParameters: {
          'appointmentId': appointmentId,
          'offset': 0,
          'limit': 1,
        },
        options: Options(extra: {'sessionGeneration': session}),
      );
      final rows = (response.data as List)
          .map(
            (x) =>
                CustomerInvoice.fromJson(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
      if (!_current(epoch, session)) return null;
      if (rows.any((x) => x.appointmentId != appointmentId)) {
        throw const FormatException('Unexpected invoice appointment');
      }
      return rows.firstOrNull;
    } catch (_) {
      if (_current(epoch, session)) rethrow;
      return null;
    }
  }

  Future<void> load({bool more = false}) async {
    if (_disposed || _accountId == null || (more && (loading || !hasMore))) {
      return;
    }
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    final request = ++_listRequest;
    final offset = more ? _offset : 0;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _dio.get(
        '/invoices',
        queryParameters: {'offset': offset, 'limit': pageSize},
        options: Options(extra: {'sessionGeneration': session}),
      );
      final next = (response.data as List)
          .map(
            (x) =>
                CustomerInvoice.fromJson(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
      if (!_current(epoch, session) || request != _listRequest) return;
      final byId = {
        if (more)
          for (final item in invoices) item.id: item,
        for (final item in next) item.id: item,
      };
      invoices = byId.values.toList();
      _offset = offset + next.length;
      hasMore = next.length == pageSize;
    } on DioException catch (e) {
      if (_current(epoch, session) && request == _listRequest) {
        error = ApiError.message(e);
      }
    } catch (_) {
      if (_current(epoch, session) && request == _listRequest) {
        error = 'Không đọc được lịch sử hóa đơn. Vui lòng thử lại.';
      }
    } finally {
      if (_current(epoch, session) && request == _listRequest) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<CustomerInvoice?> loadDetail(int id) async {
    if (_disposed || _accountId == null || loadingDetails.contains(id)) {
      return null;
    }
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    loadingDetails.add(id);
    detailErrors.remove(id);
    notifyListeners();
    try {
      final response = await _dio.get(
        '/invoices/$id',
        options: Options(extra: {'sessionGeneration': session}),
      );
      final invoice = CustomerInvoice.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!_current(epoch, session)) return null;
      if (invoice.id != id) throw const FormatException('Invoice mismatch');
      details[id] = invoice;
      if (invoice.isPaid && pendingInvoice?.id == id) pendingInvoice = null;
      invoices = invoices.map((x) => x.id == id ? invoice : x).toList();
      if (!invoice.canTransfer ||
          (transfers[id] != null && transfers[id]!.amount != invoice.total)) {
        transfers.remove(id);
      }
      return invoice;
    } on DioException catch (e) {
      if (_current(epoch, session)) detailErrors[id] = ApiError.message(e);
    } catch (_) {
      if (_current(epoch, session)) {
        detailErrors[id] = 'Không đọc được hóa đơn. Vui lòng thử lại.';
      }
    } finally {
      if (_current(epoch, session)) {
        loadingDetails.remove(id);
        notifyListeners();
      }
    }
    return null;
  }

  Future<bool> requestTransfer(int id) async {
    if (_disposed ||
        _accountId == null ||
        loadingTransfers.contains(id) ||
        details[id]?.canTransfer != true ||
        detailErrors.containsKey(id)) {
      return false;
    }
    final epoch = _epoch, session = TokenStorage.sessionGeneration;
    loadingTransfers.add(id);
    transfers.remove(id);
    transferErrors.remove(id);
    notifyListeners();
    try {
      final response = await _dio.post(
        '/invoices/$id/bank-transfer',
        options: Options(extra: {'sessionGeneration': session}),
      );
      final instructions = BankTransferInstructions.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!_current(epoch, session)) return false;
      if (instructions.invoiceId != id ||
          instructions.amount <= 0 ||
          instructions.amount != details[id]?.total ||
          Uri.tryParse(instructions.qrImageUrl)?.scheme != 'https' ||
          instructions.accountNumber.isEmpty ||
          instructions.transferContent.isEmpty) {
        throw const FormatException('Invalid transfer instructions');
      }
      // A concurrent status refresh may have already confirmed payment.
      if (details[id]?.canTransfer != true) return false;
      transfers[id] = instructions;
      return true;
    } on DioException catch (e) {
      if (_current(epoch, session)) {
        transferErrors[id] = e.response?.statusCode == 503
            ? 'Thanh toán chuyển khoản chưa khả dụng. Vui lòng liên hệ lễ tân.'
            : ApiError.message(e);
      }
    } catch (_) {
      if (_current(epoch, session)) {
        transferErrors[id] =
            'Không lấy được thông tin chuyển khoản. Vui lòng thử lại.';
      }
    } finally {
      if (_current(epoch, session)) {
        loadingTransfers.remove(id);
        notifyListeners();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
