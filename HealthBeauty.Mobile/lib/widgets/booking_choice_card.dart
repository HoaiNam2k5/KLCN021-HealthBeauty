import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'catalog_image.dart';

class BookingChoiceCard extends StatelessWidget {
  const BookingChoiceCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.duration,
    this.price,
    this.detail,
    this.footer,
    this.selected = false,
    this.onTap,
  });
  final String title;
  final String? imageUrl, duration, price, detail;
  final Widget? footer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? AppColors.roseContainer.withValues(alpha: .45)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? AppColors.rose
                : AppColors.outline.withValues(alpha: .5),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1,
                          child: CatalogImage(
                            imageUrl: imageUrl,
                            semanticLabel: title,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (duration != null) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 15,
                                  color: AppColors.inkMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    duration!,
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (price != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              price!,
                              style: const TextStyle(
                                color: AppColors.rose,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (detail != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              detail!,
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected
                            ? AppColors.rose
                            : Theme.of(context).colorScheme.outline,
                        semanticLabel: selected ? 'Đã chọn' : 'Chưa chọn',
                      ),
                    ],
                  ],
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
