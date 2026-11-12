import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/widgets/customer_avatar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('picker excludes reception, stale titles and inactive staff', () async {
    final dio = Dio();
    final rows = [
      {'nhanVienId': 1, 'hoTen': 'Reception', 'chucVu': 'Reception'},
      {'nhanVienId': 2, 'hoTen': 'Manager', 'chucVu': 'KTV', 'role': 'Manager'},
      {
        'nhanVienId': 3,
        'hoTen': 'Inactive',
        'role': 'Staff',
        'isActive': false,
      },
      {
        'nhanVienId': 4,
        'hoTen': 'Real technician',
        'chucVu': 'Senior',
        'role': 'Staff',
        'isActive': true,
        'avatarUrl': 'https://example.com/4.png',
      },
      {
        'nhanVienId': 5,
        'hoTen': 'Legacy technician',
        'chucVu': ' Kỹ thuật viên ',
      },
      {'nhanVienId': 6, 'hoTen': 'Unknown'},
    ];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          h.resolve(
            Response(
              requestOptions: r,
              statusCode: 200,
              data: r.path == '/staff' ? rows : [],
            ),
          );
        },
      ),
    );
    final provider = CatalogProvider(dio: dio);
    addTearDown(provider.dispose);
    provider.bind(1);
    await provider.loadStaff();
    expect(provider.staffList.map((s) => s.id), [4, 5]);
    expect(provider.staffById(4)?.avatarUrl, 'https://example.com/4.png');
    expect(provider.staffById(1), isNull);
  });

  test('account role overrides an outdated position', () {
    expect(
      const Staff(
        id: 1,
        fullName: 'A',
        role: 'Staff',
        position: 'Reception',
      ).isTechnician,
      isTrue,
    );
    expect(
      const Staff(
        id: 2,
        fullName: 'B',
        role: 'Reception',
        position: 'Staff',
      ).isTechnician,
      isFalse,
    );
    expect(
      const Staff(id: 3, fullName: 'C', position: 'Therapist').isTechnician,
      isTrue,
    );
  });

  testWidgets('invalid or missing portrait safely shows initials', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerAvatar(
            url: 'javascript:invalid',
            initial: 'N',
            radius: 24,
          ),
        ),
      ),
    );
    expect(find.text('N'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
