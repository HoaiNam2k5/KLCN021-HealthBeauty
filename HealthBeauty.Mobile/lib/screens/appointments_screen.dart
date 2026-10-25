import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/service_package_provider.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'invoice_detail_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _tab = 0; // 0 = sắp tới, 1 = lịch sử

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ap = context.watch<AppointmentProvider>();
    final cs = Theme.of(context).colorScheme;
    final list = _tab == 0 ? ap.upcoming : ap.history;

    if (!auth.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 72,
                color: AppColors.rose,
              ),
              const SizedBox(height: 16),
              const Text(
                'Xem lịch hẹn của bạn',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng đăng nhập để theo dõi và quản lý các lịch hẹn làm đẹp đã đặt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Lịch hẹn',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text('Sắp tới (${ap.upcoming.length})'),
              ),
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
                    subtitle: _tab == 0
                        ? 'Bấm "Đặt lịch" để tạo lịch hẹn mới'
                        : null,
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
                Text(
                  two(d.day),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Thg ${d.month}',
                  style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                ),
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
                      child: Text(
                        a.code,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (a.isDone && a.hasReviewed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: StatusChip(
                          label: '${a.reviewStars ?? 5} ⭐',
                          color: AppColors.warn,
                        ),
                      ),
                    StatusChip(
                      label: a.statusLabel,
                      color: statusColor(a.status),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  a.serviceSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${weekdayStr(d)} · ${timeStr(d)} · ${durationStr(a.durationMinutes)}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final catalog = context.read<CatalogProvider>();
    final staff = a.staffId != null ? catalog.staffById(a.staffId!) : null;
    final staffDisplay = a.staffId != null
        ? (staff != null
              ? '${staff.fullName} (${staff.displayTitle})'
              : 'KTV #${a.staffId}')
        : 'Spa tự sắp xếp KTV';
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
                    child: Text(
                      'Lịch hẹn ${a.code}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: a.statusLabel,
                    color: statusColor(a.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${weekdayStr(a.appointmentAt)}, ${dateStr(a.appointmentAt)} · ${timeStr(a.appointmentAt)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.sage),
                  const SizedBox(width: 6),
                  Text(
                    'Thời lượng: ${durationStr(a.durationMinutes)}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.rose,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'KTV: $staffDisplay',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              for (final it in a.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          it.durationMinutes > 0
                              ? '${it.serviceName} (${durationStr(it.durationMinutes)})'
                              : it.serviceName,
                        ),
                      ),
                      Text(
                        vnd(it.expectedPrice),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tạm tính',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    vnd(a.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.rose,
                    ),
                  ),
                ],
              ),
              ..._buildNoteDetails(a.note, cs),
              if (a.invoiceId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Xem hóa đơn / Thanh toán'),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => InvoiceDetailScreen(invoiceId: a.invoiceId!),
                      ));
                      if (context.mounted) context.read<AppointmentProvider>().load();
                    },
                  ),
                ),
              ],
              if (a.customerPackageId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Sử dụng lượt từ gói dịch vụ #${a.customerPackageId} · không thu thêm tiền dịch vụ.',
                    style: TextStyle(color: cs.primary),
                  ),
                ),
              if (a.canCancel) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text(
                      'Hủy lịch hẹn',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _confirmCancel(context, sheetContext),
                  ),
                ),
              ] else if (a.isUpcoming) ...[
                const SizedBox(height: 12),
                Text(
                  'Lịch hẹn đang được xử lý. Để đổi/hủy vui lòng liên hệ spa.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ] else if (a.isDone) ...[
                const SizedBox(height: 16),
                if (!a.hasReviewed)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.star_rounded),
                      label: const Text(
                        'Đánh giá dịch vụ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _openReviewDialog(context, sheetContext),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.roseContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.rose.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Đánh giá của bạn',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < (a.reviewStars ?? 5)
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${a.reviewStars ?? 5}/5',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.rose,
                              ),
                            ),
                          ],
                        ),
                        if (a.reviewedAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            dateStr(a.reviewedAt!),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          (a.reviewComment != null &&
                                  a.reviewComment!.trim().isNotEmpty)
                              ? '"${a.reviewComment!.trim()}"'
                              : '(Bạn không để lại nhận xét bằng chữ)',
                          style: TextStyle(
                            fontStyle:
                                (a.reviewComment != null &&
                                    a.reviewComment!.trim().isNotEmpty)
                                ? FontStyle.normal
                                : FontStyle.italic,
                            fontSize: 13,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                        ),
                        if (a.reviewReply != null &&
                            a.reviewReply!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.rose.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.reply_rounded,
                                      size: 14,
                                      color: AppColors.rose,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Phản hồi từ Spa:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.rose,
                                      ),
                                    ),
                                    if (a.reviewRepliedAt != null) ...[
                                      const Spacer(),
                                      Text(
                                        dateStr(a.reviewRepliedAt!),
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.reviewReply!.trim(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReviewDialog(
    BuildContext context,
    BuildContext sheetContext,
  ) async {
    int selectedStars = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;
    String? submitError;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final starLabels = [
            'Rất tệ',
            'Không hài lòng',
            'Bình thường',
            'Hài lòng',
            'Tuyệt vời',
          ];

          return AlertDialog(
            backgroundColor: AppColors.cream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Text(
                  'Đánh giá dịch vụ',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    a.serviceSummary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Chọn sao
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        iconSize: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        onPressed: isSubmitting
                            ? null
                            : () => setDialogState(
                                () => selectedStars = starValue,
                              ),
                        icon: Icon(
                          starValue <= selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  Text(
                    starLabels[selectedStars - 1],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.rose,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    maxLength: 1000,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'Hãy chia sẻ cảm nhận của bạn về trải nghiệm dịch vụ, tay nghề kỹ thuật viên...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.rose,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      submitError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogCtx, false),
                child: const Text('Bỏ qua'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() {
                          isSubmitting = true;
                          submitError = null;
                        });
                        final ap = context.read<AppointmentProvider>();
                        final ok = await ap.submitReview(
                          appointmentId: a.id,
                          stars: selectedStars,
                          comment: commentController.text.trim(),
                        );
                        if (!dialogCtx.mounted) return;
                        if (ok) {
                          Navigator.pop(dialogCtx, true);
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            submitError = ap.error ?? 'Gửi đánh giá thất bại';
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Gửi đánh giá',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá dịch vụ! ⭐'),
          backgroundColor: AppColors.ok,
        ),
      );
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    BuildContext sheetContext,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (d) => AlertDialog(
        title: const Text('Xác nhận hủy lịch'),
        content: Text('Bạn có chắc chắn muốn hủy lịch hẹn ${a.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Không'),
          ),
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
      final packages = context.read<ServicePackageProvider>();
      Navigator.pop(sheetContext); // đóng bottom sheet
      final ok = await ap.cancel(a.id);
      if (ok && a.customerPackageId != null) packages.invalidateOwned();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Đã hủy lịch hẹn ${a.code}'
                : (ap.error ?? 'Hủy lịch thất bại'),
          ),
        ),
      );
    }
  }

  List<Widget> _buildNoteDetails(String? rawNote, ColorScheme cs) {
    if (rawNote == null || rawNote.trim().isEmpty) return const [];

    String text = rawNote.trim();
    String? reminder;
    String? voucher;
    String? paymentMethod;

    final reminderMatch = RegExp(r'\[Nhắc hẹn:\s*([^\]]+)\]').firstMatch(text);
    if (reminderMatch != null) {
      reminder = reminderMatch.group(1)?.trim();
      text = text.replaceAll(reminderMatch.group(0)!, '').trim();
    }

    final voucherMatch = RegExp(r'\[Voucher:\s*([^\]]+)\]').firstMatch(text);
    if (voucherMatch != null) {
      voucher = voucherMatch.group(1)?.trim();
      text = text.replaceAll(voucherMatch.group(0)!, '').trim();
    }

    final paymentMatch = RegExp(r'\[Thanh toán:\s*([^\]]+)\]').firstMatch(text);
    if (paymentMatch != null) {
      paymentMethod = paymentMatch.group(1)?.trim();
      text = text.replaceAll(paymentMatch.group(0)!, '').trim();
    }

    final remaining = text.trim();
    final widgets = <Widget>[];

    if (paymentMethod != null) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(
        Row(
          children: [
            Icon(
              paymentMethod.contains('Chuyển khoản')
                  ? Icons.qr_code_2
                  : Icons.payments_outlined,
              size: 17,
              color: AppColors.rose,
            ),
            const SizedBox(width: 8),
            const Text(
              'Hình thức thanh toán: ',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              paymentMethod,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (voucher != null) {
      widgets.add(const SizedBox(height: 6));
      widgets.add(
        Row(
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 17,
              color: AppColors.rose,
            ),
            const SizedBox(width: 8),
            const Text(
              'Voucher ưu đãi: ',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              voucher,
              style: const TextStyle(
                color: AppColors.rose,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (reminder != null) {
      widgets.add(const SizedBox(height: 6));
      widgets.add(
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 17,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            const Text(
              'Nhắc hẹn: ',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              reminder,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (remaining.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes_outlined, size: 17, color: cs.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ghi chú: $remaining',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return widgets;
  }
}
