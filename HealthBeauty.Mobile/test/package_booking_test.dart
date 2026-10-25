import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/core/package_booking.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/models/service_package.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';

CustomerServicePackage owned({int available = 2}) =>
    CustomerServicePackage.fromJson({
      'id': 3,
      'servicePackageId': 2,
      'customerId': 9,
      'name': 'Package',
      'price': 500000,
      'validityDays': 30,
      'status': 'Paid',
      'createdAt': '2026-10-24T10:00:00',
      'expiresAt': '2099-01-01T12:00:00',
      'items': [
        {
          'id': 11,
          'serviceId': 7,
          'serviceName': 'Care',
          'granted': 5,
          'reserved': 4 - available,
          'used': 1,
          'remaining': 4,
          'available': available,
        },
      ],
    });
const services = [
  Service(
    id: 7,
    categoryId: 1,
    name: 'Care',
    price: 100000,
    durationMinutes: 60,
  ),
];

void main() {
  test('package booking is limited by available, not remaining sessions', () {
    expect(owned().items.single.remaining, 4);
    expect(
      () => buildPackageBookingLines(
        package: owned(),
        quantities: {7: 3},
        services: services,
      ),
      throwsFormatException,
    );
    final rows = buildPackageBookingLines(
      package: owned(),
      quantities: {7: 2},
      services: services,
    );
    expect(rows.length, 2);
    expect(
      rows.every((x) => x['expectedPrice'] == 0 && x['comboId'] == null),
      true,
    );
  });
  test('appointment provider submits customerPackageId and no customer or payment claims', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.path, '/appointments');
          expect(request.data['customerPackageId'], 3);
          expect(request.data.containsKey('customerId'), false);
          expect(request.data.containsKey('paid'), false);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 201,
              data: {
                'id': 10,
                'customerId': 9,
                'staffId': 2,
                'appointmentAt': '2098-01-01T09:00:00',
                'status': 'ChoXacNhan',
                'customerPackageId': 3,
                'items': [],
              },
            ),
          );
        },
      ),
    );
    final provider = AppointmentProvider(dio: dio)..bind(1);
    addTearDown(provider.dispose);
    final result = await provider.create(
      at: DateTime(2098, 1, 1, 9),
      staffId: 2,
      customerPackageId: 3,
      lines: buildPackageBookingLines(
        package: owned(),
        quantities: {7: 1},
        services: services,
      ),
    );
    expect(result?.customerPackageId, 3);
    expect(result?.copyWith(status: 'DaHuy').customerPackageId, 3);
  });
  test('legacy cash appointments still parse without a package', () {
    final value = Appointment.fromJson({
      'id': 1,
      'customerId': 9,
      'appointmentAt': '2098-01-01T09:00:00',
      'status': 'ChoXacNhan',
      'items': [],
    });
    expect(value.customerPackageId, null);
  });
}
