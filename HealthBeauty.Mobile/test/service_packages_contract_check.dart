import 'dart:io';

import 'package:app_doancunhan/models/service_package.dart';

Map<String, dynamic> balance({
  int used = 1,
  int reserved = 1,
  int available = 3,
}) => {
  'id': 11,
  'serviceId': 7,
  'serviceName': 'Chăm sóc da',
  'granted': 5,
  'used': used,
  'reserved': reserved,
  'remaining': 5 - used,
  'available': available,
};
Map<String, dynamic> purchase({
  String status = 'Paid',
  String? expiry = '2099-01-01T12:00:00',
  int available = 3,
}) => {
  'id': 3,
  'servicePackageId': 2,
  'customerId': 9,
  'name': 'Gói chăm sóc',
  'price': 500000,
  'validityDays': 30,
  'status': status,
  'createdAt': '2026-10-24T10:00:00',
  'paidAt': status == 'Paid' ? '2026-10-24T11:00:00' : null,
  'expiresAt': expiry,
  'paymentMethod': null,
  'items': [balance(available: available)],
};
void check(bool value, String description) {
  if (!value) throw StateError(description);
}

void main() {
  final checks = <void Function()>[
    () {
      final p = CustomerServicePackage.fromJson(purchase());
      check(
        p.items.single.remaining == 4 &&
            p.items.single.available == 3 &&
            p.items.single.reserved == 1,
        'Remaining differs from available',
      );
    },
    () {
      final p = CustomerServicePackage.fromJson(purchase());
      check(p.canUseAt(DateTime(2098)), 'Paid valid package usable');
    },
    () {
      final p = CustomerServicePackage.fromJson(
        purchase(status: 'Pending', expiry: null, available: 0),
      );
      check(
        !p.canUseAt(DateTime.now()) && p.statusLabel == 'Chờ thanh toán',
        'Pending never usable',
      );
    },
    () {
      check(
        !CustomerServicePackage.fromJson(
          purchase(expiry: '2020-01-01T12:00:00', available: 0),
        ).canUseAt(DateTime.now()),
        'Expired never usable',
      );
    },
    () {
      check(
        !CustomerServicePackage.fromJson(purchase())
            .canUseAt(DateTime(2099, 1, 1, 12, 0, 1)),
        'Appointment after expiry rejected',
      );
    },
    () {
      check(
        !CustomerServicePackage.fromJson(
          purchase(status: 'Cancelled', available: 0),
        ).canUseAt(DateTime.now()),
        'Cancelled never usable',
      );
    },
    () {
      check(
        !CustomerServicePackage.fromJson(purchase(available: 0))
            .canUseAt(DateTime.now()),
        'No available sessions cannot book',
      );
    },
    () {
      final p = CustomerServicePackage.fromJson(purchase());
      check(
        p.service(7)?.serviceName == 'Chăm sóc da' && p.service(99) == null,
        'Covered services lookup',
      );
    },
    () {
      final p = ServicePackageOffer.fromJson({
        'id': 2,
        'name': 'Gói',
        'price': 500000,
        'validityDays': 30,
        'active': true,
        'imageUrl': ' https://example.test/a.png ',
        'items': [
          {'serviceId': 7, 'sessions': 5},
        ],
      });
      check(
        p.items.single.sessions == 5 &&
            p.imageUrl == 'https://example.test/a.png',
        'Catalog contract',
      );
    },
    () {
      var rejected = false;
      try {
        PackageSessionBalance.fromJson(balance(available: 4));
      } on FormatException {
        rejected = true;
      }
      check(rejected, 'Overspending balance rejected');
    },
    () {
      final detail = CustomerPackageDetail.fromJson({
        'package': purchase(),
        'history': [
          {
            'id': 1,
            'customerPackageItemId': 11,
            'appointmentId': 8,
            'quantity': 1,
            'status': 'Reserved',
            'createdAt': '2026-10-24T12:00:00',
            'settledAt': null,
          },
        ],
      });
      check(
        detail.history.single.statusLabel == 'Đang giữ lượt' &&
            detail.package.id == 3,
        'Detail/history contract',
      );
    },
    () {
      final p = CustomerServicePackage.fromJson(purchase());
      check(
        p.expiresAt!.hour == 12 && !p.expiresAt!.isUtc,
        'Local wall-clock expiry retained',
      );
    },
  ];
  for (final test in checks) {
    test();
  }
  stdout.writeln(
    'SERVICE_PACKAGES_CONTRACT: ${checks.length}/${checks.length} PASS',
  );
}
