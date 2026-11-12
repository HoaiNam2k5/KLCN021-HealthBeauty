import 'dart:convert';
import 'dart:io';

import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/services_screen.dart';
import 'package:app_doancunhan/widgets/service_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final path = Platform.environment['HEALTHBEAUTY_SQL_SERVICE_JSON'];
  final skip = path == null || path.isEmpty;

  Future<double> setup(WidgetTester tester) async {
    final input = jsonDecode(File(path!).readAsStringSync().replaceFirst('\uFEFF', '')) as Map<String, dynamic>;
    final price = (input['Price'] as num).toDouble();
    final service = Service(
      id: input['Id'] as int,
      categoryId: 1,
      name: input['Name'] as String,
      price: price,
      durationMinutes: input['Minutes'] as int,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = CatalogProvider()
      ..loaded = true
      ..categories = const []
      ..services = [service];
    addTearDown(catalog.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: catalog,
      child: const MaterialApp(home: Scaffold(body: SafeArea(child: ServicesScreen()))),
    ));
    await tester.pumpAndSettle();
    return price;
  }

  testWidgets('CAT03 filters the SQL snapshot at the inclusive price boundary', (tester) async {
    final price = await setup(tester);
    expect(find.byType(ServiceCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('price_filter_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('minimum_price_field')), price.toInt().toString());
    await tester.enterText(find.byKey(const Key('maximum_price_field')), price.toInt().toString());
    await tester.tap(find.byKey(const Key('apply_price_filter')));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('price_filter_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('minimum_price_field')), (price.toInt() + 1).toString());
    await tester.enterText(find.byKey(const Key('maximum_price_field')), '');
    await tester.tap(find.byKey(const Key('apply_price_filter')));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCard), findsNothing);
  }, skip: skip);

  testWidgets('CAT04 rejects a reversed price range for SQL snapshot data', (tester) async {
    final price = await setup(tester);
    await tester.tap(find.byKey(const Key('price_filter_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('minimum_price_field')), (price.toInt() + 1).toString());
    await tester.enterText(find.byKey(const Key('maximum_price_field')), price.toInt().toString());
    await tester.tap(find.byKey(const Key('apply_price_filter')));
    await tester.pump();
    expect(find.text('Giá tối thiểu không được lớn hơn giá tối đa.'), findsOneWidget);
    expect(find.byKey(const Key('minimum_price_field')), findsOneWidget);
  }, skip: skip);

  for (final sample in <(String, int, int, bool)>[
    ('lower boundary', 0, 100, true),
    ('middle of range', -1, 1, true),
    ('upper boundary', -100, 0, true),
    ('just below minimum', 1, 100, false),
    ('just above maximum', -100, -1, false),
  ]) {
    testWidgets('CAT03 SQL snapshot ${sample.$1}', (tester) async {
      final price = (await setup(tester)).toInt();
      await tester.tap(find.byKey(const Key('price_filter_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('minimum_price_field')), '${price + sample.$2}');
      await tester.enterText(find.byKey(const Key('maximum_price_field')), '${price + sample.$3}');
      await tester.tap(find.byKey(const Key('apply_price_filter')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCard), sample.$4 ? findsOneWidget : findsNothing);
    }, skip: skip);
  }
}
