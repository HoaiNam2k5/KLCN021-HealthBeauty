import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/services_screen.dart';
import 'package:app_doancunhan/widgets/service_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late CatalogProvider catalog;

  setUp(() {
    catalog = CatalogProvider()
      ..loaded = true
      ..categories = const [ServiceCategory(id: 1, name: 'Chăm sóc da')]
      ..services = const [
        Service(
          id: 1,
          categoryId: 1,
          name: 'Dịch vụ giá thấp',
          price: 100000,
          durationMinutes: 30,
        ),
        Service(
          id: 2,
          categoryId: 1,
          name: 'Dịch vụ trong khoảng',
          price: 300000,
          durationMinutes: 45,
        ),
        Service(
          id: 3,
          categoryId: 1,
          name: 'Dịch vụ giá cao',
          price: 700000,
          durationMinutes: 60,
        ),
      ];
  });

  tearDown(() => catalog.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: catalog,
        child: const MaterialApp(
          home: Scaffold(body: SafeArea(child: ServicesScreen())),
        ),
      ),
    );
  }

  testWidgets('filters services by an inclusive price range and can clear it', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byType(ServiceCard), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('price_filter_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('minimum_price_field')),
      '100000',
    );
    await tester.enterText(
      find.byKey(const Key('maximum_price_field')),
      '300000',
    );
    await tester.tap(find.byKey(const Key('apply_price_filter')));
    await tester.pumpAndSettle();

    expect(find.byType(ServiceCard), findsNWidgets(2));
    expect(find.textContaining('100.000 ₫ – 300.000 ₫'), findsOneWidget);

    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('price_filter_button')),
    );
    chip.onDeleted!();
    await tester.pump();
    expect(find.byType(ServiceCard), findsNWidgets(3));
  });

  testWidgets('keeps the filter sheet open when minimum exceeds maximum', (
    tester,
  ) async {
    await pumpScreen(tester);
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
  });

  testWidgets('rejects a selected price below the catalog minimum', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('price_filter_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('minimum_price_field')),
      '50000',
    );
    await tester.enterText(
      find.byKey(const Key('maximum_price_field')),
      '300000',
    );
    await tester.tap(find.byKey(const Key('apply_price_filter')));
    await tester.pump();

    expect(find.text('Mức giá không được thấp hơn 100.000 ₫.'), findsOneWidget);
    expect(find.byKey(const Key('minimum_price_field')), findsOneWidget);
    expect(find.byType(ServiceCard), findsNWidgets(3));
  });
}
