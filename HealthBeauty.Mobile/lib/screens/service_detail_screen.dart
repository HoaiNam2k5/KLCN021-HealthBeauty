import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/catalog.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import '../widgets/catalog_image.dart';
import '../widgets/before_after_slider.dart';
import 'booking_screen.dart';
import 'login_screen.dart';

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
      appBar: AppBar(title: const Text('Chi tiết dịch vụ')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.outline.withValues(alpha: .4)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FilledButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(ctaLabel, textAlign: TextAlign.center),
            ),
          ),
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
                    child: Text(
                      '${p.name} · ${p.discountLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
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
    final service = catalog.services.firstWhere(
      (item) => item.id == this.service.id,
      orElse: () => this.service,
    );
    final cs = Theme.of(context).colorScheme;
    final category = catalog.categoryName(service.categoryId);

    return _DetailScaffold(
      title: service.name,
      ctaLabel: 'Đặt lịch dịch vụ này',
      onCta: () async {
        final auth = context.read<AuthProvider>();
        if (!auth.isLoggedIn) {
          final loggedIn = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          if (loggedIn != true ||
              !context.mounted ||
              !context.read<AuthProvider>().isLoggedIn) {
            return;
          }
        }
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingScreen(initialService: service),
          ),
        );
      },
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CatalogImage(
              imageUrl: service.imageUrl,
              semanticLabel: service.name,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
            if (service.totalReviews > 0 && service.averageRating != null)
              Chip(
                avatar: const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Colors.amber,
                ),
                label: Text(
                  '${service.averageRating!.toStringAsFixed(1)} (${service.totalReviews} đánh giá)',
                ),
              ),
            if (service.bookedCount > 0)
              Chip(
                avatar: const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.rose,
                ),
                label: Text('Đã đặt ${service.bookedCount} lượt'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          vnd(service.price),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.rose,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('service_reviews_button'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceReviewsScreen(
                serviceId: service.id,
                serviceName: service.name,
              ),
            ),
          ),
          icon: const Icon(Icons.rate_review_outlined),
          label: Text(
            service.hasReviewStatistics
                ? 'Đánh giá & bình luận (${service.totalReviews})'
                : 'Xem đánh giá & bình luận',
          ),
        ),
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
        _ServiceReviewsSection(serviceId: service.id),
        const SizedBox(height: 20),
        const BeforeAfterSlider(),
      ],
    );
  }
}

class ComboDetailScreen extends StatelessWidget {
  final Combo combo;
  const ComboDetailScreen({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final combo = catalog.combos.firstWhere(
      (item) => item.id == this.combo.id,
      orElse: () => this.combo,
    );
    final cs = Theme.of(context).colorScheme;

    String? validity;
    if (combo.validFrom != null || combo.validTo != null) {
      validity =
          'Hiệu lực: '
          '${combo.validFrom != null ? dateStr(combo.validFrom!) : '...'}'
          ' – '
          '${combo.validTo != null ? dateStr(combo.validTo!) : '...'}';
    }

    return _DetailScaffold(
      title: combo.name,
      ctaLabel: 'Đặt combo này',
      onCta: () async {
        final auth = context.read<AuthProvider>();
        if (!auth.isLoggedIn) {
          final loggedIn = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          if (loggedIn != true ||
              !context.mounted ||
              !context.read<AuthProvider>().isLoggedIn) {
            return;
          }
        }
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingScreen(initialCombo: combo)),
        );
      },
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CatalogImage(
              imageUrl: combo.imageUrl,
              semanticLabel: combo.name,
              icon: Icons.auto_awesome_outlined,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          vnd(combo.price),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.rose,
          ),
        ),
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
                  Text(
                    'x${it.quantity}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        const _PromoNote(),
      ],
    );
  }
}

class ServiceReviewsScreen extends StatelessWidget {
  const ServiceReviewsScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });
  final int serviceId;
  final String serviceName;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đánh giá & bình luận')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          serviceName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nhận xét từ khách đã sử dụng dịch vụ. Để viết đánh giá, mở lịch đã hoàn thành trong Lịch hẹn → Lịch sử.',
        ),
        _ServiceReviewsSection(serviceId: serviceId),
      ],
    ),
  );
}

class _ServiceReviewsSection extends StatefulWidget {
  final int serviceId;
  const _ServiceReviewsSection({required this.serviceId});

  @override
  State<_ServiceReviewsSection> createState() => _ServiceReviewsSectionState();
}

class _ServiceReviewsSectionState extends State<_ServiceReviewsSection> {
  bool _loading = true;
  String? _error;
  int? _filterStars;
  ReviewSummary _summary = const ReviewSummary();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = context.read<CatalogProvider>();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await catalog.loadServiceReviews(widget.serviceId);
      if (mounted) setState(() => _summary = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được đánh giá. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Đánh giá & Nhận xét'),
          ErrorState(message: _error!, onRetry: _load),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SectionTitle(
          'Đánh giá & Nhận xét',
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Tải lại đánh giá',
            onPressed: _load,
          ),
        ),
        const SizedBox(height: 10),
        if (_summary.totalReviews == 0)
          AppCard(
            color: Colors.white,
            child: Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: AppColors.sage,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chưa có đánh giá nào cho dịch vụ này. Hãy trải nghiệm và là người đầu tiên đánh giá nhé!',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Khung điểm trung bình & Biểu đồ phân bổ sao
          if (MediaQuery.sizeOf(context).width < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 20)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_summary.averageRating.toStringAsFixed(1)} / 5',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.rose,
                    ),
                  ),
                  Text('${_summary.totalReviews} đánh giá'),
                ],
              ),
            )
          else
            AppCard(
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _summary.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.rose,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < _summary.averageRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_summary.totalReviews} đánh giá',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppColors.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 14),
                  // Biểu đồ phân bổ 5★ -> 1★
                  Expanded(
                    child: Column(
                      children: [
                        for (int s = 5; s >= 1; s--) ...[
                          Builder(
                            builder: (context) {
                              final count = _summary.items
                                  .where((i) => i.stars == s)
                                  .length;
                              final ratio = _summary.totalReviews > 0
                                  ? count / _summary.totalReviews
                                  : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1.5,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '$s★',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 5,
                                          color: AppColors.rose,
                                          backgroundColor:
                                              AppColors.surfaceTint,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 16,
                                      child: Text(
                                        '$count',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Bộ lọc đánh giá theo sao
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('Tất cả (${_summary.totalReviews})'),
                  selected: _filterStars == null,
                  selectedColor: AppColors.roseContainer,
                  checkmarkColor: AppColors.rose,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _filterStars == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _filterStars == null
                        ? AppColors.onRoseContainer
                        : AppColors.ink,
                  ),
                  onSelected: (_) => setState(() => _filterStars = null),
                ),
                for (int s = 5; s >= 1; s--) ...[
                  Builder(
                    builder: (context) {
                      final count = _summary.items
                          .where((i) => i.stars == s)
                          .length;
                      if (count == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: Text('$s Sao ($count)'),
                          selected: _filterStars == s,
                          selectedColor: AppColors.roseContainer,
                          checkmarkColor: AppColors.rose,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _filterStars == s
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _filterStars == s
                                ? AppColors.onRoseContainer
                                : AppColors.ink,
                          ),
                          onSelected: (_) => setState(
                            () => _filterStars = _filterStars == s ? null : s,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Danh sách nhận xét
          for (final r
              in (_filterStars == null
                  ? _summary.items
                  : _summary.items
                        .where((i) => i.stars == _filterStars)
                        .toList()))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.roseContainer,
                              child: Text(
                                r.customerName.isNotEmpty
                                    ? r.customerName[0].toUpperCase()
                                    : 'K',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.rose,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.customerName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    dateStr(r.createdAt),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < r.stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        r.comment!.trim(),
                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                    ],
                    if (r.reply != null && r.reply!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.storefront,
                                  size: 15,
                                  color: AppColors.rose,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'HealthBeauty Spa phản hồi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.rose,
                                    ),
                                  ),
                                ),
                                if (r.repliedAt != null)
                                  Text(
                                    dateStr(r.repliedAt!),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.reply!.trim(),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
