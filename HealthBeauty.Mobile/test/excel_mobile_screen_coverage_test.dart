import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/core/spa_location.dart';
import 'package:app_doancunhan/models/account.dart';
import 'package:app_doancunhan/models/customer.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/providers/notification_provider.dart';
import 'package:app_doancunhan/providers/profile_provider.dart';
import 'package:app_doancunhan/providers/service_package_provider.dart';
import 'package:app_doancunhan/screens/branch_screen.dart';
import 'package:app_doancunhan/screens/booking_screen.dart';
import 'package:app_doancunhan/screens/appointments_screen.dart';
import 'package:app_doancunhan/screens/customer_package_detail_screen.dart';
import 'package:app_doancunhan/screens/edit_profile_screen.dart';
import 'package:app_doancunhan/screens/notification_screen.dart';
import 'package:app_doancunhan/screens/service_packages_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
// Use the installed plugin's platform contract only to replace the native picker.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'service_packages_test.dart' as fixtures;
import 'customer_self_service_test.dart' as avatars;

class GalleryFixture extends ImagePickerPlatform {
  int selections = 0;
  final List<int> bytes;
  GalleryFixture({this.bytes = avatars.png});

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    expect(source, ImageSource.gallery);
    expect(options.maxWidth, 1024);
    expect(options.imageQuality, 85);
    selections++;
    return XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'avatar.png',
      mimeType: 'image/png',
    );
  }
}

AuthProvider signedIn(Dio dio) => AuthProvider(
  client: ApiClient.withDio(dio: dio, refreshDio: dio),
)..account = Account(id: 1, email: 'customer@example.test', role: 'Customer');

Map<String, dynamic> paidDetail({int reserved = 1, int used = 1}) {
  final p = fixtures.purchase(status: 'Paid');
  p['paidAt'] = DateTime.now()
      .subtract(const Duration(days: 2))
      .toIso8601String();
  p['expiresAt'] = DateTime.now()
      .add(const Duration(days: 28))
      .toIso8601String();
  (p['items'] as List)[0] = {
    'id': 11,
    'serviceId': 7,
    'serviceName': 'Chăm sóc da kiểm thử',
    'granted': 5,
    'reserved': reserved,
    'used': used,
    'remaining': 5 - used,
    'available': 5 - used - reserved,
  };
  return {
    'package': p,
    'history': [
      {
        'id': 1,
        'customerPackageItemId': 11,
        'appointmentId': 41,
        'quantity': 1,
        'status': 'Consumed',
        'createdAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'settledAt': DateTime.now()
            .subtract(const Duration(hours: 20))
            .toIso8601String(),
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'PKG01 PKG02 catalog confirms a purchase and opens pending detail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var posts = 0;
      final dio = fixtures.transport((r) {
        if (r.path == '/service-packages' && r.method == 'GET') {
          return [
            {
              'id': 2,
              'name': 'Gói chăm sóc 5 buổi',
              'price': 500000,
              'validityDays': 30,
              'active': true,
              'items': [
                {'serviceId': 7, 'sessions': 5},
              ],
            },
          ];
        }
        if (r.path == '/service-packages/mine') return [];
        if (r.path == '/service-packages/purchases' && r.method == 'POST') {
          expect(r.data, {'packageId': 2});
          posts++;
          return fixtures.purchase();
        }
        if (r.path == '/service-packages/purchases/3') {
          return {'package': fixtures.purchase(), 'history': []};
        }
        throw StateError('Unexpected request ${r.method} ${r.path}');
      });
      final auth = signedIn(dio);
      final packages = ServicePackageProvider(dio: dio)..bind(1);
      final catalog = CatalogProvider(dio: dio)..loaded = true;
      addTearDown(auth.dispose);
      addTearDown(packages.dispose);
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: packages),
            ChangeNotifierProvider.value(value: catalog),
          ],
          child: const MaterialApp(home: ServicePackagesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gói chăm sóc 5 buổi'), findsOneWidget);
      expect(find.text('Hạn dùng 30 ngày sau thanh toán'), findsOneWidget);
      await tester.tap(find.text('Đăng ký mua gói').first);
      await tester.pumpAndSettle();
      expect(posts, 0);
      expect(find.textContaining('chờ thanh toán'), findsWidgets);
      await tester.tap(find.text('Đăng ký mua').last);
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.byType(CustomerPackageDetailScreen), findsOneWidget);
      expect(find.text('Thanh toán chuyển khoản'), findsOneWidget);
      expect(packages.mine.single.status, 'Pending');
      expect(tester.takeException(), isNull);
    },
  );

  for (final exhausted in [false, true]) {
    testWidgets(
      'PKG06 PKG05 detail shows balance/history and ${exhausted ? "blocks" : "allows"} booking',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final dio = fixtures.transport((r) {
          expect(r.path, '/service-packages/purchases/3');
          return paidDetail(
            reserved: exhausted ? 0 : 1,
            used: exhausted ? 5 : 1,
          );
        });
        final auth = signedIn(dio),
            packages = ServicePackageProvider(dio: dio)..bind(1);
        addTearDown(auth.dispose);
        addTearDown(packages.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: packages),
            ],
            child: const MaterialApp(
              home: CustomerPackageDetailScreen(customerPackageId: 3),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            exhausted
                ? 'Còn lại: 0 · Có thể đặt: 0'
                : 'Còn lại: 4 · Có thể đặt: 3',
          ),
          findsOneWidget,
        );
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Đặt lịch sử dụng gói'),
        );
        expect(button.onPressed == null, exhausted);
        await tester.ensureVisible(find.text('Đã sử dụng'));
        expect(find.text('Đã sử dụng'), findsOneWidget);
        expect(find.textContaining('Lịch hẹn #41'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'BOOK01 selected service advances actual booking screen to time and staff',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dio = fixtures.transport((r) {
        expect(r.path, '/appointments/availability/days');
        expect(r.queryParameters['durationMinutes'], 60);
        return [];
      });
      final auth = signedIn(dio);
      final appointments = AppointmentProvider(dio: dio)..bind(1);
      final packages = ServicePackageProvider(dio: dio)..bind(1);
      final catalog = CatalogProvider(dio: dio)
        ..loaded = true
        ..services = [
          const Service(
            id: 7,
            categoryId: 1,
            name: 'Chăm sóc da kiểm thử',
            price: 100000,
            durationMinutes: 60,
          ),
        ];
      addTearDown(auth.dispose);
      addTearDown(appointments.dispose);
      addTearDown(packages.dispose);
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: appointments),
            ChangeNotifierProvider.value(value: packages),
            ChangeNotifierProvider.value(value: catalog),
          ],
          child: const MaterialApp(home: BookingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final next = find.widgetWithText(FilledButton, 'Tiếp tục');
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.tap(find.text('Chăm sóc da kiểm thử'));
      await tester.pump();
      expect(find.text('Tạm tính: 100.000 ₫'), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text('Bước 2/3 · Chọn thời gian & kỹ thuật viên'),
        findsOneWidget,
      );
      expect(find.text('Nhân viên thực hiện'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PKG04 paid package opens booking and caps quantities to available sessions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dio = fixtures.transport((r) {
        expect(r.path, '/service-packages/purchases/3');
        return paidDetail();
      });
      final auth = signedIn(dio);
      final packages = ServicePackageProvider(dio: dio)..bind(1);
      final appointments = AppointmentProvider(dio: dio)..bind(1);
      final catalog = CatalogProvider(dio: dio)
        ..loaded = true
        ..services = [
          const Service(
            id: 7,
            categoryId: 1,
            name: 'Chăm sóc da kiểm thử',
            price: 100000,
            durationMinutes: 60,
          ),
        ];
      addTearDown(auth.dispose);
      addTearDown(packages.dispose);
      addTearDown(catalog.dispose);
      addTearDown(appointments.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: packages),
            ChangeNotifierProvider.value(value: catalog),
            ChangeNotifierProvider.value(value: appointments),
          ],
          child: const MaterialApp(
            home: CustomerPackageDetailScreen(customerPackageId: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lịch sử dụng gói'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);
      expect(find.textContaining('không áp dụng thêm voucher'), findsOneWidget);
      expect(find.text('Còn 4/5 lượt · Có thể đặt 3'), findsOneWidget);
      final add = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Tăng số lượt',
      );
      await tester.ensureVisible(add);
      for (var i = 0; i < 3; i++) {
        await tester.tap(add);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<IconButton>(add).onPressed, isNull);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Thời lượng lần hẹn: 3 giờ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'USER02 profile avatar action picks gallery image and sends own multipart',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final originalPicker = ImagePickerPlatform.instance;
      final picker = GalleryFixture();
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = originalPicker);
      var uploads = 0;
      final dio = fixtures.transport((r) {
        expect(r.path, '/customers/me/avatar');
        expect(r.method, 'POST');
        final file = (r.data as FormData).files.single;
        expect(file.key, 'File');
        expect(file.value.contentType.toString(), 'image/png');
        expect(file.value.length, avatars.png.length);
        uploads++;
        return avatars.profile();
      });
      final auth = signedIn(dio), profile = ProfileProvider(dio: dio)..bind(1);
      addTearDown(auth.dispose);
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: profile),
          ],
          child: const MaterialApp(
            home: EditProfileScreen(
              customer: Customer(id: 1, fullName: 'Customer', rewardPoints: 42),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Đổi ảnh đại diện'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(picker.selections, 1);
      expect(uploads, 1);
      expect(profile.customer!.avatarUrl, 'https://example.test/avatar.png');
      expect(find.text('Đã cập nhật ảnh đại diện'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('USER03 gallery selection rejects invalid image before upload', (
    tester,
  ) async {
    final originalPicker = ImagePickerPlatform.instance;
    final picker = GalleryFixture(bytes: [1, 2, 3]);
    ImagePickerPlatform.instance = picker;
    addTearDown(() => ImagePickerPlatform.instance = originalPicker);
    var uploads = 0;
    final dio = fixtures.transport((_) {
      uploads++;
      return avatars.profile();
    });
    final auth = signedIn(dio), profile = ProfileProvider(dio: dio)..bind(1);
    addTearDown(auth.dispose);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: profile),
        ],
        child: const MaterialApp(
          home: EditProfileScreen(
            customer: Customer(id: 1, fullName: 'Customer', rewardPoints: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Đổi ảnh đại diện'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(picker.selections, 1);
    expect(uploads, 0);
    expect(find.text('Vui lòng chọn ảnh JPG, PNG hoặc WebP.'), findsOneWidget);
    expect(profile.customer, isNull);
    expect(profile.avatarSaving, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'USER07 completed appointment submits review and shows success outcome',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var submissions = 0;
      final dio = fixtures.transport((r) {
        if (r.path == '/reviews/appointments/41') {
          expect(r.method, 'POST');
          expect(r.data, {'stars': 5, 'comment': 'Dịch vụ rất tốt'});
          submissions++;
          return {};
        }
        if ([
          '/service-categories',
          '/services',
          '/combos',
          '/promotions',
        ].contains(r.path)) {
          return [];
        }
        throw StateError('Unexpected request ${r.method} ${r.path}');
      });
      final auth = signedIn(dio);
      final appointments = AppointmentProvider(dio: dio)
        ..bind(1)
        ..items = [
          Appointment(
            id: 41,
            customerId: 1,
            appointmentAt: DateTime.now().subtract(const Duration(days: 1)),
            status: 'HoanThanh',
            items: const [
              AppointmentItem(
                id: 1,
                serviceId: 7,
                serviceName: 'Chăm sóc da kiểm thử',
                expectedPrice: 100000,
              ),
            ],
          ),
        ];
      final catalog = CatalogProvider(dio: dio)..loaded = true;
      addTearDown(auth.dispose);
      addTearDown(appointments.dispose);
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: appointments),
            ChangeNotifierProvider.value(value: catalog),
          ],
          child: const MaterialApp(home: Scaffold(body: AppointmentsScreen())),
        ),
      );
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết vé'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đánh giá dịch vụ'));
      await tester.tap(find.text('Đánh giá dịch vụ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Dịch vụ rất tốt');
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(submissions, 1);
      expect(appointments.items.single.hasReviewed, true);
      expect(appointments.items.single.reviewStars, 5);
      expect(appointments.items.single.reviewComment, 'Dịch vụ rất tốt');
      expect(
        find.text('Cảm ơn bạn đã gửi đánh giá dịch vụ! ⭐'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'USER01 profile form saves valid edited name and phone through own endpoint',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      final dio = fixtures.transport((r) {
        expect(r.method, 'PUT');
        expect(r.path, '/customers/me');
        expect(r.data, {
          'fullName': 'Khách hàng kiểm thử',
          'phone': '0901234567',
          'gender': 'Nữ',
        });
        calls++;
        return {
          'id': 1,
          'fullName': 'Khách hàng kiểm thử',
          'phone': '0901234567',
          'gender': 'Nữ',
          'rewardPoints': 42,
        };
      });
      final auth = signedIn(dio), profile = ProfileProvider(dio: dio)..bind(1);
      addTearDown(auth.dispose);
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: profile),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(c).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(
                        customer: Customer(
                          id: 1,
                          fullName: 'Tên cũ',
                          phone: '0901234567',
                          gender: 'Nữ',
                          rewardPoints: 42,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Mở hồ sơ'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở hồ sơ'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Khách hàng kiểm thử',
      );
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(profile.customer!.fullName, 'Khách hàng kiểm thử');
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'USER04 notification screen loads own list and applies unread filter',
    (tester) async {
      final requests = <bool>[];
      final dio = fixtures.transport((r) {
        if (r.path == '/notifications/unread-count') return {'unreadCount': 1};
        if (r.path == '/notifications') {
          requests.add(r.queryParameters['unreadOnly'] == true);
          return {
            'items': [
              {
                'id': 1,
                'title': 'Thông báo kiểm thử',
                'body': 'Lịch hẹn đã xác nhận',
                'type': 'HeThong',
                'isRead': false,
                'createdAt': DateTime.now().toIso8601String(),
              },
            ],
            'totalCount': 1,
            'unreadCount': 1,
          };
        }
        throw StateError('Unexpected request ${r.path}');
      });
      final auth = signedIn(dio),
          notifications = NotificationProvider(dio: dio)..bind(1);
      addTearDown(auth.dispose);
      addTearDown(notifications.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: notifications),
          ],
          child: const MaterialApp(home: NotificationScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thông báo kiểm thử'), findsOneWidget);
      await tester.tap(find.text('Chưa đọc (1)'));
      await tester.pumpAndSettle();
      expect(requests, [false, true]);
      expect(find.text('Thông báo kiểm thử'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'USER05 branch screen presents configured address and copy action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: BranchScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(SpaLocation.address), findsOneWidget);
      await tester.ensureVisible(find.text('Sao chép địa chỉ'));
      await tester.tap(find.text('Sao chép địa chỉ'));
      await tester.pump();
      expect(copied, SpaLocation.address);
      expect(find.text('Đã sao chép địa chỉ'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
