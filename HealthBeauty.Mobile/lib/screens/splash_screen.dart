import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Màn hình Splash khởi động phong cách Luxury Pulse & Glow dành cho Spa & Thẩm mỹ viện.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _bottomFade;

  @override
  void initState() {
    super.initState();

    // Controller cho hiệu ứng xuất hiện ban đầu (~1400ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Controller cho vòng hào quang thở nhẹ nhàng (lặp lại liên tục, 2200ms)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _bottomFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward().then((_) {
      if (mounted) {
        widget.onFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF9FA), // Trắng hồng ngọc trai êm dịu
              Color(0xFFFDEEF1), // Hồng phấn pastel nhẹ nhàng
              AppColors.cream,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),

              // Trung tâm: Logo với hào quang Pulse & Glow
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 2 Vòng hào quang gợn sóng thư thái (Pulse Ripple)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                final val = _pulseController.value;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Vòng ngoài
                                    Transform.scale(
                                      scale: 1.0 + (val * 0.75),
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.rose.withValues(
                                            alpha: (1.0 - val) * 0.16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Vòng trong
                                    Transform.scale(
                                      scale: 1.0 + (val * 0.40),
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.rose.withValues(
                                            alpha: (1.0 - val) * 0.28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            // Huy hiệu Logo hình tròn sang trọng
                            Container(
                              width: 94,
                              height: 94,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.rose.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 26,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Tên thương hiệu & Slogan
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Column(
                          children: [
                            const Text(
                              'HealthBeauty',
                              style: TextStyle(
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ĐÁNH THỨC VẺ ĐẸP TỰ NHIÊN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                                color: AppColors.rose.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Đáy màn hình: 3 chấm breathing indicator thanh thoát
              FadeTransition(
                opacity: _bottomFade,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final delay = index * 0.25;
                          final progress = (_pulseController.value + delay) % 1.0;
                          final scale = 0.75 + (0.45 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));
                          final alpha = 0.35 + (0.65 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 7 * scale,
                            height: 7 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.rose.withValues(alpha: alpha),
                            ),
                          );
                        }),
                      );
                    },
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
