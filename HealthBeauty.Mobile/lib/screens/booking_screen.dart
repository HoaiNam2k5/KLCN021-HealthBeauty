import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../core/notification_service.dart';
import '../models/catalog.dart';
import '../providers/appointment_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

/// Đặt lịch 3 bước:
/// Bước 1: Chọn dịch vụ & Combo
/// Bước 2: Chọn nhân viên thực hiện & Khung giờ
/// Bước 3: Voucher ưu đãi, Cài đặt nhắc nhở & Xác nhận thanh toán
class BookingScreen extends StatefulWidget {
  final Service? initialService;
  final Combo? initialCombo;
  const BookingScreen({super.key, this.initialService, this.initialCombo});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const _openHour = 9;
  static const _closeHour = 20;
  static const _slotStepMinutes = 30;

  late final DateTime _today;
  int _step = 0;
  final Set<int> _serviceIds = {};
  final Set<int> _comboIds = {};
  int? _selectedStaffId; // null = bất kỳ nhân viên nào
  late DateTime _focused;
  DateTime? _day;
  DateTime? _slot;

  // Voucher
  CustomerVoucher? _selectedVoucher;
  VoucherCheck? _manualVoucherCheck;
  String? _manualVoucherCode;

  // Nhắc nhở trước giờ hẹn (mặc định 30 phút)
  Duration? _reminderBefore = const Duration(minutes: 30);

  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _focused = _today;
    if (widget.initialService != null) _serviceIds.add(widget.initialService!.id);
    if (widget.initialCombo != null) _comboIds.add(widget.initialCombo!.id);
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

  double _discount(double rawTotal) {
    if (_selectedVoucher != null) {
      return _selectedVoucher!.discountValue > rawTotal
          ? rawTotal
          : _selectedVoucher!.discountValue;
    }
    if (_manualVoucherCheck != null && _manualVoucherCheck!.value != null) {
      final v = _manualVoucherCheck!.value!;
      return v > rawTotal ? rawTotal : v;
    }
    return 0.0;
  }

  double _finalTotal(CatalogProvider c) {
    final raw = _total(c);
    final disc = _discount(raw);
    return (raw - disc).clamp(0.0, double.infinity);
  }

  int _minutes(CatalogProvider c) {
    var m = _selectedServices(c).fold(0, (s, e) => s + e.durationMinutes);
    for (final combo in _selectedCombos(c)) {
      for (final it in combo.items) {
        m += (c.serviceById(it.serviceId)?.durationMinutes ?? 0) * it.quantity;
      }
    }
    return m;
  }

  /// Chuyển lựa chọn thành danh sách `items` gửi lên POST /appointments.
  List<Map<String, dynamic>> _buildLines(CatalogProvider c) {
    final lines = <Map<String, dynamic>>[];
    final rawTotal = _total(c);
    final discountAmount = _discount(rawTotal);
    final ratio = rawTotal > 0 ? (rawTotal - discountAmount) / rawTotal : 1.0;

    for (final s in _selectedServices(c)) {
      lines.add({
        'serviceId': s.id,
        'comboId': null,
        'expectedPrice': (s.price * ratio).roundToDouble(),
      });
    }
    for (final combo in _selectedCombos(c)) {
      final ids = <int>[];
      for (final it in combo.items) {
        for (var i = 0; i < it.quantity; i++) {
          ids.add(it.serviceId);
        }
      }
      if (ids.isEmpty) continue;
      final share = (combo.price * ratio) / ids.length;
      for (final id in ids) {
        lines.add({
          'serviceId': id,
          'comboId': combo.id,
          'expectedPrice': share.roundToDouble(),
        });
      }
    }
    return lines;
  }

  List<DateTime> _slotsFor(DateTime day, int minutes) {
    final need = minutes < _slotStepMinutes ? _slotStepMinutes : minutes;
    final open = DateTime(day.year, day.month, day.day, _openHour);
    final close = DateTime(day.year, day.month, day.day, _closeHour);
    final slots = <DateTime>[];
    var t = open;
    while (!t.add(Duration(minutes: need)).isAfter(close)) {
      slots.add(t);
      t = t.add(const Duration(minutes: _slotStepMinutes));
    }
    return slots;
  }

  bool _canNext(CatalogProvider c) {
    switch (_step) {
      case 0:
        return _serviceIds.isNotEmpty || _comboIds.isNotEmpty;
      case 1:
        return _slot != null;
      default:
        return true;
    }
  }

  String _reminderText(Duration? d) {
    if (d == null) return 'Không nhắc';
    if (d.inDays >= 1) return '${d.inDays} ngày trước';
    if (d.inHours >= 1) return '${d.inHours} giờ trước';
    return '${d.inMinutes} phút trước';
  }

  Future<void> _submit() async {
    final catalog = context.read<CatalogProvider>();
    final ap = context.read<AppointmentProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _error = null);

    // Xây dựng ghi chú bao gồm thông tin voucher và nhắc nhở
    final noteParts = <String>[];
    if (_selectedVoucher != null) {
      noteParts.add(
          '[Voucher: ${_selectedVoucher!.code} - Giảm ${vnd(_discount(_total(catalog)))}]');
    } else if (_manualVoucherCheck != null && _manualVoucherCode != null) {
      noteParts.add(
          '[Voucher: $_manualVoucherCode - Giảm ${vnd(_discount(_total(catalog)))}]');
    }
    if (_reminderBefore != null) {
      noteParts.add('[Nhắc hẹn: ${_reminderText(_reminderBefore)}]');
    }
    if (_note.text.trim().isNotEmpty) {
      noteParts.add(_note.text.trim());
    }

    final created = await ap.create(
      at: _slot!,
      lines: _buildLines(catalog),
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
      'Voucher & Thanh toán'
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                        borderRadius: BorderRadius.circular(16)),
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
                    : () => isLast ? _submit() : setState(() => _step++),
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
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
            child: Center(child: CircularProgressIndicator()))
      ];
    }
    if (catalog.services.isEmpty && catalog.combos.isEmpty) {
      return [
        SizedBox(
          height: 300,
          child: EmptyState(
            icon: Icons.spa_outlined,
            title: 'Chưa có dịch vụ để đặt',
            subtitle: catalog.error ??
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
        widgets.add(_pickTile(
          title: s.name,
          subtitle: '${durationStr(s.durationMinutes)} · ${vnd(s.price)}',
          selected: selected,
          onTap: () => setState(() {
            selected ? _serviceIds.remove(s.id) : _serviceIds.add(s.id);
            _slot = null;
          }),
        ));
      }
    }
    if (catalog.combos.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(const SectionTitle('Combo ưu đãi'));
      widgets.add(const SizedBox(height: 8));
      for (final c in catalog.combos) {
        final selected = _comboIds.contains(c.id);
        widgets.add(_pickTile(
          title: c.name,
          subtitle: '${c.totalServices} dịch vụ · ${vnd(c.price)}',
          selected: selected,
          onTap: () => setState(() {
            selected ? _comboIds.remove(c.id) : _comboIds.add(c.id);
            _slot = null;
          }),
        ));
      }
    }
    widgets.add(const SizedBox(height: 8));
    widgets.add(Text(
      'Tạm tính: ${vnd(_total(catalog))}',
      textAlign: TextAlign.right,
      style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.rose),
    ));
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
            Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.rose : cs.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
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

    final widgets = <Widget>[
      // --- Phần chọn nhân viên thực hiện ---
      const SectionTitle('Nhân viên thực hiện'),
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
      AppCard(
        padding: const EdgeInsets.all(8),
        child: TableCalendar(
          firstDay: _today,
          lastDay: _today.add(const Duration(days: 60)),
          focusedDay: _focused,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (d) => _day != null && sameDay(d, _day!),
          onDaySelected: (selected, focused) => setState(() {
            _day = DateTime(selected.year, selected.month, selected.day);
            _focused = focused;
            _slot = null;
          }),
          onPageChanged: (focused) => _focused = focused,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                'Tháng ${date.month}, ${date.year}',
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            dowTextFormatter: (date, locale) =>
                const ['T2', 'T3', 'T4', 'T5', 'T6', 'CN', 'CN'][date.weekday - 1],
          ),
          calendarStyle: CalendarStyle(
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
      widgets.add(Text('Vui lòng chọn một ngày để xem các khung giờ khả dụng.',
          style: TextStyle(color: cs.onSurfaceVariant)));
      return widgets;
    }

    final now = DateTime.now();
    final slots = _slotsFor(_day!, minutes);
    final usable = slots
        .where((t) =>
            t.isAfter(now.add(const Duration(minutes: 30))) &&
            !ap.hasConflictAt(t))
        .length;

    final selectedStaff = _selectedStaffId != null
        ? catalog.staffById(_selectedStaffId!)
        : null;

    widgets.add(SectionTitle('${weekdayStr(_day!)}, ${dateStr(_day!)}'));
    widgets.add(const SizedBox(height: 4));
    widgets.add(Text(
      'Thời lượng dự kiến: ${durationStr(minutes)} · ${selectedStaff != null ? 'KTV: ${selectedStaff.fullName}' : 'Spa tự sắp xếp KTV'}',
      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
    ));
    widgets.add(const SizedBox(height: 12));

    if (slots.isEmpty || usable == 0) {
      widgets.add(const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Không còn khung giờ trống trong ngày này',
        subtitle: 'Vui lòng chọn một ngày khác',
      ));
    } else {
      widgets.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in slots)
            ChoiceChip(
              label: Text(timeStr(t)),
              selected: _slot == t,
              onSelected: (t.isAfter(now.add(const Duration(minutes: 30))) &&
                      !ap.hasConflictAt(t))
                  ? (_) => setState(() => _slot = t)
                  : null,
            ),
        ],
      ));
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
            onTap: () => setState(() {
              _selectedStaffId = null;
              _slot = null;
            }),
          ),
          for (final s in staffList)
            _staffCard(
              title: s.fullName,
              subtitle: s.displayTitle,
              initial: s.fullName.isNotEmpty
                  ? s.fullName.trim()[0].toUpperCase()
                  : '?',
              selected: _selectedStaffId == s.id,
              onTap: () => setState(() {
                _selectedStaffId = s.id;
                _slot = null;
              }),
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
                backgroundColor:
                    selected ? AppColors.rose : cs.primaryContainer,
                child: icon != null
                    ? Icon(icon,
                        size: 18,
                        color: selected ? Colors.white : cs.onPrimaryContainer)
                    : Text(
                        initial ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected ? Colors.white : cs.onPrimaryContainer,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
    final discountAmount = _discount(rawTotal);
    final finalAmount = _finalTotal(catalog);

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
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger))),
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
                    '${weekdayStr(_slot!)}, ${dateStr(_slot!)} · ${timeStr(_slot!)}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: AppColors.sage),
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
            for (final s in services) _line(s.name, vnd(s.price), cs),
            for (final c in combos) _line('${c.name} (combo)', vnd(c.price), cs),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Card 2: Chọn Voucher ưu đãi
      const SectionTitle('Mã giảm giá / Voucher'),
      const SizedBox(height: 8),
      _voucherSection(catalog, cs),
      const SizedBox(height: 16),

      // Card 3: Cài đặt thời gian nhắc trước giờ hẹn
      const SectionTitle('Nhắc nhở trước giờ hẹn'),
      const SizedBox(height: 4),
      Text(
        'Hệ thống sẽ gửi thông báo đến điện thoại trước khi lịch hẹn bắt đầu.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      const SizedBox(height: 8),
      _reminderSelector(),
      const SizedBox(height: 16),

      // Card 4: Ghi chú cho spa
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

      // Card 5: Bảng thanh toán tổng kết
      AppCard(
        color: AppColors.cream,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tạm tính dịch vụ')),
                Text(vnd(rawTotal),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (discountAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer,
                            size: 16, color: AppColors.ok),
                        const SizedBox(width: 4),
                        Text(
                          'Giảm giá voucher (${_selectedVoucher?.code ?? _manualVoucherCode ?? ''})',
                          style: const TextStyle(
                              color: AppColors.ok, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text('-${vnd(discountAmount)}',
                      style: const TextStyle(
                          color: AppColors.ok, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Tổng thanh toán tạm tính',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(
                  vnd(finalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.rose,
                      fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Thanh toán tại quầy khi đến làm dịch vụ tại Spa.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    ];
  }

  // --- Widget chọn Voucher ---
  Widget _voucherSection(CatalogProvider catalog, ColorScheme cs) {
    final hasVoucher =
        _selectedVoucher != null || _manualVoucherCheck?.valid == true;
    final code = _selectedVoucher?.code ?? _manualVoucherCode;
    final discountVal = _discount(_total(catalog));

    if (hasVoucher) {
      return AppCard(
        color: AppColors.sageContainer.withValues(alpha: 0.5),
        child: Row(
          children: [
            const Icon(Icons.confirmation_number, color: AppColors.sage),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voucher: $code',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    'Đã áp dụng giảm ${vnd(discountVal)}',
                    style: const TextStyle(
                        color: AppColors.ok,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.inkMuted),
              tooltip: 'Gỡ voucher',
              onPressed: () => setState(() {
                _selectedVoucher = null;
                _manualVoucherCheck = null;
                _manualVoucherCode = null;
              }),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: () => _openVoucherBottomSheet(context, catalog),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined, color: AppColors.rose),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Chọn voucher hoặc nhập mã ưu đãi',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        ],
      ),
    );
  }

  // --- Bottom Sheet chọn Voucher ---
  void _openVoucherBottomSheet(BuildContext context, CatalogProvider catalog) {
    final codeCtrl = TextEditingController();
    bool validating = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Voucher ưu đãi',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Nhập mã thủ công
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Nhập mã voucher (VD: SPA100K)',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: validating
                              ? null
                              : () async {
                                  final text = codeCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  setSheetState(() {
                                    validating = true;
                                    localError = null;
                                  });
                                  final check =
                                      await catalog.validateVoucher(text);
                                  setSheetState(() => validating = false);
                                  if (check.valid) {
                                    setState(() {
                                      _manualVoucherCheck = check;
                                      _manualVoucherCode = text;
                                      _selectedVoucher = null;
                                    });
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } else {
                                    setSheetState(() => localError =
                                        check.message ?? 'Mã voucher không hợp lệ');
                                  }
                                },
                          child: validating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Áp dụng'),
                        ),
                      ],
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 6),
                      Text(localError!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),

                    // Danh sách voucher của tôi
                    const SectionTitle('Voucher khả dụng của bạn'),
                    const SizedBox(height: 8),
                    if (catalog.myVouchers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('Bạn chưa có voucher nào trong ví'),
                        ),
                      )
                    else
                      for (final v in catalog.myVouchers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.roseContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.confirmation_number,
                                      color: AppColors.rose, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v.code,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              letterSpacing: 0.5)),
                                      if (v.promotionName != null &&
                                          v.promotionName!.isNotEmpty)
                                        Text(v.promotionName!,
                                            style: const TextStyle(fontSize: 12)),
                                      Text(
                                        'Giảm ${vnd(v.discountValue)}${v.expiresAt != null ? ' · HSD ${dateStr(v.expiresAt!)}' : ''}',
                                        style: const TextStyle(
                                            color: AppColors.rose,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: () {
                                    setState(() {
                                      _selectedVoucher = v;
                                      _manualVoucherCheck = null;
                                      _manualVoucherCode = null;
                                    });
                                    Navigator.pop(ctx);
                                  },
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
        },
      ),
    );
  }

  // --- Widget chọn thời gian nhắc trước giờ hẹn ---
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
