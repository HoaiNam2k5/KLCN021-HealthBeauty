import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/appointment.dart';

class AppointmentProvider extends ChangeNotifier {
  final _dio = ApiClient().dio;

  int? _accountId;
  List<Appointment> items = [];
  bool loading = false;
  bool submitting = false;
  String? error;

  /// Gắn với tài khoản đang đăng nhập. Đổi tài khoản/đăng xuất thì xóa dữ liệu cũ
  /// (không notify vì được gọi trong lúc build của ProxyProvider).
  void bind(int? accountId) {
    if (accountId == _accountId) return;
    _accountId = accountId;
    items = [];
    error = null;
    loading = false;
    submitting = false;
  }

  List<Appointment> get upcoming {
    final l = items.where((a) => a.isUpcoming).toList();
    l.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
    return l;
  }

  List<Appointment> get history {
    final l = items.where((a) => !a.isUpcoming).toList();
    l.sort((a, b) => b.appointmentAt.compareTo(a.appointmentAt));
    return l;
  }

  /// Backend trả 409 nếu cùng khách có lịch cùng thời điểm (chưa hủy).
  /// Kiểm tra trước ở app để tránh gọi thừa.
  bool hasConflictAt(DateTime t) => items.any((a) =>
      !a.isCancelled &&
      a.appointmentAt.year == t.year &&
      a.appointmentAt.month == t.month &&
      a.appointmentAt.day == t.day &&
      a.appointmentAt.hour == t.hour &&
      a.appointmentAt.minute == t.minute);

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.get('/appointments', queryParameters: {'pageSize': 100});
      final dynamic raw = res.data;
      final List listData = raw is List
          ? raw
          : (raw is Map && raw['items'] is List ? raw['items'] as List : []);
      items = listData
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      error = ApiError.message(e);
    } catch (e) {
      error = 'Dữ liệu trả về không đúng định dạng';
      if (kDebugMode) debugPrint('AppointmentProvider parse error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Hủy lịch hẹn (DELETE /appointments/{id})
  Future<bool> cancel(int id) async {
    try {
      await _dio.delete('/appointments/$id');
      final idx = items.indexWhere((a) => a.id == id);
      if (idx != -1) {
        items[idx] = items[idx].copyWith(status: 'DaHuy');
        notifyListeners();
      }
      return true;
    } on DioException catch (e) {
      error = ApiError.message(e);
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Không thể hủy lịch hẹn';
      notifyListeners();
      return false;
    }
  }

  /// Trả về lịch hẹn vừa tạo, hoặc null nếu lỗi (xem [error]).
  Future<Appointment?> create({
    required DateTime at,
    required List<Map<String, dynamic>> lines,
    String? note,
    int? staffId,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.post('/appointments', data: {
        // DateTime local -> "2026-10-14T14:30:00.000" (không có Z)
        'appointmentAt': at.toIso8601String(),
        'items': lines,
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        'staffId': staffId,
      });
      final created = Appointment.fromJson(res.data as Map<String, dynamic>);
      items = [created, ...items];
      return created;
    } on DioException catch (e) {
      error = ApiError.message(e);
      return null;
    } catch (e) {
      error = 'Không đọc được phản hồi từ máy chủ';
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
