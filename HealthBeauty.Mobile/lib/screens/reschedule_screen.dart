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
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';

class RescheduleScreen extends StatefulWidget {
  final Appointment appointment;

  const RescheduleScreen({super.key, required this.appointment});

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  late final DateTime _today;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  int? _selectedStaffId;
  DateTime? _selectedSlot;
  List<AvailableAppointmentSlot> _availableSlots = [];
  bool _slotsLoading = false;
  String? _slotsError;
  String? _submitError;
  int _availabilityRequest = 0;

  Appointment get appointment => widget.appointment;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final current = appointment.appointmentAt;
    final currentDay = DateTime(current.year, current.month, current.day);
    _selectedDay = currentDay.isBefore(_today) ? _today : currentDay;
    _focusedDay = _selectedDay;
    _selectedStaffId = appointment.staffId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final catalog = context.read<CatalogProvider>();
      if (catalog.staffList.isEmpty && !catalog.staffLoading) {
        catalog.loadStaff();
      }
      _reloadSlots();
    });
  }

  Future<void> _reloadSlots() async {
    final request = ++_availabilityRequest;
    setState(() {
      _slotsLoading = true;
      _slotsError = null;
      _availableSlots = [];
      _selectedSlot = null;
    });
    try {
      final slots = await context.read<AppointmentProvider>().availableSlots(
        date: _selectedDay,
        staffId: _selectedStaffId,
        durationMinutes: appointment.durationMinutes,
      );
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _availableSlots = slots);
    } on DioException catch (exception) {
      if (mounted && request == _availabilityRequest) {
        setState(() => _slotsError = ApiError.message(exception));
      }
    } catch (_) {
      if (mounted && request == _availabilityRequest) {
        setState(() {
          _slotsError = 'Không tải được khung giờ trống. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _slotsLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    if (slot == null) {
      setState(() => _submitError = 'Vui lòng chọn khung giờ mới.');
      return;
    }
    final provider = context.read<AppointmentProvider>();
    if (provider.hasConflictAt(
      slot,
      durationMinutes: appointment.durationMinutes,
      excludedId: appointment.id,
    )) {
      setState(() {
        _submitError = 'Thời gian mới bị trùng với một lịch hẹn khác của bạn.';
      });
      return;
    }

    setState(() => _submitError = null);
    final updated = await provider.reschedule(
      id: appointment.id,
      at: slot,
      staffId: _selectedStaffId,
      note: appointment.note,
    );
    if (!mounted) return;
    if (updated == null) {
      setState(() => _submitError = provider.error ?? 'Đổi lịch thất bại.');
      return;
    }

    await _refreshLocalReminder(updated);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _refreshLocalReminder(Appointment updated) async {
    final notifications = NotificationService();
    final reminder = _reminderDuration(updated.note);
    final catalog = context.read<CatalogProvider>();
    final staffName = updated.staffId == null
        ? 'Health Beauty Spa'
        : catalog.staffById(updated.staffId!)?.fullName ?? 'Kỹ thuật viên';
    await notifications.cancelReminder(updated.id);
    if (reminder == null) return;
    await notifications.scheduleAppointmentReminder(
      id: updated.id,
      title: 'Nhắc nhở lịch hẹn ${updated.code}',
      body:
          'Lịch hẹn spa của bạn sẽ bắt đầu lúc ${timeStr(updated.appointmentAt)} (${dateStr(updated.appointmentAt)}). Kỹ thuật viên: $staffName.',
      reminderTime: updated.appointmentAt.subtract(reminder),
    );
  }

  Duration? _reminderDuration(String? note) {
    if (note == null) return null;
    final match = RegExp(r'\[Nhắc hẹn:\s*([^\]]+)\]').firstMatch(note);
    final value = match?.group(1)?.trim().toLowerCase();
    if (value == null || value == 'không nhắc') return null;
    final amount = int.tryParse(
      RegExp(r'\d+').firstMatch(value)?.group(0) ?? '',
    );
    if (amount == null) return null;
    if (value.contains('ngày')) return Duration(days: amount);
    if (value.contains('giờ')) return Duration(hours: amount);
    if (value.contains('phút')) return Duration(minutes: amount);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final submitting = context.watch<AppointmentProvider>().submitting;
    final slots = _availableSlots.map((item) => item.start).toSet().toList()
      ..sort();
    final now = DateTime.now();
    final usableSlots = slots
        .where(
          (slot) =>
              slot.isAfter(now) &&
              !context.read<AppointmentProvider>().hasConflictAt(
                slot,
                durationMinutes: appointment.durationMinutes,
                excludedId: appointment.id,
              ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Đổi lịch ${appointment.code}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _currentAppointmentCard(catalog),
                  const SizedBox(height: 20),
                  const SectionTitle('Chọn nhân viên thực hiện'),
                  const SizedBox(height: 8),
                  _staffSelector(catalog),
                  const SizedBox(height: 20),
                  const SectionTitle('Chọn ngày mới'),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
                      firstDay: _today,
                      lastDay: _today.add(const Duration(days: 60)),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Tháng',
                      },
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate: (day) => sameDay(day, _selectedDay),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                          );
                          _focusedDay = focused;
                        });
                        _reloadSlots();
                      },
                      onPageChanged: (focused) => _focusedDay = focused,
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
                  ),
                  const SizedBox(height: 20),
                  SectionTitle('Khung giờ ${dateStr(_selectedDay)}'),
                  const SizedBox(height: 10),
                  if (_slotsLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_slotsError != null)
                    ErrorState(message: _slotsError!, onRetry: _reloadSlots)
                  else if (usableSlots.isEmpty)
                    const EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'Không còn khung giờ phù hợp',
                      subtitle: 'Vui lòng chọn ngày hoặc nhân viên khác',
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final slot in usableSlots)
                          ChoiceChip(
                            label: Text(timeStr(slot)),
                            selected: _selectedSlot == slot,
                            onSelected: (_) {
                              setState(() {
                                _selectedSlot = slot;
                                _submitError = null;
                              });
                            },
                          ),
                      ],
                    ),
                  if (_submitError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _submitError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.outline)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitting || _selectedSlot == null
                      ? null
                      : _submit,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_repeat),
                  label: Text(
                    submitting ? 'Đang đổi lịch...' : 'Xác nhận đổi lịch',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentAppointmentCard(CatalogProvider catalog) {
    final staff = appointment.staffId == null
        ? null
        : catalog.staffById(appointment.staffId!);
    return AppCard(
      color: AppColors.roseContainer.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch hiện tại',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(appointment.serviceSummary),
          const SizedBox(height: 4),
          Text(
            '${weekdayStr(appointment.appointmentAt)}, ${dateStr(appointment.appointmentAt)} · ${timeStr(appointment.appointmentAt)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Thời lượng ${durationStr(appointment.durationMinutes)} · ${staff?.fullName ?? 'Spa tự sắp xếp KTV'}',
          ),
        ],
      ),
    );
  }

  Widget _staffSelector(CatalogProvider catalog) {
    if (catalog.staffLoading && catalog.staffList.isEmpty) {
      return const LinearProgressIndicator();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _staffChoice(
            title: 'Bất kỳ nhân viên',
            subtitle: 'Spa tự sắp xếp',
            selected: _selectedStaffId == null,
            onTap: () => _selectStaff(null),
          ),
          for (final staff in catalog.staffList)
            _staffChoice(
              title: staff.fullName,
              subtitle: staff.displayTitle,
              selected: _selectedStaffId == staff.id,
              onTap: () => _selectStaff(staff.id),
            ),
        ],
      ),
    );
  }

  void _selectStaff(int? staffId) {
    if (_selectedStaffId == staffId) return;
    setState(() => _selectedStaffId = staffId);
    _reloadSlots();
  }

  Widget _staffChoice({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.roseContainer : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.rose : AppColors.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.person_outline,
                color: selected ? AppColors.rose : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
