import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';

/// Khung dùng chung cho chi tiết dịch vụ / combo
class _DetailScaffold extends StatelessWidget {
  final String title;
  final String ctaLabel;
  final VoidCallback onCta;
  final List<Widget> children;

  const _DetailScaffold({
    required this.title,
    required this.ctaLabel,
    required this.onCta,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: onCta, child: Text(ctaLabel)),
        ),
      ),
    );
  }
}

class _PromoNote extends StatelessWidget {
  const _PromoNote();

  @override
  Widget build(BuildContext context) {
    final promos = context.watch<CatalogProvider>().promotions.take(2).toList();
    if (promos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const SectionTitle('Ưu đãi đang diễn ra'),
        const SizedBox(height: 8),
        for (final p in promos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              color: AppColors.roseContainer.withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: AppColors.rose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${p.name} · ${p.discountLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final cs = Theme.of(context).colorScheme;
    final category = catalog.categoryName(service.categoryId);

    return _DetailScaffold(
      title: service.name,
      ctaLabel: 'Đặt lịch dịch vụ này',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(initialService: service)),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (category.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.category_outlined, size: 18),
                label: Text(category),
              ),
            Chip(
              avatar: const Icon(Icons.schedule, size: 18),
              label: Text(durationStr(service.durationMinutes)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(vnd(service.price),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.rose)),
        const SizedBox(height: 16),
        const SectionTitle('Mô tả'),
        const SizedBox(height: 6),
        Text(
          (service.description == null || service.description!.trim().isEmpty)
              ? 'Chưa có mô tả cho dịch vụ này.'
              : service.description!,
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
        ),
        const _PromoNote(),
      ],
    );
  }
}

class ComboDetailScreen extends StatelessWidget {
  final Combo combo;
  const ComboDetailScreen({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String? validity;
    if (combo.validFrom != null || combo.validTo != null) {
      validity = 'Hiệu lực: '
          '${combo.validFrom != null ? dateStr(combo.validFrom!) : '...'}'
          ' – '
          '${combo.validTo != null ? dateStr(combo.validTo!) : '...'}';
    }

    return _DetailScaffold(
      title: combo.name,
      ctaLabel: 'Đặt combo này',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(initialCombo: combo)),
      ),
      children: [
        Text(vnd(combo.price),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.rose)),
        if (validity != null) ...[
          const SizedBox(height: 4),
          Text(validity, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        const SectionTitle('Gồm các dịch vụ'),
        const SizedBox(height: 8),
        for (final it in combo.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.sage),
                  const SizedBox(width: 10),
                  Expanded(child: Text(it.serviceName)),
                  Text('x${it.quantity}',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        const _PromoNote(),
      ],
    );
  }
}
