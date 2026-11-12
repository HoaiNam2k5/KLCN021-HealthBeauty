import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import '../screens/booking_screen.dart';
import '../screens/login_screen.dart';

class PromoBannerDialog extends StatelessWidget {
  const PromoBannerDialog({super.key});

  static bool _hasShownThisSession = false;

  /// Hiển thị popup quảng cáo / ưu đãi nếu chưa từng hiển thị trong phiên mở app này
  static void showIfFirstTime(BuildContext context) {
    if (_hasShownThisSession) return;
    _hasShownThisSession = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      show(context);
    });
  }

  /// Hiển thị popup banner
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => const PromoBannerDialog(),
    );
  }

  /// Reset trạng thái đã hiển thị (dùng cho test hoặc khi muốn kích hoạt lại)
  static void resetSession() {
    _hasShownThisSession = false;
  }

  Future<void> _onBannerAction(BuildContext context) async {
    Navigator.of(context).pop();

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
      MaterialPageRoute(builder: (_) => const BookingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxDialogWidth = (screenSize.width * 0.90).clamp(280.0, 390.0);
    final maxDialogHeight = screenSize.height * 0.82;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDialogWidth,
            maxHeight: maxDialogHeight,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Khung card chứa nội dung banner
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hình ảnh banner
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _onBannerAction(context),
                        child: Image.asset(
                          'assets/images/welcome_banner.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 320,
                              color: AppColors.roseContainer,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.spa, size: 54, color: AppColors.rose),
                                  SizedBox(height: 12),
                                  Text(
                                    'Ưu đãi khách hàng mới: Giảm 10%',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.onRoseContainer,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Áp dụng cho tất cả dịch vụ spa',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.onRoseContainer),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Thanh nút bấm đặt lịch nhận ưu đãi
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          key: const Key('promo_banner_action_button'),
                          onPressed: () => _onBannerAction(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.rose,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text(
                            'Đặt lịch nhận ưu đãi ngay',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dấu X để người dùng ẩn / đóng banner đi
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  key: const Key('promo_banner_close_button'),
                  color: Colors.black.withValues(alpha: 0.60),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
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
