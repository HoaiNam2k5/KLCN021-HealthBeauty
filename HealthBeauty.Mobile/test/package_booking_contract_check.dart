import 'dart:io';

import 'package:app_doancunhan/core/package_booking.dart';
import 'package:app_doancunhan/models/service_package.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/models/booking_contract.dart';

CustomerServicePackage owned({
  String status = 'Paid',
  int available = 3,
  String expiry = '2099-01-01T12:00:00',
}) => CustomerServicePackage.fromJson({
  'id': 3,
  'servicePackageId': 2,
  'customerId': 9,
  'name': 'Fixture package',
  'price': 500000,
  'validityDays': 30,
  'status': status,
  'createdAt': '2026-10-24T10:00:00',
  'expiresAt': expiry,
  'items': [
    {
      'id': 11,
      'serviceId': 7,
      'serviceName': 'Fixture service',
      'granted': 50,
      'used': 1,
      'reserved': 49 - available,
      'remaining': 49,
      'available': available,
    },
  ],
});
const services = [
  Service(
    id: 7,
    categoryId: 1,
    name: 'Fixture service',
    price: 100000,
    durationMinutes: 60,
  ),
];
List<Map<String, dynamic>> lines({
  CustomerServicePackage? package,
  Map<int, int> quantities = const {7: 1},
  List<Service> catalog = services,
  DateTime? date,
}) => buildPackageBookingLines(
  package: package ?? owned(),
  quantities: quantities,
  services: catalog,
  appointmentAt: date,
);
void check(bool value, String description) {
  if (!value) throw StateError(description);
}

void rejects(void Function() action) {
  try {
    action();
  } on FormatException {
    return;
  }
  throw StateError('Expected rejection');
}

void main() {
  final checks = <void Function()>[
    () {
      final value = lines(quantities: {7: 2});
      check(
        value.length == 2 &&
            value.every(
              (x) =>
                  x['serviceId'] == 7 &&
                  x['comboId'] == null &&
                  x['expectedPrice'] == 0,
            ),
        'Repeated service consumes requested quantity at zero cash price',
      );
    },
    () => check(
      bookingDurationMinutes(lines(quantities: {7: 2}), services) == 120,
      'Full service quantity duration',
    ),
    () => rejects(() => lines(package: owned(status: 'Pending', available: 0))),
    () =>
        rejects(() => lines(package: owned(status: 'Cancelled', available: 0))),
    () => rejects(() => lines(package: owned(expiry: '2000-01-01T12:00:00'))),
    () => rejects(() => lines(date: DateTime(2099, 1, 1, 12, 1))),
    () => check(
      lines(date: DateTime(2099, 1, 1, 12)).length == 1,
      'Expiry boundary follows server appointment-start rule',
    ),
    () => rejects(() => lines(quantities: {7: 4})),
    () => rejects(() => lines(quantities: {99: 1})),
    () => rejects(() => lines(catalog: [])),
    () => rejects(() => lines(quantities: {})),
    () => rejects(() => lines(quantities: {7: 0})),
    () => rejects(
      () => lines(package: owned(available: 49), quantities: {7: 25}),
    ),
  ];
  for (final test in checks) {
    test();
  }
  stdout.writeln(
    'PACKAGE_BOOKING_CONTRACT: ${checks.length}/${checks.length} PASS',
  );
}
