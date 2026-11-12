import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/main_shell.dart';
import '../screens/service_packages_screen.dart';
import 'promo_banner_dialog.dart';

/// Carousel Banner quảng cáo tự động trượt với thiết kế mở rộng hình ảnh sang trọng.
class HeroBannerCarousel extends StatefulWidget {
  const HeroBannerCarousel({super.key});

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  static const int _totalBanners = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _totalBanners;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              // Slide 1: Ưu đãi khách hàng mới (Giữ key home_promo_banner_card cho tests)
              GestureDetector(
                key: const Key('home_promo_banner_card'),
                onTap: () => PromoBannerDialog.show(context),
                child: _buildBannerCard(
                  badgeText: 'ƯU ĐÃI KHÁCH HÀNG MỚI',
                  badgeColor: AppColors.rose,
                  badgeIcon: Icons.local_fire_department,
                  title: 'Giảm 10% tất cả dịch vụ spa',
                  actionText: 'Nhận ưu đãi',
                  gradient: const [Color(0xFFFFF2E6), Color(0xFFFFE8EC)],
                  borderColor: AppColors.rose,
                  imageAsset: 'assets/images/welcome_banner.jpg',
                  fallbackIcon: Icons.spa,
                ),
              ),

              // Slide 2: Gói dịch vụ tiết kiệm
              GestureDetector(
                key: const Key('home_packages_banner_card'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServicePackagesScreen(),
                  ),
                ),
                child: _buildBannerCard(
                  badgeText: 'GÓI CHĂM SÓC',
                  badgeColor: AppColors.sage,
                  badgeIcon: Icons.card_giftcard,
                  title: 'Gói chăm sóc định kỳ',
                  actionText: 'Xem các gói',
                  gradient: const [Color(0xFFEBF5EE), Color(0xFFE0EFE6)],
                  borderColor: AppColors.sage,
                  imageAsset: 'assets/images/banner2.png',
                  fallbackIcon: Icons.all_inclusive,
                ),
              ),

              // Slide 3: Chăm sóc da chuyên sâu
              GestureDetector(
                key: const Key('home_skincare_banner_card'),
                onTap: () {
                  mainTab.value = 1; // Tab Dịch vụ
                },
                child: _buildBannerCard(
                  badgeText: 'CHĂM SÓC BẢN THÂN',
                  badgeColor: const Color(0xFFC47B2B),
                  badgeIcon: Icons.auto_awesome,
                  title: 'Dành thời gian cho làn da của bạn',
                  actionText: 'Khám phá ngay',
                  gradient: const [Color(0xFFFFF9E6), Color(0xFFFBEFD1)],
                  borderColor: const Color(0xFFC47B2B),
                  imageAsset: 'assets/images/banner3.png',
                  fallbackIcon: Icons.face_retouching_natural,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalBanners, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuad,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.rose
                    : AppColors.outline.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBannerCard({
    required String badgeText,
    required Color badgeColor,
    required IconData badgeIcon,
    required String title,
    String? actionText,
    required List<Color> gradient,
    required Color borderColor,
    String? imageAsset,
    required IconData fallbackIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image mở rộng toàn bộ diện tích thẻ banner
            if (imageAsset != null)
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _iconPlaceholder(badgeColor, fallbackIcon, gradient),
              )
            else
              _iconPlaceholder(badgeColor, fallbackIcon, gradient),

            // Lớp phủ Gradient: Trái sang Phải giúp hiển thị chữ rõ nét
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // Lớp phủ Gradient: Dưới lên trên để chữ phía dưới luôn tương phản tốt
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.50),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),

            // Nội dung tối giản, ít chữ, làm nổi bật ảnh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge gọn gàng
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tiêu đề súc tích + Nút hành động nhỏ gọn
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                actionText ?? 'Khám phá ngay',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 9,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder(Color color, IconData icon, List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
