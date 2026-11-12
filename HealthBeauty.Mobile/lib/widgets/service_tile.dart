import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/catalog.dart';
import 'common.dart';
import 'catalog_image.dart';

/// Only display promotions and ratings explicitly supplied by data.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.service,
    required this.categoryName,
    required this.onTap,
    this.discountLabel,
  });
  final Service service;
  final String categoryName;
  final VoidCallback onTap;
  final String? discountLabel;

  @override
  Widget build(BuildContext context) => _CatalogCard(
    name: service.name,
    imageUrl: service.imageUrl,
    price: service.price,
    subtitle: durationStr(service.durationMinutes),
    category: categoryName,
    rating: service.totalReviews > 0 ? service.averageRating : null,
    discountLabel: discountLabel,
    bookingLabel: service.bookedCount > 0
        ? 'Đã đặt ${service.bookedCount}'
        : service.hasBookingStatistics
        ? 'Mới'
        : null,
    reviewLabel: !service.hasReviewStatistics
        ? 'Xem đánh giá'
        : service.totalReviews == 0
        ? 'Chưa đánh giá'
        : '${service.totalReviews} đánh giá',
    onTap: onTap,
  );
}

class ComboCard extends StatelessWidget {
  const ComboCard({super.key, required this.combo, required this.onTap});
  final Combo combo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _CatalogCard(
    name: combo.name,
    imageUrl: combo.imageUrl,
    price: combo.price,
    subtitle: '${combo.totalServices} d\u1ecbch v\u1ee5',
    category: 'Combo ch\u0103m s\u00f3c',
    onTap: onTap,
  );
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.subtitle,
    required this.category,
    required this.onTap,
    this.rating,
    this.discountLabel,
    this.bookingLabel,
    this.reviewLabel,
  });
  final String name;
  final String? imageUrl;
  final double price;
  final String subtitle;
  final String category;
  final VoidCallback onTap;
  final double? rating;
  final String? discountLabel;
  final String? bookingLabel;
  final String? reviewLabel;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.outline.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight =
                (constraints.maxHeight -
                        (bookingLabel == null && reviewLabel == null
                                ? 146
                                : 174) *
                            scale)
                    .clamp(48.0, constraints.maxWidth * .82);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CatalogImage(imageUrl: imageUrl, semanticLabel: name),
                      if (discountLabel != null &&
                          discountLabel!.trim().isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.roseContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              discountLabel!,
                              style: const TextStyle(
                                color: AppColors.onRoseContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 13,
                              color: AppColors.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                            if (rating != null) ...[
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFD19A38),
                              ),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          vnd(price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.rose,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (category.isNotEmpty)
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        if (bookingLabel != null || reviewLabel != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 3,
                            children: [
                              if (reviewLabel != null)
                                Text(
                                  reviewLabel!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              if (bookingLabel != null)
                                Text(
                                  bookingLabel!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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
                Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
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
          Text(
            vnd(service.price),
            style: const TextStyle(
              color: AppColors.rose,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                Text(
                  combo.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${combo.totalServices} dịch vụ trong combo',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            vnd(combo.price),
            style: const TextStyle(
              color: AppColors.rose,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
