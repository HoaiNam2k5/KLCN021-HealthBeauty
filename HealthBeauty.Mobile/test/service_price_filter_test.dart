import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/models/service_price_filter.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/services_screen.dart';
import 'package:app_doancunhan/widgets/service_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'range allows zero, no bounds, one-sided bounds and inclusive endpoints',
    () {
      expect(ServicePriceRange.parse('', '').includes(100000), true);
      final range = ServicePriceRange.parse('0', '200000');
      expect(range.includes(100000), true);
      expect(range.includes(200000), true);
      expect(range.includes(300000), false);
      expect(ServicePriceRange.parse('100000', '').includes(99999), false);
      expect(ServicePriceRange.parse('', '100000').includes(100000), true);
    },
  );

  test(
    'range rejects negatives, invalid numbers, infinity and reversed bounds',
    () {
      for (final values in [
        ['-1', ''],
        ['', '-1'],
        ['NaN', ''],
        ['Infinity', ''],
        ['abc', ''],
        ['200000', '100000'],
      ]) {
        expect(
          () => ServicePriceRange.parse(values[0], values[1]),
          throwsFormatException,
        );
      }
    },
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = CatalogProvider()
      ..loaded = true
      ..categories = const [ServiceCategory(id: 1, name: 'Chăm sóc da')]
      ..services = const [
        Service(
          id: 1,
          categoryId: 1,
          name: 'Dịch vụ thấp',
          price: 100000,
          durationMinutes: 30,
        ),
        Service(
          id: 2,
          categoryId: 1,
          name: 'Dịch vụ giữa',
          price: 300000,
          durationMinutes: 30,
        ),
        Service(
          id: 3,
          categoryId: 1,
          name: 'Dịch vụ cao',
          price: 700000,
          durationMinutes: 30,
        ),
      ];
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: catalog,
        child: const MaterialApp(
          home: Scaffold(body: SafeArea(child: ServicesScreen())),
        ),
      ),
    );
  }

  testWidgets(
    'zero-to-budget range filters cards, preserves package entry and clears',
    (tester) async {
      await pump(tester);
      expect(find.byType(ServiceCard), findsNWidgets(3));
      expect(find.text('Gói dịch vụ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('price_filter_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('minimum_price_field')), '0');
      await tester.enterText(
        find.byKey(const Key('maximum_price_field')),
        '200000',
      );
      await tester.tap(find.byKey(const Key('apply_price_filter')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCard), findsOneWidget);
      final chip = tester.widget<FilterChip>(
        find.byKey(const Key('price_filter_button')),
      );
      chip.onDeleted!();
      await tester.pump();
      expect(find.byType(ServiceCard), findsNWidgets(3));
    },
  );

  testWidgets(
    'reversed bounds keep sheet open and do not change service list',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('price_filter_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('minimum_price_field')),
        '500000',
      );
      await tester.enterText(
        find.byKey(const Key('maximum_price_field')),
        '200000',
      );
      await tester.tap(find.byKey(const Key('apply_price_filter')));
      await tester.pump();
      expect(
        find.text('Giá tối thiểu không được lớn hơn giá tối đa.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('minimum_price_field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('clear_price_filter')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCard), findsNWidgets(3));
    },
  );
}
