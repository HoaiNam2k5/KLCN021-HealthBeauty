import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Thanh tiến trình 3 bước trực quan, hiện đại cho quy trình Đặt lịch hẹn
class BookingStepperHeader extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int>? onStepTapped;

  const BookingStepperHeader({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  static const _steps = [
    _StepItem(
      title: 'Dịch vụ',
      icon: Icons.spa_outlined,
      activeIcon: Icons.spa,
    ),
    _StepItem(
      title: 'Thời gian & KTV',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
    ),
    _StepItem(
      title: 'Xác nhận',
      icon: Icons.verified_outlined,
      activeIcon: Icons.verified,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                Expanded(
                  child: Semantics(
                    selected: i == currentStep,
                    label: 'Bước ${i + 1}: ${_steps[i].title}',
                    child: InkWell(
                      onTap: onStepTapped != null && i <= currentStep
                          ? () => onStepTapped!(i)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: _buildStepNode(
                        index: i,
                        step: _steps[i],
                        isCurrent: i == currentStep,
                        isCompleted: i < currentStep,
                      ),
                    ),
                  ),
                ),
                if (i < _steps.length - 1)
                  _buildConnector(isCompleted: i < currentStep),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required int index,
    required _StepItem step,
    required bool isCurrent,
    required bool isCompleted,
  }) {
    Color nodeColor;
    Color iconColor;
    Border? border;

    if (isCurrent) {
      nodeColor = AppColors.rose;
      iconColor = Colors.white;
    } else if (isCompleted) {
      nodeColor = AppColors.sage;
      iconColor = Colors.white;
    } else {
      nodeColor = AppColors.surfaceTint;
      iconColor = AppColors.inkMuted;
      border = Border.all(color: AppColors.outline);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: nodeColor,
            shape: BoxShape.circle,
            border: border,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.rose.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Icon(
                    isCurrent ? step.activeIcon : step.icon,
                    color: iconColor,
                    size: 19,
                  ),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              color: isCurrent
                  ? AppColors.rose
                  : (isCompleted ? AppColors.sage : AppColors.inkMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector({required bool isCompleted}) {
    return Container(
      width: 16,
      height: 3,
      margin: const EdgeInsets.only(bottom: 34, left: 3, right: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.sage
            : AppColors.outline.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _StepItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  const _StepItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });
}
