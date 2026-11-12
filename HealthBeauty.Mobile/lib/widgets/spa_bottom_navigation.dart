import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Presentation order differs from legacy tab indices used by existing flows.
class SpaBottomNavigation extends StatelessWidget {
  const SpaBottomNavigation({
    super.key,
    required this.tab,
    required this.onTab,
    required this.onBook,
  });
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.70),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _item('Trang chủ', Icons.home_outlined, 0),
                _item('Dịch vụ', Icons.spa_outlined, 1),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Đặt lịch',
                    child: InkWell(
                      key: const Key('nav_booking'),
                      onTap: onBook,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE57383), AppColors.rose],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.rose.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_month_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Đặt lịch',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.rose,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _item('Lịch hẹn', Icons.event_note_outlined, 2),
                _item('Tài khoản', Icons.person_outline, 4),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _item(String label, IconData icon, int target) => Expanded(
    child: Semantics(
      button: true,
      selected: tab == target,
      child: InkWell(
        key: ValueKey('nav_tab_$target'),
        onTap: () => onTab(target),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: tab == target ? AppColors.rose : AppColors.inkMuted,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: tab == target ? AppColors.rose : AppColors.inkMuted,
                  fontWeight: tab == target ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
