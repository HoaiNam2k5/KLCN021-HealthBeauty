import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/spa_assistant_screen.dart';

class HomeSupportButtons extends StatelessWidget {
  const HomeSupportButtons({super.key});
  static const hotline = '19008888';

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _button(
        context,
        label: 'Trợ lý tư vấn spa',
        icon: Icons.auto_awesome,
        size: 52,
        colors: const [Color(0xffb17ac1), Color(0xffd989ab)],
        onTap: () async {
          if (!context.read<AuthProvider>().isLoggedIn) {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
            if (result != true ||
                !context.mounted ||
                !context.read<AuthProvider>().isLoggedIn) {
              return;
            }
          }
          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SpaAssistantScreen()),
            );
          }
        },
      ),
      const SizedBox(height: 10),
      _button(
        context,
        label: 'Liên hệ hotline',
        icon: Icons.phone_in_talk,
        size: 48,
        colors: const [Color(0xffd7898d), Color(0xffad6b77)],
        onTap: () => _hotline(context),
      ),
    ],
  );

  Widget _button(
    BuildContext context, {
    required String label,
    required IconData icon,
    required double size,
    required List<Color> colors,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
          ),
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    ),
  );

  Future<void> _hotline(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Liên hệ HealthBeauty',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Hotline 1900 8888',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                var success = false;
                try {
                  success = await launchUrl(
                    Uri(scheme: 'tel', path: hotline),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  // Some devices do not provide a phone application.
                }
                if (!success && sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Không mở được ứng dụng gọi điện.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.phone),
              label: const Text('Gọi ngay'),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: hotline));
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép số hotline.')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép số'),
            ),
          ],
        ),
      ),
    ),
  );
}
