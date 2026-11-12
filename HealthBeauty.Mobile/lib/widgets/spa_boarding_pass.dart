import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/appointment.dart';
import 'common.dart';

/// Vé đối chiếu lịch tại quầy; không phải mã QR check-in tự động.
class SpaBoardingPassCard extends StatelessWidget {
  final Appointment a;
  final VoidCallback onTap;
  const SpaBoardingPassCard({super.key, required this.a, required this.onTap});

  String? _relativeDay() {
    if (a.isDone || a.isCancelled) return null;
    final now = DateTime.now().toLocal();
    final date = a.appointmentAt.toLocal();
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (days == 0) return 'Hôm nay';
    if (days == 1) return 'Ngày mai';
    return days > 1 ? 'Còn $days ngày' : null;
  }

  Widget _calendar(DateTime date) => Container(
    width: 64,
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(
            color: AppColors.rose,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(
            'Thg ${date.month}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            two(date.day),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final date = a.appointmentAt.toLocal();
    final relative = _relativeDay();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (relative != null)
              StatusChip(label: relative, color: AppColors.rose),
            StatusChip(label: a.statusLabel, color: statusColor(a.status)),
            if (a.isDone && a.hasReviewed)
              StatusChip(
                label: '${a.reviewStars ?? 5} ⭐',
                color: AppColors.warn,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          a.serviceSummary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              '${weekdayStr(date)}, ${timeStr(date)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              durationStr(a.durationMinutes),
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
          ],
        ),
        if (a.needsOutcomeUpdate)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Đã qua ngày hẹn · Cửa hàng chưa cập nhật kết quả',
              style: TextStyle(color: AppColors.warn, fontSize: 11.5),
            ),
          ),
      ],
    );
    return Semantics(
      button: true,
      label: 'Xem chi tiết vé lịch hẹn',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stack =
                          constraints.maxWidth < 340 ||
                          MediaQuery.textScalerOf(context).scale(14) > 21;
                      return stack
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _calendar(date),
                                const SizedBox(height: 12),
                                content,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _calendar(date),
                                const SizedBox(width: 14),
                                Expanded(child: content),
                              ],
                            );
                    },
                  ),
                ),
                _perforation(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Vé lịch hẹn',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                            color: AppColors.rose,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Xem chi tiết vé',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.rose,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.rose,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _perforation() => SizedBox(
    height: 18,
    child: Row(
      children: [
        Container(
          width: 9,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(9),
            ),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                (constraints.maxWidth / 9).floor(),
                (_) => const SizedBox(
                  width: 5,
                  height: 1.2,
                  child: ColoredBox(color: AppColors.outline),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 9,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(9),
            ),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
          ),
        ),
      ],
    ),
  );
}
