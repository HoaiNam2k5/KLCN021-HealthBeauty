import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/core/app_theme.dart';
import 'package:app_doancunhan/core/spa_location.dart';
import 'package:app_doancunhan/screens/branch_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:app_doancunhan/widgets/home_discovery.dart';
import 'package:app_doancunhan/widgets/spa_bottom_navigation.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/providers/notification_provider.dart';
import 'package:app_doancunhan/providers/service_package_provider.dart';
import 'package:app_doancunhan/screens/home_screen.dart';

void main() {
  testWidgets('USER05: branch screen shows the map and configured address', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BranchScreen()));
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    await tester.scrollUntilVisible(find.text(SpaLocation.address), 300);
    expect(find.text(SpaLocation.address), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mở Google Maps'), 200);
    expect(find.text('Mở Google Maps'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('home discovery remains usable at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = CatalogProvider()..loaded = true;
    catalog.services = [
      const Service(
        id: 1,
        categoryId: 1,
        name: 'Chăm sóc da chuyên sâu phục hồi và thư giãn',
        price: 650000,
        durationMinutes: 75,
      ),
    ];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AppointmentProvider()),
          ChangeNotifierProvider(create: (_) => catalog),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => ServicePackageProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(1.6),
            ),
            child: const Scaffold(body: HomeScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -550));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('map and directions keep the complete approved address', () {
    expect(SpaLocation.mapUrl.queryParameters['api'], '1');
    expect(SpaLocation.mapUrl.queryParameters['query'], SpaLocation.address);
    expect(
      SpaLocation.directionsUrl.queryParameters['destination'],
      SpaLocation.address,
    );
    expect(SpaLocation.address, contains('140 Lê Trọng Tấn'));
    expect(SpaLocation.point.latitude, closeTo(10.806528, .000001));
  });

  testWidgets(
    'five visible destinations preserve existing tab targets and separate booking',
    (tester) async {
      final selected = <int>[];
      var bookings = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: SpaBottomNavigation(
              tab: 0,
              onTab: selected.add,
              onBook: () => bookings++,
            ),
          ),
        ),
      );
      for (final tab in [0, 1, 2, 4]) {
        await tester.tap(find.byKey(ValueKey('nav_tab_$tab')));
      }
      await tester.tap(find.byKey(const Key('nav_booking')));
      expect(selected, [0, 1, 2, 4]);
      expect(bookings, 1);
      expect(find.text('Ưu đãi'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shortcuts and navigation fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var branchOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: HomeShortcuts(
              onServices: () {},
              onPackages: () {},
              onOffers: () {},
              onBranch: () => branchOpens++,
            ),
            bottomNavigationBar: SpaBottomNavigation(
              tab: 4,
              onTab: (_) {},
              onBook: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('shortcut_Cơ sở')));
    expect(branchOpens, 1);
    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
