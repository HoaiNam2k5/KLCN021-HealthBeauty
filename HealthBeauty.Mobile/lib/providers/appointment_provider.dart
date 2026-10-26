import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/appointment.dart';
import '../models/booking_contract.dart';
import '../models/availability_day.dart';
import '../core/token_storage.dart';

class _RescheduleAttempt {
  const _RescheduleAttempt(this.original, this.at);
  final Appointment original;
  final DateTime at;
}

class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider({Dio? dio, DateTime Function()? now})
    : _dio = dio ?? ApiClient().dio,
      _now = now ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;
  int? _accountId;
  int get accountVersion => _generation;
  final Map<int, _RescheduleAttempt> _uncertainReschedules = {};
  bool hasUncertainReschedule(int id) => _uncertainReschedules.containsKey(id);
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
    _uncertainReschedules.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  List<Appointment> get upcoming {
    final now = _now();
    final list = items.where((item) => item.isUpcomingAt(now)).toList();
    list.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
    return list;
  }

  List<Appointment> get history {
    final now = _now();
    final list = items.where((item) => !item.isUpcomingAt(now)).toList();
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
    int? excludeAppointmentId,
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
        'excludeAppointmentId': ?excludeAppointmentId,
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

  Future<List<AvailableAppointmentDay>> availableDays({
    required DateTime from,
    required DateTime to,
    int? staffId,
    required int durationMinutes,
  }) async {
    final generation = _generation;
    if (!_current(generation)) return [];
    final range = DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
    if (range < 0 ||
        range > 60 ||
        durationMinutes < 1 ||
        durationMinutes > 1440) {
      throw const FormatException(
        'Khoảng lịch tối đa 61 ngày và thời lượng từ 1 đến 1440 phút.',
      );
    }
    final response = await _dio.get(
      '/appointments/availability/days',
      queryParameters: {
        'from': localBookingDateTime(from).split('T').first,
        'to': localBookingDateTime(to).split('T').first,
        'staffId': ?staffId,
        'durationMinutes': durationMinutes,
      },
    );
    if (!_current(generation)) return [];
    if (response.data is! List) {
      throw const FormatException('Invalid availability days response.');
    }
    return (response.data as List)
        .map(
          (row) => AvailableAppointmentDay.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<bool> cancel(int id) async {
    final generation = _generation;
    if (!_current(generation)) return false;
    if (hasUncertainReschedule(id)) {
      error = 'Vui lòng kiểm tra kết quả đổi lịch trước khi hủy lịch hẹn này.';
      notifyListeners();
      return false;
    }
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

  bool _matchesReschedule(Appointment row, _RescheduleAttempt attempt) =>
      row.id == attempt.original.id &&
      localBookingDateTime(row.appointmentAt) ==
          localBookingDateTime(attempt.at) &&
      row.staffId == attempt.original.staffId &&
      (row.note?.trim() ?? '') == (attempt.original.note?.trim() ?? '') &&
      row.customerPackageId == attempt.original.customerPackageId;

  void _storeRescheduled(Appointment row) {
    _revision++;
    items = [
      for (final old in items)
        if (old.id == row.id) row else old,
    ];
  }

  Future<Appointment?> _reconcileReschedule(
    int id,
    int generation,
    int session,
  ) async {
    final attempt = _uncertainReschedules[id];
    if (attempt == null) return null;
    bool current() =>
        _current(generation) && session == TokenStorage.sessionGeneration;
    try {
      final response = await _dio.get(
        '/appointments/$id',
        options: Options(extra: {'sessionGeneration': session}),
      );
      if (!current()) return null;
      final row = Appointment.fromRescheduleJson(
        Map<String, dynamic>.from(response.data as Map),
        fallback: attempt.original,
      );
      _storeRescheduled(row);
      if (_matchesReschedule(row, attempt)) {
        _uncertainReschedules.remove(id);
        error = null;
        return row;
      }
      if (!row.canReschedule) {
        _uncertainReschedules.remove(id);
        error = 'Trạng thái lịch hẹn đã được cửa hàng cập nhật. Vui lòng xem lại lịch hẹn.';
        return null;
      }
    } catch (_) {
      // A second network/parse error cannot establish whether the write committed.
    }
    if (current()) {
      error = 'Chưa xác nhận được kết quả đổi lịch. Bấm kiểm tra kết quả hoặc liên hệ lễ tân; không gửi đổi lịch lại.';
    }
    return null;
  }

  /// Change only the date/time, retaining booked services, assigned staff and note.
  /// An ambiguous result is reconciled by GET; a subsequent tap never repeats POST.
  Future<Appointment?> reschedule({
    required int id,
    required DateTime at,
  }) async {
    final generation = _generation;
    final session = TokenStorage.sessionGeneration;
    bool current() =>
        _current(generation) && session == TokenStorage.sessionGeneration;
    if (!current() || submitting) return null;
    final previous = items.where((row) => row.id == id).firstOrNull;
    if (previous == null) {
      error = 'Vui lòng tải lại danh sách lịch hẹn trước khi đổi lịch.';
      notifyListeners();
      return null;
    }
    if (!hasUncertainReschedule(id) && !previous.canReschedule) {
      error = 'Lịch hẹn này không còn được phép đổi.';
      notifyListeners();
      return null;
    }
    if (!hasUncertainReschedule(id) && !at.isAfter(_now())) {
      error = 'Thời gian hẹn mới phải ở trong tương lai.';
      notifyListeners();
      return null;
    }
    if (!hasUncertainReschedule(id) &&
        localBookingDateTime(at) ==
            localBookingDateTime(previous.appointmentAt)) {
      error = 'Vui lòng chọn ngày giờ khác lịch hẹn hiện tại.';
      notifyListeners();
      return null;
    }
    submitting = true;
    error = null;
    _revision++; // Do not let an older list response overwrite the committed update.
    notifyListeners();
    try {
      if (hasUncertainReschedule(id)) {
        return await _reconcileReschedule(id, generation, session);
      }
      final attempt = _RescheduleAttempt(previous, at);
      try {
        final response = await _dio.post(
          '/appointments/$id/reschedule',
          data: {
            'appointmentAt': localBookingDateTime(at),
            'staffId': previous.staffId,
            'note': previous.note,
          },
          options: Options(extra: {'sessionGeneration': session}),
        );
        if (!current()) return null;
        final row = Appointment.fromRescheduleJson(
          Map<String, dynamic>.from(response.data as Map),
          fallback: previous,
        );
        if (!_matchesReschedule(row, attempt)) {
          throw const FormatException('Unexpected reschedule response');
        }
        _storeRescheduled(row);
        return row;
      } on DioException catch (exception) {
        if (!current()) return null;
        final code = exception.response?.statusCode;
        if (code != null && code >= 400 && code < 500 && code != 408) {
          error = ApiError.message(exception);
          return null;
        }
      } catch (_) {
        if (!current()) return null;
      }
      _uncertainReschedules[id] = attempt;
      return await _reconcileReschedule(id, generation, session);
    } finally {
      if (current()) {
        submitting = false;
        notifyListeners();
      }
    }
  }

  Future<Appointment?> create({
    required DateTime at,
    required List<Map<String, dynamic>> lines,
    String? note,
    int? staffId,
    int? customerPackageId,
  }) async {
    final generation = _generation;
    if (!_current(generation) || submitting) return null;
    final session = TokenStorage.sessionGeneration;
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
          'customerPackageId': ?customerPackageId,
        },
        options: Options(extra: {'sessionGeneration': session}),
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

  Future<bool> submitReview({
    required int appointmentId,
    required int stars,
    String? comment,
  }) async {
    final generation = _generation;
    if (!_current(generation)) return false;
    error = null;
    notifyListeners();
    try {
      await _dio.post(
        '/reviews/appointments/$appointmentId',
        data: {
          'stars': stars,
          'comment': comment == null || comment.trim().isEmpty
              ? null
              : comment.trim(),
        },
      );
      if (!_current(generation)) return false;
      _revision++;
      final index = items.indexWhere((item) => item.id == appointmentId);
      if (index != -1) {
        items[index] = items[index].copyWith(
          hasReviewed: true,
          reviewStars: stars,
          reviewComment: comment == null || comment.trim().isEmpty
              ? null
              : comment.trim(),
          reviewedAt: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } on DioException catch (exception) {
      if (_current(generation)) error = ApiError.message(exception);
    } catch (_) {
      if (_current(generation)) {
        error = 'Không thể gửi đánh giá dịch vụ';
      }
    }
    if (_current(generation)) notifyListeners();
    return false;
  }
}
