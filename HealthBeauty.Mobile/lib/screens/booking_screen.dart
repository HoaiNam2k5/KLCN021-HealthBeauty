import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/app_theme.dart';
import '../core/api_error.dart';
import '../core/format.dart';
import '../core/notification_service.dart';
import '../models/catalog.dart';
import '../models/booking_contract.dart';
import '../models/availability_day.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Đặt lịch 3 bước:
/// Bước 1: Chọn dịch vụ & Combo
/// Bước 2: Chọn nhân viên thực hiện & Khung giờ
/// Bước 3: Chọn Voucher, Hình thức thanh toán, Nhắc hẹn & Xác nhận
class BookingScreen extends StatefulWidget {
  final Service? initialService;
  final Combo? initialCombo;
  final String? initialVoucherCode;
  const BookingScreen({
    super.key,
    this.initialService,
    this.initialCombo,
    this.initialVoucherCode,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final DateTime _today;
  int _step = 0;
  final Set<int> _serviceIds = {};
  final Set<int> _comboIds = {};
  int? _selectedStaffId; // null = bất kỳ nhân viên nào
  late DateTime _focused;
  DateTime? _day;
  DateTime? _slot;

  List<AvailableAppointmentSlot> _availableSlots = [];
  bool _slotsLoading = false;
  String? _slotsError;
  int _availabilityRequest = 0;
  List<AvailableAppointmentDay> _availableDays = [];
  bool _daysLoading = false;
  String? _daysError;
  int _daysRequest = 0;

  // Nhắc nhở trước giờ hẹn (mặc định 30 phút)
  Duration? _reminderBefore = const Duration(minutes: 30);

  // Voucher đã chọn
  String? _selectedVoucherCode;
  String? _selectedVoucherTitle;
  double? _selectedVoucherDiscount;

  // Hình thức thanh toán: 'TienMat' | 'ChuyenKhoan'
  String _paymentMethod = 'TienMat';

  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _focused = _today;
    if (widget.initialService != null) {
      _serviceIds.add(widget.initialService!.id);
    }
    if (widget.initialCombo != null) _comboIds.add(widget.initialCombo!.id);
    if (widget.initialVoucherCode != null) {
      _selectedVoucherCode = widget.initialVoucherCode;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // ---------- tính toán ----------

  List<Combo> _selectedCombos(CatalogProvider c) =>
      c.combos.where((x) => _comboIds.contains(x.id)).toList();

  List<Service> _selectedServices(CatalogProvider c) =>
      c.services.where((x) => _serviceIds.contains(x.id)).toList();

  double _total(CatalogProvider c) =>
      _selectedServices(c).fold(0.0, (s, e) => s + e.price) +
      _selectedCombos(c).fold(0.0, (s, e) => s + e.price);

  double _voucherDiscount(double rawTotal) {
    if (_selectedVoucherDiscount == null || _selectedVoucherDiscount! <= 0) {
      return 0;
    }
    return _selectedVoucherDiscount! > rawTotal
        ? rawTotal
        : _selectedVoucherDiscount!;
  }

  double _finalTotal(double rawTotal) {
    final discount = _voucherDiscount(rawTotal);
    final net = rawTotal - discount;
    return net < 0 ? 0 : net;
  }

  List<Map<String, dynamic>> _buildLines(
    CatalogProvider catalog, {
    bool discovery = false,
  }) {
    final services = _selectedServices(catalog);
    final combos = _selectedCombos(catalog);
    if (services.length != _serviceIds.length ||
        combos.length != _comboIds.length) {
      throw const FormatException(
        'Dịch vụ hoặc combo đã chọn không còn khả dụng.',
      );
    }
    return buildBookingLines(
      services: services,
      combos: combos,
      catalogServices: catalog.services,
      appointmentDate: discovery ? null : _day,
    );
  }

  int _minutes(CatalogProvider catalog, {bool discovery = false}) {
    try {
      return bookingDurationMinutes(
        _buildLines(catalog, discovery: discovery),
        catalog.services,
      );
    } on FormatException {
      return 0;
    }
  }

  List<DateTime> _bookableStarts(
    CatalogProvider catalog,
    AppointmentProvider appointments,
  ) {
    final minutes = _minutes(catalog, discovery: true);
    if (minutes < 1) return [];
    return bookableAvailabilityStarts(
      _availableDays,
      now: DateTime.now(),
      canBookDate: (date) => _selectedCombos(catalog).every(
        (combo) =>
            combo.active &&
            (combo.validFrom == null || !date.isBefore(combo.validFrom!)) &&
            (combo.validTo == null || !date.isAfter(combo.validTo!)),
      ),
      hasConflict: (start) =>
          appointments.hasConflictAt(start, durationMinutes: minutes),
    );
  }

  Future<void> _reloadDays() async {
    final request = ++_daysRequest;
    ++_availabilityRequest;
    final catalog = context.read<CatalogProvider>();
    final appointments = context.read<AppointmentProvider>();
    final minutes = _minutes(catalog, discovery: true);
    final staffId = _selectedStaffId;
    setState(() {
      _daysLoading = true;
      _daysError = null;
      _availableDays = [];
      _availableSlots = [];
      _slotsLoading = false;
      _slotsError = null;
      _day = null;
      _slot = null;
    });
    try {
      final days = await appointments.availableDays(
        from: _today,
        to: DateTime(_today.year, _today.month, _today.day + 60),
        staffId: staffId,
        durationMinutes: minutes,
      );
      if (!mounted || request != _daysRequest) return;
      setState(() => _availableDays = days);
    } on DioException catch (exception) {
      if (mounted && request == _daysRequest) {
        setState(() => _daysError = ApiError.message(exception));
      }
    } catch (_) {
      if (mounted && request == _daysRequest) {
        setState(
          () => _daysError =
              'Không tải được ngày còn lịch trống. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && request == _daysRequest) {
        setState(() => _daysLoading = false);
      }
    }
  }

  void _selectAvailableDay(DateTime selected) {
    setState(() {
      _day = DateTime(selected.year, selected.month, selected.day);
      _focused = _day!;
      _slot = null;
    });
    _reloadSlots();
  }

  Future<void> _reloadSlots() async {
    final request = ++_availabilityRequest;
    if (_day == null) return;
    final catalog = context.read<CatalogProvider>();
    final appointments = context.read<AppointmentProvider>();
    final date = _day!;
    final staffId = _selectedStaffId;
    final minutes = _minutes(catalog);
    setState(() {
      _slotsLoading = true;
      _slotsError = null;
      _availableSlots = [];
      _slot = null;
    });
    try {
      final slots = await appointments.availableSlots(
        date: date,
        staffId: staffId,
        durationMinutes: minutes,
      );
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _availableSlots = slots);
    } on DioException catch (exception) {
      if (mounted && request == _availabilityRequest) {
        setState(() => _slotsError = ApiError.message(exception));
      }
    } catch (_) {
      if (mounted && request == _availabilityRequest) {
        setState(
          () => _slotsError = 'Không tải được khung giờ trống. Vui lòng kiểm tra lựa chọn dịch vụ và thử lại.',
        );
      }
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _slotsLoading = false);
      }
    }
  }

  void _nextStep() {
    setState(() => _step++);
    if (_step == 1) {
      context.read<CatalogProvider>().loadStaff();
      _reloadDays();
    }
    if (_step == 2) {
      final auth = context.read<AuthProvider>();
      final catalog = context.read<CatalogProvider>();
      if (auth.isLoggedIn &&
          catalog.myVouchers.isEmpty &&
          !catalog.vouchersLoading) {
        catalog.loadMyVouchers();
      }
    }
  }

  bool _canNext(CatalogProvider c) {
    switch (_step) {
      case 0:
        return _minutes(c, discovery: true) > 0 &&
            _minutes(c, discovery: true) <= 1440;
      case 1:
        return _slot != null && !_slotsLoading && _slotsError == null;
      default:
        return _slot != null && _minutes(c) > 0;
    }
  }

  String _reminderText(Duration? d) {
    if (d == null) return 'Không nhắc';
    if (d.inDays >= 1) return '${d.inDays} ngày trước';
    if (d.inHours >= 1) return '${d.inHours} giờ trước';
    return '${d.inMinutes} phút trước';
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true ||
          !mounted ||
          !context.read<AuthProvider>().isLoggedIn) {
        return;
      }
    }

    final catalog = context.read<CatalogProvider>();
    final ap = context.read<AppointmentProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _error = null);
    List<Map<String, dynamic>> lines;
    try {
      lines = _buildLines(catalog);
      if (_slot == null || !_slot!.isAfter(DateTime.now())) {
        throw const FormatException(
          'Vui lòng chọn thời điểm đặt lịch trong tương lai.',
        );
      }
      if (ap.hasConflictAt(_slot!, durationMinutes: _minutes(catalog))) {
        throw const FormatException(
          'Thời gian hẹn bị trùng với lịch khác của bạn.',
        );
      }
    } on FormatException catch (exception) {
      setState(() => _error = exception.message);
      return;
    }

    // Voucher và hình thức thanh toán được ghi nhận cùng thông tin lịch hẹn.
    final noteParts = <String>[];
    if (_reminderBefore != null) {
      noteParts.add('[Nhắc hẹn: ${_reminderText(_reminderBefore)}]');
    }
    if (_selectedVoucherCode != null && _selectedVoucherCode!.isNotEmpty) {
      final discount = _voucherDiscount(_total(catalog));
      noteParts.add('[Voucher: $_selectedVoucherCode (-${vnd(discount)})]');
    }
    final paymentLabel = _paymentMethod == 'ChuyenKhoan'
        ? 'Chuyển khoản'
        : 'Tiền mặt';
    noteParts.add('[Thanh toán: $paymentLabel]');
    if (_note.text.trim().isNotEmpty) {
      noteParts.add(_note.text.trim());
    }

    final created = await ap.create(
      at: _slot!,
      lines: lines,
      note: noteParts.isEmpty ? null : noteParts.join(' '),
      staffId: _selectedStaffId,
    );
    if (!mounted) return;

    if (created == null) {
      setState(() => _error = ap.error ?? 'Đặt lịch thất bại');
      return;
    }

    // Lên lịch thông báo nhắc nhở nếu người dùng chọn
    if (_reminderBefore != null) {
      final reminderTime = _slot!.subtract(_reminderBefore!);
      final staffName = _selectedStaffId != null
          ? catalog.staffById(_selectedStaffId!)?.fullName ?? 'Kỹ thuật viên'
          : 'Health Beauty Spa';
      await NotificationService().scheduleAppointmentReminder(
        id: created.id,
        title: 'Nhắc nhở lịch hẹn ${created.code}',
        body:
            'Lịch hẹn spa của bạn sẽ bắt đầu lúc ${timeStr(_slot!)} (${dateStr(_slot!)}). Kỹ thuật viên: $staffName.',
        reminderTime: reminderTime,
      );
    }

    if (!mounted) return;
    mainTab.value = 2; // chuyển sang tab Lịch hẹn
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Đặt lịch thành công ${created.code}.${_reminderBefore != null ? ' Đã cài nhắc trước ${_reminderText(_reminderBefore)}.' : ''}',
        ),
      ),
    );
  }

  // ---------- giao diện ----------

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final submitting = context.watch<AppointmentProvider>().submitting;
    const titles = [
      'Chọn dịch vụ',
      'Nhân viên & Thời gian',
      'Xác nhận đặt lịch',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch hẹn')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bước ${_step + 1}/3 · ${titles[_step]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    minHeight: 6,
                    color: AppColors.rose,
                    backgroundColor: AppColors.roseContainer,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (_step == 0) ..._stepServices(catalog),
                if (_step == 1) ..._stepTimeAndStaff(catalog),
                if (_step == 2) ..._stepConfirmAndVoucher(catalog),
              ],
            ),
          ),
          _bottomBar(catalog, submitting),
        ],
      ),
    );
  }

  Widget _bottomBar(CatalogProvider catalog, bool submitting) {
    final isLast = _step == 2;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: submitting ? null : () => setState(() => _step--),
                  child: const Text('Quay lại'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: (!_canNext(catalog) || submitting)
                    ? null
                    : () => isLast ? _submit() : _nextStep(),
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(isLast ? 'Xác nhận đặt lịch' : 'Tiếp tục'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BƯỚC 1: Chọn dịch vụ & Combo =====
  List<Widget> _stepServices(CatalogProvider catalog) {
    if (catalog.loading && !catalog.loaded) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (catalog.services.isEmpty && catalog.combos.isEmpty) {
      return [
        SizedBox(
          height: 300,
          child: EmptyState(
            icon: Icons.spa_outlined,
            title: 'Chưa có dịch vụ để đặt',
            subtitle:
                catalog.error ??
                'Hãy quay lại sau hoặc kéo để tải lại ở tab Dịch vụ',
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    if (catalog.services.isNotEmpty) {
      widgets.add(const SectionTitle('Dịch vụ lẻ'));
      widgets.add(const SizedBox(height: 8));
      for (final s in catalog.services) {
        final selected = _serviceIds.contains(s.id);
        widgets.add(
          _pickTile(
            title: s.name,
            subtitle: '${durationStr(s.durationMinutes)} · ${vnd(s.price)}',
            selected: selected,
            onTap: () => setState(() {
              selected ? _serviceIds.remove(s.id) : _serviceIds.add(s.id);
              _slot = null;
              _availableSlots = [];
              _availabilityRequest++;
              _daysRequest++;
              _availableDays = [];
              _daysLoading = false;
            }),
          ),
        );
      }
    }
    if (catalog.combos.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(const SectionTitle('Combo ưu đãi'));
      widgets.add(const SizedBox(height: 8));
      for (final c in catalog.combos) {
        final selected = _comboIds.contains(c.id);
        widgets.add(
          _pickTile(
            title: c.name,
            subtitle: '${c.totalServices} dịch vụ · ${vnd(c.price)}',
            selected: selected,
            onTap: () => setState(() {
              selected ? _comboIds.remove(c.id) : _comboIds.add(c.id);
              _slot = null;
              _availableSlots = [];
              _availabilityRequest++;
              _daysRequest++;
              _availableDays = [];
              _daysLoading = false;
            }),
          ),
        );
      }
    }
    widgets.add(const SizedBox(height: 8));
    widgets.add(
      Text(
        'Tạm tính: ${vnd(_total(catalog))}',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.rose,
        ),
      ),
    );
    return widgets;
  }

  Widget _pickTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        color: selected
            ? AppColors.roseContainer.withValues(alpha: 0.5)
            : Colors.white,
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.rose : cs.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BƯỚC 2: Chọn nhân viên & Thời gian =====
  List<Widget> _stepTimeAndStaff(CatalogProvider catalog) {
    final ap = context.watch<AppointmentProvider>();
    final cs = Theme.of(context).colorScheme;
    final minutes = _minutes(catalog);
    final starts = _bookableStarts(catalog, ap);
    final openDates = starts
        .map((start) => DateTime(start.year, start.month, start.day))
        .toSet();
    final daysReady = !_daysLoading && _daysError == null;

    final widgets = <Widget>[
      // --- Phần chọn nhân viên thực hiện ---
      Row(
        children: [
          const Expanded(child: SectionTitle('Nhân viên thực hiện')),
          IconButton(
            tooltip: 'Cập nhật danh sách nhân viên',
            onPressed: catalog.staffLoading ? null : () => catalog.loadStaff(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (catalog.staffLoading) const LinearProgressIndicator(),
      if (catalog.staffError != null)
        ErrorState(
          message: catalog.staffError!,
          onRetry: () => catalog.loadStaff(),
        ),
      if (!catalog.staffLoading && catalog.staffError == null && catalog.staffList.isEmpty)
        const Text('Chưa có nhân viên trong danh sách. Vui lòng liên hệ Spa.'),
      const SizedBox(height: 4),
      Text(
        'Bạn có thể chọn kỹ thuật viên yêu thích hoặc để Spa tự sắp xếp.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      const SizedBox(height: 10),
      _staffSelector(catalog),
      const SizedBox(height: 20),

      // --- Phần chọn ngày & giờ ---
      const SectionTitle('Chọn ngày & giờ hẹn'),
      const SizedBox(height: 8),
      if (_daysLoading) const LinearProgressIndicator(),
      if (_daysError != null)
        ErrorState(message: _daysError!, onRetry: _reloadDays),
      if (daysReady) ...[
        Text(
          'Ngày có chấm là ngày còn giờ phù hợp với dịch vụ và lịch của bạn.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: starts.isEmpty
              ? null
              : () => _selectAvailableDay(starts.first),
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Lịch trống gần nhất'),
        ),
        if (starts.isEmpty)
          const Text(
            'Chưa có lịch phù hợp từ hôm nay đến 60 ngày tới. Bạn có thể đổi nhân viên hoặc dịch vụ.',
          ),
        TextButton.icon(
          onPressed: _reloadDays,
          icon: const Icon(Icons.refresh),
          label: const Text('Cập nhật lịch trống'),
        ),
      ],
      AppCard(
        padding: const EdgeInsets.all(8),
        child: TableCalendar(
          firstDay: _today,
          lastDay: DateTime(_today.year, _today.month, _today.day + 60),
          focusedDay: _focused,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (d) => _day != null && sameDay(d, _day!),
          enabledDayPredicate: (date) =>
              daysReady &&
              openDates.contains(DateTime(date.year, date.month, date.day)),
          eventLoader: (date) =>
              daysReady &&
                  openDates.contains(DateTime(date.year, date.month, date.day))
              ? [true]
              : [],
          onDaySelected: (selected, focused) {
            _selectAvailableDay(selected);
          },
          onPageChanged: (focused) => _focused = focused,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                'Tháng ${date.month}, ${date.year}',
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            dowTextFormatter: (date, locale) => const [
              'T2',
              'T3',
              'T4',
              'T5',
              'T6',
              'CN',
              'CN',
            ][date.weekday - 1],
          ),
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.roseContainer,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: AppColors.onRoseContainer,
              fontWeight: FontWeight.w700,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.rose,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (_day == null) {
      widgets.add(
        Text(
          _daysLoading
              ? 'Đang tìm ngày còn lịch trống...'
              : 'Chọn ngày có chấm hoặc bấm “Lịch trống gần nhất” để xem giờ.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
      return widgets;
    }

    if (_slotsLoading) {
      widgets.add(const Center(child: CircularProgressIndicator()));
      return widgets;
    }
    if (_slotsError != null) {
      widgets.add(ErrorState(message: _slotsError!, onRetry: _reloadSlots));
      return widgets;
    }
    final now = DateTime.now();
    final slots = _availableSlots.map((slot) => slot.start).toSet().toList()
      ..sort();
    final usable = slots
        .where(
          (time) =>
              time.isAfter(now) &&
              !ap.hasConflictAt(time, durationMinutes: minutes),
        )
        .length;

    final selectedStaff = _selectedStaffId != null
        ? catalog.staffById(_selectedStaffId!)
        : null;

    widgets.add(SectionTitle('${weekdayStr(_day!)}, ${dateStr(_day!)}'));
    widgets.add(const SizedBox(height: 4));
    widgets.add(
      Text(
        'Thời lượng dự kiến: ${durationStr(minutes)} · ${selectedStaff != null ? 'KTV: ${selectedStaff.fullName}' : 'Spa tự sắp xếp KTV'}',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
    );
    widgets.add(const SizedBox(height: 12));

    if (slots.isEmpty || usable == 0) {
      widgets.add(
        const EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Không còn khung giờ trống trong ngày này',
          subtitle: 'Lịch có thể vừa thay đổi. Bấm “Cập nhật lịch trống” để tìm ngày khác.',
        ),
      );
    } else {
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in slots)
              ChoiceChip(
                label: Text(timeStr(t)),
                selected: _slot == t,
                onSelected:
                    (t.isAfter(now) &&
                        !ap.hasConflictAt(t, durationMinutes: minutes))
                    ? (_) => setState(() => _slot = t)
                    : null,
              ),
          ],
        ),
      );
    }
    return widgets;
  }

  Widget _staffSelector(CatalogProvider catalog) {
    final staffList = catalog.staffList;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Lựa chọn "Bất kỳ nhân viên nào"
          _staffCard(
            title: 'Bất kỳ nhân viên',
            subtitle: 'Spa tự sắp xếp',
            icon: Icons.auto_awesome,
            selected: _selectedStaffId == null,
            onTap: () {
              setState(() {
                _selectedStaffId = null;
                _slot = null;
              });
              _reloadDays();
            },
          ),
          for (final s in staffList)
            _staffCard(
              title: s.fullName,
              subtitle: s.displayTitle,
              initial: s.fullName.isNotEmpty
                  ? s.fullName.trim()[0].toUpperCase()
                  : '?',
              selected: _selectedStaffId == s.id,
              onTap: () {
                setState(() {
                  _selectedStaffId = s.id;
                  _slot = null;
                });
                _reloadDays();
              },
            ),
        ],
      ),
    );
  }

  Widget _staffCard({
    required String title,
    required String subtitle,
    IconData? icon,
    String? initial,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
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
              color: selected
                  ? AppColors.rose
                  : AppColors.outline.withValues(alpha: 0.6),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: selected
                    ? AppColors.rose
                    : cs.primaryContainer,
                child: icon != null
                    ? Icon(
                        icon,
                        size: 18,
                        color: selected ? Colors.white : cs.onPrimaryContainer,
                      )
                    : Text(
                        initial ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected
                              ? Colors.white
                              : cs.onPrimaryContainer,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== BƯỚC 3: Xác nhận, Voucher & Cài đặt thông báo =====
  List<Widget> _stepConfirmAndVoucher(CatalogProvider catalog) {
    final cs = Theme.of(context).colorScheme;
    final services = _selectedServices(catalog);
    final combos = _selectedCombos(catalog);
    final rawTotal = _total(catalog);
    final discount = _voucherDiscount(rawTotal);
    final finalTotal = _finalTotal(rawTotal);
    final minutes = _minutes(catalog);

    final selectedStaff = _selectedStaffId != null
        ? catalog.staffById(_selectedStaffId!)
        : null;

    return [
      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),

      // Card 1: Thông tin lịch hẹn
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: AppColors.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${weekdayStr(_slot!)}, ${dateStr(_slot!)} · ${timeStr(_slot!)} · ${durationStr(minutes)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: AppColors.sage,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedStaff != null
                        ? 'Nhân viên: ${selectedStaff.fullName} (${selectedStaff.displayTitle})'
                        : 'Nhân viên: Tự động sắp xếp (Bất kỳ KTV)',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final s in services)
              _line(
                '${s.name} (${durationStr(s.durationMinutes)})',
                vnd(s.price),
                cs,
              ),
            for (final c in combos)
              _line('${c.name} (combo)', vnd(c.price), cs),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Card 2: Chọn Voucher
      _voucherSection(catalog, rawTotal),
      const SizedBox(height: 16),

      // Card 3: Chọn hình thức thanh toán
      _paymentMethodSection(),
      const SizedBox(height: 16),

      // Card 4: Cài đặt thời gian nhắc trước giờ hẹn
      const SectionTitle('Nhắc nhở trước giờ hẹn'),
      const SizedBox(height: 4),
      Text(
        'Hệ thống sẽ gửi thông báo đến điện thoại trước khi lịch hẹn bắt đầu.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      const SizedBox(height: 8),
      _reminderSelector(),
      const SizedBox(height: 16),

      // Card 5: Ghi chú cho spa
      TextField(
        controller: _note,
        maxLines: 2,
        maxLength: 500,
        decoration: InputDecoration(
          labelText: 'Ghi chú cho spa (không bắt buộc)',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      const SizedBox(height: 8),

      // Card 6: Bảng thanh toán tổng kết
      AppCard(
        color: AppColors.cream,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tạm tính dịch vụ')),
                Text(
                  vnd(rawTotal),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (_selectedVoucherCode != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          size: 16,
                          color: AppColors.rose,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Voucher ($_selectedVoucherCode)',
                            style: const TextStyle(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${vnd(discount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.rose,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tổng tiền dự kiến',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Text(
                  vnd(finalTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.rose,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _paymentMethod == 'ChuyenKhoan'
                      ? Icons.qr_code_2
                      : Icons.payments_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _paymentMethod == 'ChuyenKhoan'
                        ? 'Thanh toán chuyển khoản ngân hàng (quét VietQR).'
                        : 'Thanh toán tiền mặt tại quầy khi đến làm dịch vụ tại Spa.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // --- Widget chọn Voucher ---
  Widget _voucherSection(CatalogProvider catalog, double rawTotal) {
    final cs = Theme.of(context).colorScheme;
    final discount = _voucherDiscount(rawTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Voucher & Ưu đãi'),
        const SizedBox(height: 4),
        Text(
          'Chọn voucher khả dụng hoặc nhập mã khuyến mãi để nhận giảm giá.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (_selectedVoucherCode == null)
          AppCard(
            onTap: () => _openVoucherPicker(context, catalog, rawTotal),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.roseContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.rose,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn hoặc nhập mã voucher',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        catalog.myVouchers.isNotEmpty
                            ? 'Bạn có ${catalog.myVouchers.where((v) => v.isAvailableAt(DateTime.now())).length} voucher có thể sử dụng'
                            : 'Nhấn để chọn ưu đãi giảm giá',
                        style: TextStyle(
                          color: catalog.myVouchers.isNotEmpty
                              ? AppColors.rose
                              : cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: catalog.myVouchers.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.outline,
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.roseContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rose, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.confirmation_number,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _selectedVoucherCode!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.rose,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ĐÃ ÁP DỤNG',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedVoucherTitle != null &&
                          _selectedVoucherTitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _selectedVoucherTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Giảm dự kiến: -${vnd(discount)}',
                        style: const TextStyle(
                          color: AppColors.rose,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Hủy voucher',
                  onPressed: () => setState(() {
                    _selectedVoucherCode = null;
                    _selectedVoucherTitle = null;
                    _selectedVoucherDiscount = null;
                  }),
                ),
                TextButton(
                  onPressed: () =>
                      _openVoucherPicker(context, catalog, rawTotal),
                  child: const Text('Đổi mã'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _openVoucherPicker(
    BuildContext context,
    CatalogProvider catalog,
    double rawTotal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return _VoucherPickerSheet(
          currentCode: _selectedVoucherCode,
          onVoucherSelected: (code, title, discount) {
            setState(() {
              _selectedVoucherCode = code;
              _selectedVoucherTitle = title;
              _selectedVoucherDiscount = discount;
            });
          },
          onClear: () {
            setState(() {
              _selectedVoucherCode = null;
              _selectedVoucherTitle = null;
              _selectedVoucherDiscount = null;
            });
          },
        );
      },
    );
  }

  // --- Widget chọn hình thức thanh toán ---
  Widget _paymentMethodSection() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Hình thức thanh toán'),
        const SizedBox(height: 4),
        Text(
          'Chọn cách thức thanh toán khi đến làm dịch vụ tại Spa.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 10),

        // Lựa chọn 1: Tiền mặt
        _paymentOptionCard(
          value: 'TienMat',
          title: 'Tiền mặt tại quầy',
          subtitle:
              'Thanh toán trực tiếp bằng tiền mặt khi làm dịch vụ tại Spa',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 8),

        // Lựa chọn 2: Chuyển khoản ngân hàng
        _paymentOptionCard(
          value: 'ChuyenKhoan',
          title: 'Chuyển khoản ngân hàng (QR Code)',
          subtitle: 'Quét mã VietQR hoặc chuyển khoản qua tài khoản ngân hàng của Spa',
          icon: Icons.qr_code_2,
        ),

        // Thông tin chuyển khoản hiển thị khi chọn Chuyển khoản
        if (_paymentMethod == 'ChuyenKhoan') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.roseContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.account_balance,
                      size: 18,
                      color: AppColors.rose,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Thông tin chuyển khoản Spa',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.rose,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _bankInfoRow('Ngân hàng:', 'MB Bank (Quân Đội)'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SizedBox(
                      width: 100,
                      child: Text(
                        'Số tài khoản:',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '0386 868 686',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                          const ClipboardData(text: '0386868686'),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép số tài khoản'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 13, color: AppColors.rose),
                            SizedBox(width: 4),
                            Text(
                              'Sao chép',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.rose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _bankInfoRow('Chủ tài khoản:', 'SPA HEALTH & BEAUTY'),
                const SizedBox(height: 6),
                _bankInfoRow('Nội dung CK:', 'Họ tên + SĐT đặt lịch'),
                const SizedBox(height: 8),
                Text(
                  '* Quý khách có thể chuyển khoản trước hoặc quét mã VietQR tại quầy lễ tân khi hoàn thành dịch vụ.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _bankInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _paymentOptionCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _paymentMethod == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.roseContainer.withValues(alpha: 0.35)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.rose
                : AppColors.outline.withValues(alpha: 0.6),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.rose : cs.outline,
              size: 20,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.rose.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.rose : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget chọn nhắc nhở ---
  Widget _reminderSelector() {
    const options = <Duration?>[
      null,
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(hours: 1),
      Duration(hours: 2),
      Duration(days: 1),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in options)
          ChoiceChip(
            label: Text(_reminderText(opt)),
            selected: _reminderBefore == opt,
            onSelected: (_) => setState(() => _reminderBefore = opt),
          ),
      ],
    );
  }

  Widget _line(String name, String price, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text(price, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Bottom Sheet chọn hoặc nhập voucher cho bước xác nhận đặt lịch
class _VoucherPickerSheet extends StatefulWidget {
  final String? currentCode;
  final Function(String code, String? title, double discount) onVoucherSelected;
  final VoidCallback onClear;

  const _VoucherPickerSheet({
    required this.currentCode,
    required this.onVoucherSelected,
    required this.onClear,
  });

  @override
  State<_VoucherPickerSheet> createState() => _VoucherPickerSheetState();
}

class _VoucherPickerSheetState extends State<_VoucherPickerSheet> {
  final _codeController = TextEditingController();
  bool _validating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final catalog = context.read<CatalogProvider>();
      if (auth.isLoggedIn &&
          catalog.myVouchers.isEmpty &&
          !catalog.vouchersLoading) {
        catalog.loadMyVouchers();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndApply() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final catalog = context.read<CatalogProvider>();
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      final res = await catalog.validateVoucher(code);
      if (!mounted) return;
      if (res.valid) {
        widget.onVoucherSelected(res.code ?? code, res.title, res.value ?? 0);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã áp dụng mã voucher ${res.code ?? code}'),
            backgroundColor: AppColors.rose,
          ),
        );
      } else {
        setState(() {
          _error = res.message ?? 'Mã voucher không hợp lệ hoặc đã hết hạn';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể kiểm tra mã voucher. Vui lòng thử lại sau.';
        });
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final catalog = context.watch<CatalogProvider>();
    final cs = Theme.of(context).colorScheme;
    final availableVouchers = catalog.myVouchers
        .where((v) => v.isAvailableAt(DateTime.now()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo trên modal
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn Voucher & Ưu đãi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Nhập mã voucher
              const Text(
                'Nhập mã khuyến mãi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _checkAndApply(),
                      decoration: InputDecoration(
                        hintText: 'VD: RANGRO100',
                        prefixIcon: const Icon(
                          Icons.confirmation_number_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppColors.cream,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _validating ? null : _checkAndApply,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _validating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Áp dụng'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (widget.currentCode != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: Text('Bỏ chọn mã hiện tại (${widget.currentCode})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const Divider(height: 28),

              // Danh sách voucher của khách hàng
              const Text(
                'Voucher của bạn',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),

              if (!auth.isLoggedIn)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        color: AppColors.rose,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Đăng nhập để xem và áp dụng các voucher cá nhân trong tài khoản của bạn.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                )
              else if (catalog.vouchersLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (catalog.voucherError != null)
                ErrorState(
                  message: catalog.voucherError!,
                  onRetry: () => catalog.loadMyVouchers(),
                )
              else if (availableVouchers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 36,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bạn chưa có voucher nào trong ví',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final v in availableVouchers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.currentCode == v.code
                            ? AppColors.roseContainer.withValues(alpha: 0.4)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.currentCode == v.code
                              ? AppColors.rose
                              : AppColors.outline.withValues(alpha: 0.6),
                          width: widget.currentCode == v.code ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.roseContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.confirmation_number,
                              color: AppColors.rose,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                if (v.promotionName != null &&
                                    v.promotionName!.isNotEmpty)
                                  Text(
                                    v.promotionName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                Text(
                                  'Giảm tối đa ${vnd(v.discountValue)}${v.expiresAt != null ? ' · HSD: ${dateStr(v.expiresAt!)}' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.rose,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.currentCode == v.code)
                            const Chip(
                              label: Text('Đang dùng'),
                              backgroundColor: AppColors.roseContainer,
                              labelStyle: TextStyle(
                                color: AppColors.rose,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            )
                          else
                            FilledButton.tonal(
                              onPressed: () {
                                widget.onVoucherSelected(
                                  v.code,
                                  v.promotionName,
                                  v.discountValue,
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã chọn voucher ${v.code}'),
                                    backgroundColor: AppColors.rose,
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Dùng'),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
