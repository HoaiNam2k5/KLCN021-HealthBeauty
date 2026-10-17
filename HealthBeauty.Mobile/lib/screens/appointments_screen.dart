import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../widgets/common.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _tab = 0; // 0 = sắp tới, 1 = lịch sử

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppointmentProvider>();
    final list = _tab == 0 ? ap.upcoming : ap.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text('Lịch hẹn',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text('Sắp tới (${ap.upcoming.length})')),
              const ButtonSegment(value: 1, label: Text('Lịch sử')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body(ap, list)),
      ],
    );
  }

  Widget _body(AppointmentProvider ap, List<Appointment> list) {
    if (ap.loading && ap.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ap.error != null && ap.items.isEmpty) {
      return ErrorState(message: ap.error!, onRetry: ap.load);
    }
    return RefreshIndicator(
      onRefresh: ap.load,
      child: list.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: _tab == 0
                        ? 'Bạn chưa có lịch hẹn sắp tới'
                        : 'Chưa có lịch sử lịch hẹn',
                    subtitle: _tab == 0 ? 'Bấm "Đặt lịch" để tạo lịch hẹn mới' : null,
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _AppointmentCard(a: list[i]),
            ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment a;
  const _AppointmentCard({required this.a});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = a.appointmentAt;
    return AppCard(
      onTap: () => _showDetail(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(two(d.day),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer)),
                Text('Thg ${d.month}',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.code,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ),
                    StatusChip(label: a.statusLabel, color: statusColor(a.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(a.serviceSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${weekdayStr(d)} · ${timeStr(d)}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Lịch hẹn ${a.code}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  StatusChip(label: a.statusLabel, color: statusColor(a.status)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${weekdayStr(a.appointmentAt)}, ${dateStr(a.appointmentAt)} · ${timeStr(a.appointmentAt)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Divider(height: 24),
              for (final it in a.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(it.serviceName)),
                      Text(vnd(it.expectedPrice),
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                      child: Text('Tạm tính', style: TextStyle(fontWeight: FontWeight.w700))),
                  Text(vnd(a.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.rose)),
                ],
              ),
              if (a.note != null && a.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Ghi chú: ${a.note}', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
              if (a.canCancel) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy lịch hẹn',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _confirmCancel(context, sheetContext),
                  ),
                ),
              ] else if (a.isUpcoming) ...[
                const SizedBox(height: 12),
                Text(
                  'Lịch hẹn đang được xử lý. Để đổi/hủy vui lòng liên hệ spa.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, BuildContext sheetContext) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (d) => AlertDialog(
        title: const Text('Xác nhận hủy lịch'),
        content: Text('Bạn có chắc chắn muốn hủy lịch hẹn ${a.code}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final ap = context.read<AppointmentProvider>();
      Navigator.pop(sheetContext); // đóng bottom sheet
      final ok = await ap.cancel(a.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok ? 'Đã hủy lịch hẹn ${a.code}' : (ap.error ?? 'Hủy lịch thất bại')),
        ),
      );
    }
  }
}
