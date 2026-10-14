import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/appointment.dart';
import '../models/booking_contract.dart';

class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;
  int? _accountId;
  int _generation = 0;
  int _revision = 0;
  bool _disposed = false;
  List<Appointment> items = [];
  bool loading = false;
  bool submitting = false;
  String? error;

  bool _current(int generation) =>
      !_disposed && generation == _generation && _accountId != null;

  // Called from ProxyProvider: reset account data without notifying during build.
  void bind(int? accountId) {
    if (accountId == _accountId) return;
    _accountId = accountId;
    _generation++;
    items = [];
    error = null;
    loading = false;
    submitting = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  List<Appointment> get upcoming {
    final list = items.where((item) => item.isUpcoming).toList();
    list.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
    return list;
  }

  List<Appointment> get history {
    final list = items.where((item) => !item.isUpcoming).toList();
    list.sort((a, b) => b.appointmentAt.compareTo(a.appointmentAt));
    return list;
  }

  bool hasConflictAt(
    DateTime start, {
    int durationMinutes = 30,
    int? excludedId,
  }) {
    final end = start.add(
      Duration(minutes: durationMinutes > 0 ? durationMinutes : 30),
    );
    return items.any(
      (item) =>
          !item.isCancelled &&
          item.id != excludedId &&
          item.appointmentAt.isBefore(end) &&
          start.isBefore(
            item.appointmentAt.add(Duration(minutes: item.durationMinutes)),
          ),
    );
  }

  Future<void> load() async {
    if (loading || _accountId == null || _disposed) return;
    final generation = _generation;
    final revision = _revision;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final loaded = <Appointment>[];
      var page = 1;
      var totalCount = 0;
      do {
        final response = await _dio.get(
          '/appointments',
          queryParameters: {'page': page, 'pageSize': 100},
        );
        if (!_current(generation)) return;
        final raw = response.data;
        if (raw is! Map || raw['items'] is! List || raw['totalCount'] is! num) {
          throw const FormatException('Invalid appointment list response.');
        }
        final rows = raw['items'] as List;
        totalCount = (raw['totalCount'] as num).toInt();
        loaded.addAll(
          rows.map(
            (row) =>
                Appointment.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
        );
        if (rows.isEmpty) break;
        page++;
      } while (loaded.length < totalCount);
      if (_current(generation) && revision == _revision) items = loaded;
    } on DioException catch (exception) {
      if (_current(generation) && revision == _revision) {
        error = ApiError.message(exception);
      }
    } catch (exception) {
      if (_current(generation) && revision == _revision) {
        error = 'Dữ liệu lịch hẹn trả về không đúng định dạng';
        if (kDebugMode) {
          debugPrint('AppointmentProvider parse error: $exception');
        }
      }
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<List<AvailableAppointmentSlot>> availableSlots({
    required DateTime date,
    int? staffId,
    required int durationMinutes,
  }) async {
    final generation = _generation;
    if (!_current(generation)) return [];
    if (durationMinutes < 1 || durationMinutes > 1440) {
      throw const FormatException(
        'Thời lượng đặt lịch phải từ 1 đến 1440 phút.',
      );
    }
    final response = await _dio.get(
      '/appointments/availability',
      queryParameters: {
        'date': localBookingDateTime(date).split('T').first,
        'staffId': ?staffId,
        'durationMinutes': durationMinutes,
      },
    );
    if (!_current(generation)) return [];
    if (response.data is! List) {
      throw const FormatException('Invalid availability response.');
    }
    return (response.data as List)
        .map(
          (row) => AvailableAppointmentSlot.fromJson(
            Map<String, dynamic>.from(row as Map),
            date,
          ),
        )
        .toList();
  }

  Future<bool> cancel(int id) async {
    final generation = _generation;
    if (!_current(generation)) return false;
    final matches = items.where((item) => item.id == id);
    if (matches.isNotEmpty && !matches.first.canCancel) {
      error = 'Lịch hẹn này không còn được phép hủy.';
      notifyListeners();
      return false;
    }
    error = null;
    try {
      await _dio.delete('/appointments/$id');
      if (!_current(generation)) return false;
      _revision++;
      final index = items.indexWhere((item) => item.id == id);
      if (index != -1) items[index] = items[index].copyWith(status: 'DaHuy');
      notifyListeners();
      return true;
    } on DioException catch (exception) {
      if (_current(generation)) error = ApiError.message(exception);
    } catch (_) {
      if (_current(generation)) error = 'Không thể hủy lịch hẹn';
    }
    if (_current(generation)) notifyListeners();
    return false;
  }

  Future<Appointment?> create({
    required DateTime at,
    required List<Map<String, dynamic>> lines,
    String? note,
    int? staffId,
  }) async {
    final generation = _generation;
    if (!_current(generation) || submitting) return null;
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final response = await _dio.post(
        '/appointments',
        data: {
          'appointmentAt': localBookingDateTime(at),
          'items': lines,
          'note': note == null || note.trim().isEmpty ? null : note.trim(),
          'staffId': staffId,
        },
      );
      if (!_current(generation)) return null;
      final created = Appointment.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _revision++;
      items = [created, ...items.where((item) => item.id != created.id)];
      return created;
    } on DioException catch (exception) {
      if (_current(generation)) error = ApiError.message(exception);
    } catch (_) {
      if (_current(generation)) {
        error = 'Không đọc được phản hồi lịch hẹn từ máy chủ';
      }
    } finally {
      if (_current(generation)) {
        submitting = false;
        notifyListeners();
      }
    }
    return null;
  }
}
