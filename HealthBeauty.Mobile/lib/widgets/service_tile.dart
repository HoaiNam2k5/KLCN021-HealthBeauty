import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/catalog.dart';
import 'common.dart';
import 'catalog_image.dart';

/// Thẻ dịch vụ hình chữ nhật đứng theo phong cách e-commerce (2 cột, như hình 1)
class ServiceCard extends StatelessWidget {
  final Service service;
  final String categoryName;
  final VoidCallback onTap;
  final String? discountLabel;

  const ServiceCard({
    super.key,
    required this.service,
    required this.categoryName,
    required this.onTap,
    this.discountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Giảm giá hiển thị ở góc trên bên phải ảnh (nếu có khuyến mãi)
    final discount = discountLabel;

    // Số lượt đặt dịch vụ thực tế từ CSDL
    final bookedText = service.bookedCount > 0 ? 'Đã đặt ${service.bookedCount}' : 'Mới';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ảnh minh họa kèm các badge (Voucher & Discount)
              AspectRatio(
                aspectRatio: 1.15,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: CatalogImage(
                        imageUrl: service.imageUrl,
                        semanticLabel: service.name,
                      ),
                    ),
                    // Badge giảm giá góc trên phải (-XX% như hình 1)
                    if (discount != null)
                      Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFECEE),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(11),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    // Badge Voucher góc dưới trái ảnh (như hình 1)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE000),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 9, color: Color(0xFFD63031)),
                            SizedBox(width: 2),
                            Text(
                              'VOUCHER',
                              style: TextStyle(
                                color: Color(0xFFD63031),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Nội dung chi tiết (Tên kèm tag "Yêu thích", Đánh giá, Giá tiền, Danh mục)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tên dịch vụ kèm tag "Yêu thích" đỏ (như hình 1)
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4, bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEE4D2D),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'Yêu thích',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(
                              text: service.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Hàng Tag thời lượng + Đánh giá sao (như hình 1)
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.roseContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: AppColors.rose.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                durationStr(service.durationMinutes),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onRoseContainer,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (service.totalReviews > 0 && service.averageRating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB300)),
                                const SizedBox(width: 1),
                                Text(
                                  service.averageRating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'Chưa đánh giá',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                        ],
                      ),

                      // Hàng Giá tiền + Số lượt đã đặt
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              vnd(service.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.rose,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bookedText,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),

                      // Hàng Danh mục dịch vụ
                      Row(
                        children: [
                          Icon(Icons.spa_outlined, size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              categoryName.isNotEmpty ? categoryName : 'Chăm sóc sắc đẹp',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Thẻ combo hình chữ nhật đứng (Grid card phong cách e-commerce)
class ComboCard extends StatelessWidget {
  final Combo combo;
  final VoidCallback onTap;

  const ComboCard({
    super.key,
    required this.combo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookedCount = 'Trọn gói';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ảnh combo + Badges
              AspectRatio(
                aspectRatio: 1.15,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: CatalogImage(
                        imageUrl: combo.imageUrl,
                        semanticLabel: combo.name,
                        icon: Icons.auto_awesome_outlined,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(11),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'TIẾT KIỆM',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE000),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 9, color: Color(0xFFD63031)),
                            SizedBox(width: 2),
                            Text(
                              'COMBO HOT',
                              style: TextStyle(
                                color: Color(0xFFD63031),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Nội dung chi tiết Combo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4, bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.sage,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'Combo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(
                              text: combo.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.sageContainer,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${combo.totalServices} dịch vụ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSageContainer,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: Color(0xFFFFB300)),
                              SizedBox(width: 2),
                              Text(
                                'Ưu đãi',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              vnd(combo.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.rose,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bookedCount,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.card_giftcard_outlined, size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'Liệu trình trọn gói',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Thẻ danh sách hàng ngang (legacy / dùng khi cần hiển thị dạng list hàng ngang)
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
