import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/widgets/promo_banner_dialog.dart';

void main() {
  setUp(() {
    PromoBannerDialog.resetSession();
  });

  Widget buildTestApp({Widget? child}) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: child ??
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PromoBannerDialog.show(context),
                  child: const Text('Open Banner'),
                ),
              ),
        ),
      ),
    );
  }

  testWidgets('PromoBannerDialog renders close X button and action button', (tester) async {
    await tester.pumpWidget(buildTestApp());

    // Tap to open dialog
    await tester.tap(find.text('Open Banner'));
    await tester.pumpAndSettle();

    // Verify dialog elements exist
    expect(find.byType(PromoBannerDialog), findsOneWidget);
    expect(find.byKey(const Key('promo_banner_close_button')), findsOneWidget);
    expect(find.byKey(const Key('promo_banner_action_button')), findsOneWidget);
    expect(find.text('Đặt lịch nhận ưu đãi ngay'), findsOneWidget);

    // Verify close X icon exists
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Tap the close button
    await tester.tap(find.byKey(const Key('promo_banner_close_button')));
    await tester.pumpAndSettle();

    // Verify dialog is dismissed
    expect(find.byType(PromoBannerDialog), findsNothing);
  });

  testWidgets('PromoBannerDialog.showIfFirstTime shows dialog once per session', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: Builder(
          builder: (context) {
            PromoBannerDialog.showIfFirstTime(context);
            return const Text('Home Screen');
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(PromoBannerDialog), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.byKey(const Key('promo_banner_close_button')));
    await tester.pumpAndSettle();
    expect(find.byType(PromoBannerDialog), findsNothing);

    // Call showIfFirstTime again on same session - should not reopen
    await tester.pumpWidget(
      buildTestApp(
        child: Builder(
          builder: (context) {
            PromoBannerDialog.showIfFirstTime(context);
            return const Text('Home Screen Second Render');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PromoBannerDialog), findsNothing);
  });
}
