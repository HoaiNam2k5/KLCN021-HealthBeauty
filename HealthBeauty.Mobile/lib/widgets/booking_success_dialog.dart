import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/appointment.dart';

/// Modal Dialog / BottomSheet chúc mừng đặt lịch thành công với phong cách Spa & Clinic sang trọng.
class BookingSuccessDialog extends StatelessWidget {
  final Appointment appointment;
  final String? reminderText;
  final String? staffName;
  final VoidCallback onViewAppointment;
  final VoidCallback onGoHome;

  const BookingSuccessDialog({
    super.key,
    required this.appointment,
    this.reminderText,
    this.staffName,
    required this.onViewAppointment,
    required this.onGoHome,
  });

  /// Hàm tiện ích mở BottomSheet xác nhận đặt lịch
  static Future<void> show(
    BuildContext context, {
    required Appointment appointment,
    String? reminderText,
    String? staffName,
    required VoidCallback onViewAppointment,
    required VoidCallback onGoHome,
    bool Function()? isCurrent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BookingSuccessDialog(
        appointment: appointment,
        reminderText: reminderText,
        staffName: staffName,
        onViewAppointment: () {
          Navigator.of(sheetContext).pop();
          if (isCurrent?.call() ?? true) onViewAppointment();
        },
        onGoHome: () {
          Navigator.of(sheetContext).pop();
          if (isCurrent?.call() ?? true) onGoHome();
        },
      ),
    );
  }

  /// Present from the surviving navigator after removing the booking routes.
  /// Neither the sheet nor its actions retain the disposed booking State.
  static Future<void> showAfterBooking(
    BuildContext context, {
    required Appointment appointment,
    String? reminderText,
    String? staffName,
    required VoidCallback onViewAppointment,
    required VoidCallback onGoHome,
    bool Function()? isCurrent,
  }) {
    if (!(isCurrent?.call() ?? true)) return Future<void>.value();
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route.isFirst);
    return show(
      navigator.context,
      appointment: appointment,
      reminderText: reminderText,
      staffName: staffName,
      onViewAppointment: onViewAppointment,
      onGoHome: onGoHome,
      isCurrent: isCurrent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = appointment.appointmentAt;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh gạt modal
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon chúc mừng mạ viền hồng sang trọng
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F3), Color(0xFFFFE3EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.rose.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.rose.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.rose,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),

              // Tiêu đề & Lời chúc
              const Text(
                'Đặt Lịch Thành Công!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'HealthBeauty Spa rất hân hạnh được đồng hành và chăm sóc cho quý khách.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Thẻ tóm tắt vé lịch hẹn (Mini Pass)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.6),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    // Thời gian
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.rose,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${weekdayStr(d)}, ${dateStr(d)} lúc ${timeStr(d)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Dịch vụ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          size: 16,
                          color: AppColors.sage,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appointment.serviceSummary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (staffName != null && staffName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Color(0xFFC47B2B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kỹ thuật viên: $staffName',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (reminderText != null && reminderText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            size: 16,
                            color: AppColors.rose,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nhắc hẹn đã chọn: $reminderText',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.rose,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Lời nhắn hiếu khách từ Spa
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0E5D8)),
                ),
                child: const Row(
                  children: [
                    Text('🍵', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Quý khách vui lòng đến trước 10 phút để được thưởng thức trà thảo mộc & soi da chuyên sâu miễn phí.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A685A),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nút hành động
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      backgroundColor: AppColors.rose,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'Xem vé lịch hẹn của tôi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: onViewAppointment,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  onPressed: onGoHome,
                  child: const Text(
                    'Về trang chủ',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
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
