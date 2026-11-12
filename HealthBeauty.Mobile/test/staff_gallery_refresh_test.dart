import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/widgets/staff_showcase.dart';
import 'package:app_doancunhan/screens/staff_gallery_screen.dart';

void main() {
  testWidgets(
    'all staff posters are bundled and open in an independent zoom viewer',
    (tester) async {
      for (final poster in staffPosters) {
        final data = await rootBundle.load(poster.asset);
        expect(data.lengthInBytes, greaterThan(0));
      }
      await tester.pumpWidget(const MaterialApp(home: StaffGalleryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(StaffPosterViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
      expect(find.text('KTV Trinh · 1/5'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('KTV Puu · 2/5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('showcase opens full gallery without requiring account data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: StaffShowcase())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();
    expect(find.byType(StaffGalleryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
