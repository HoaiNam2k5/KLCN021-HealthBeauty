import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/api_error.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../core/notification_service.dart';
import '../models/appointment.dart';
import '../models/booking_contract.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key, required this.appointment});
  final Appointment appointment;

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  late final DateTime _firstDay, _lastDay;
  late DateTime _selectedDay, _focusedDay;
  late final int _accountVersion;
  DateTime? _selectedSlot;
  List<AvailableAppointmentSlot> _slots = [];
  bool _loading = false;
  String? _slotsError, _submitError;
  int _request = 0;

  Appointment get appointment => widget.appointment;
  bool get _current =>
      mounted &&
      context.read<AuthProvider>().isLoggedIn &&
      context.read<AppointmentProvider>().accountVersion == _accountVersion;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDay = DateTime(now.year, now.month, now.day);
    final original = appointment.appointmentAt;
    final originalDay = DateTime(original.year, original.month, original.day);
    final normalLast = DateTime(now.year + 1, now.month, now.day);
    _lastDay = originalDay.isAfter(normalLast) ? originalDay : normalLast;
    _selectedDay = originalDay.isBefore(_firstDay) ? _firstDay : originalDay;
    _focusedDay = _selectedDay;
    _accountVersion = context.read<AppointmentProvider>().accountVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) _reloadSlots();
    });
  }

  Future<void> _reloadSlots() async {
    if (!_current) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _slotsError = null;
      _selectedSlot = null;
      _slots = [];
    });
    try {
      final slots = await context.read<AppointmentProvider>().availableSlots(
        date: _selectedDay,
        staffId: appointment.staffId,
        durationMinutes: appointment.durationMinutes,
        excludeAppointmentId: appointment.id,
      );
      if (!_current || request != _request) return;
      setState(() => _slots = slots);
    } on DioException catch (exception) {
      if (_current && request == _request) {
        setState(() => _slotsError = ApiError.message(exception));
      }
    } catch (_) {
      if (_current && request == _request) {
        setState(
          () =>
              _slotsError = 'Không tải được khung giờ trống. Vui lòng thử lại.',
        );
      }
    } finally {
      if (_current && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_current) return;
    final provider = context.read<AppointmentProvider>();
    final uncertain = provider.hasUncertainReschedule(appointment.id);
    final slot = _selectedSlot;
    if (!uncertain && slot == null) return;
    setState(() => _submitError = null);
    final updated = await provider.reschedule(
      id: appointment.id,
      at: slot ?? appointment.appointmentAt,
    );
    if (!_current) return;
    if (updated == null) {
      setState(
        () => _submitError =
            provider.error ?? 'Chưa xác nhận được kết quả đổi lịch.',
      );
      return;
    }
    // Notification scheduling must not turn a committed booking into a failure.
    try {
      await _refreshLocalReminder(updated);
    } catch (_) {
      // Backend appointment reminders remain available; the booking is committed.
    }
    if (mounted && _current) Navigator.pop(context, true);
  }

  Future<void> _refreshLocalReminder(Appointment updated) async {
    final notifications = NotificationService();
    await notifications.cancelReminder(updated.id);
    if (!_current) return;
    if (updated.isCancelled || updated.isDone) return;
    final match = RegExp(r'\[Nhắc hẹn:\s*([^\]]+)\]')
        .firstMatch(updated.note ?? '');
    final value = match?.group(1)?.toLowerCase();
    final count = int.tryParse(
      RegExp(r'\d+').firstMatch(value ?? '')?.group(0) ?? '',
    );
    if (count == null || count <= 0 || value == null) return;
    final duration = value.contains('ngày')
        ? Duration(days: count)
        : value.contains('giờ')
        ? Duration(hours: count)
        : value.contains('phút')
        ? Duration(minutes: count)
        : null;
    if (duration == null) return;
    await notifications.scheduleAppointmentReminder(
      id: updated.id,
      title: 'Nhắc nhở lịch hẹn ${updated.code}',
      body:
          'Lịch hẹn bắt đầu lúc ${timeStr(updated.appointmentAt)} (${dateStr(updated.appointmentAt)}).',
      reminderTime: updated.appointmentAt.subtract(duration),
    );
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    final provider = context.watch<AppointmentProvider>();
    if (!loggedIn || provider.accountVersion != _accountVersion) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đổi lịch hẹn')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Phiên đăng nhập đã thay đổi',
          subtitle: 'Vui lòng mở lại lịch hẹn sau khi đăng nhập.',
        ),
      );
    }
    final uncertain = provider.hasUncertainReschedule(appointment.id);
    final locked = provider.submitting || uncertain;
    final slots =
        _slots
            .map((item) => item.start)
            .toSet()
            .where(
              (slot) =>
                  slot.isAfter(DateTime.now()) &&
                  localBookingDateTime(slot) !=
                      localBookingDateTime(appointment.appointmentAt) &&
                  !provider.hasConflictAt(
                    slot,
                    durationMinutes: appointment.durationMinutes,
                    excludedId: appointment.id,
                  ),
            )
            .toList()
          ..sort();
    return Scaffold(
      appBar: AppBar(title: Text('Đổi lịch ${appointment.code}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch hiện tại',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(appointment.serviceSummary),
                  Text(
                    '${dateStr(appointment.appointmentAt)} · ${timeStr(appointment.appointmentAt)}',
                  ),
                  const Text(
                    'Giữ nguyên dịch vụ, nhân viên và ghi chú; chỉ đổi ngày giờ.',
                  ),
                  if (appointment.customerPackageId != null)
                    const Text(
                      'Lịch sử dụng gói đã mua; ngày mới phải nằm trong hạn sử dụng gói.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!appointment.canReschedule && !uncertain)
              const Text('Lịch hẹn này không còn được phép đổi.'),
            TableCalendar(
              firstDay: _firstDay,
              lastDay: _lastDay,
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => sameDay(day, _selectedDay),
              onDaySelected: locked
                  ? null
                  : (day, focused) {
                      setState(() {
                        _selectedDay = DateTime(day.year, day.month, day.day);
                        _focusedDay = focused;
                        _submitError = null;
                      });
                      _reloadSlots();
                    },
              onPageChanged: (day) => _focusedDay = day,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextFormatter: (date, _) =>
                    'Tháng ${date.month}, ${date.year}',
              ),
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppColors.rose,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionTitle('Khung giờ ${dateStr(_selectedDay)}'),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_slotsError != null)
              ErrorState(message: _slotsError!, onRetry: _reloadSlots)
            else if (slots.isEmpty)
              const Text('Không có khung giờ phù hợp. Vui lòng chọn ngày khác.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slots)
                    ChoiceChip(
                      label: Text(timeStr(slot)),
                      selected: _selectedSlot == slot,
                      onSelected: locked
                          ? null
                          : (_) => setState(() {
                              _selectedSlot = slot;
                              _submitError = null;
                            }),
                    ),
                ],
              ),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  provider.submitting ||
                      (!uncertain &&
                          (_selectedSlot == null || !appointment.canReschedule))
                  ? null
                  : _submit,
              icon: provider.submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_repeat),
              label: Text(
                provider.submitting
                    ? 'Đang kiểm tra...'
                    : uncertain
                    ? 'Kiểm tra kết quả đổi lịch'
                    : 'Xác nhận đổi lịch',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
