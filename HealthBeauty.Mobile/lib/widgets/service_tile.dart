import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/catalog.dart';
import 'common.dart';

class ServiceTile extends StatelessWidget {
  final Service service;
  final String categoryName;
  final VoidCallback onTap;

  const ServiceTile({
    super.key,
    required this.service,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.spa, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (categoryName.isNotEmpty) categoryName,
                    durationStr(service.durationMinutes),
                  ].join(' · '),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(vnd(service.price),
              style: const TextStyle(
                  color: AppColors.rose, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class ComboTile extends StatelessWidget {
  final Combo combo;
  final VoidCallback onTap;
  const ComboTile({super.key, required this.combo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.card_giftcard, color: cs.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(combo.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${combo.totalServices} dịch vụ trong combo',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(vnd(combo.price),
              style: const TextStyle(
                  color: AppColors.rose, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
