import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../providers/service_package_provider.dart';
import '../screens/service_packages_screen.dart';
import 'catalog_image.dart';
import 'common.dart';

class HomeShortcuts extends StatelessWidget {
  const HomeShortcuts({
    super.key,
    required this.onServices,
    required this.onPackages,
    required this.onOffers,
    required this.onBranch,
  });
  final VoidCallback onServices, onPackages, onOffers, onBranch;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Dịch vụ', Icons.spa_outlined, onServices),
      ('Gói dịch vụ', Icons.card_membership_outlined, onPackages),
      ('Ưu đãi', Icons.local_offer_outlined, onOffers),
      ('Cơ sở', Icons.location_on_outlined, onBranch),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                key: ValueKey('shortcut_${action.$1}'),
                onTap: action.$3,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.rose.withValues(alpha: .25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.rose.withValues(alpha: .06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(action.$2, color: AppColors.rose, size: 27),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HomePackageOffers extends StatelessWidget {
  const HomePackageOffers({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServicePackageProvider>();
    final offers = provider.catalog
        .where((item) => item.active)
        .take(4)
        .toList();
    void open() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServicePackagesScreen()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Gói chăm sóc',
          trailing: TextButton(
            onPressed: open,
            child: const Text('Xem tất cả'),
          ),
        ),
        const Text(
          'Chọn liệu trình phù hợp với bạn',
          style: TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 12),
        if (provider.catalogLoading && offers.isEmpty)
          const LinearProgressIndicator()
        else if (provider.catalogError != null && offers.isEmpty)
          TextButton.icon(
            onPressed: provider.loadCatalog,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại gói dịch vụ'),
          )
        else if (offers.isEmpty)
          OutlinedButton.icon(
            onPressed: open,
            icon: const Icon(Icons.card_membership_outlined),
            label: const Text('Khám phá gói dịch vụ'),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20
                  ? 1
                  : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final offer in offers)
                    SizedBox(
                      width: width,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: open,
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1.3,
                                  child: CatalogImage(
                                    imageUrl: offer.imageUrl,
                                    semanticLabel: offer.name,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      offer.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${offer.validityDays} ngày · ${offer.items.fold<int>(0, (sum, item) => sum + item.sessions)} lượt',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      vnd(offer.price),
                                      style: const TextStyle(
                                        color: AppColors.rose,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
