import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';

Appointment booking(int id, DateTime at, [String status = 'DaXacNhan']) =>
    Appointment(
      id: id,
      customerId: 1,
      appointmentAt: at,
      status: status,
      items: const [],
    );

void main() {
  final today = DateTime(2026, 10, 26, 14);

  for (final status in ['ChoXacNhan', 'DaXacNhan', 'DaDen', 'DangThucHien']) {
    test('past-day $status is history without changing business status', () {
      final appointment = booking(1, DateTime(2026, 10, 25, 18), status);
      expect(appointment.isUpcomingAt(today), false);
      expect(appointment.status, status);
      expect(appointment.isDone, false);
      expect(appointment.isCancelled, false);
      expect(appointment.invoiceId, isNull);
    });
  }

  test(
    'today stays active even after start time, tomorrow remains upcoming',
    () {
      expect(booking(1, DateTime(2026, 10, 26, 9)).isUpcomingAt(today), true);
      expect(
        booking(
          2,
          DateTime(2026, 10, 26, 9),
          'DangThucHien',
        ).isUpcomingAt(today),
        true,
      );
      expect(booking(3, DateTime(2026, 10, 27, 9)).isUpcomingAt(today), true);
    },
  );

  test(
    'completed and cancelled remain history regardless of scheduled date',
    () {
      for (final status in ['HoanThanh', 'DaHuy']) {
        expect(
          booking(1, DateTime(2026, 10, 27), status).isUpcomingAt(today),
          false,
        );
      }
    },
  );

  test(
    'home and appointment lists share complete disjoint ordered partitions',
    () {
      final provider = AppointmentProvider(dio: Dio(), now: () => today);
      addTearDown(provider.dispose);
      provider.items = [
        booking(1, DateTime(2026, 10, 24)),
        booking(2, DateTime(2026, 10, 27)),
        booking(3, DateTime(2026, 10, 25)),
        booking(4, DateTime(2026, 10, 26, 17)),
        booking(5, DateTime(2026, 10, 26, 8), 'HoanThanh'),
      ];
      expect(provider.upcoming.map((a) => a.id), [4, 2]);
      expect(provider.history.map((a) => a.id), [5, 3, 1]);
      expect(
        {...provider.upcoming, ...provider.history}.length,
        provider.items.length,
      );
    },
  );

  test(
    'crossing midnight reclassifies cached data without a backend write',
    () {
      var clock = DateTime(2026, 10, 26, 23, 59, 59);
      final provider = AppointmentProvider(dio: Dio(), now: () => clock);
      addTearDown(provider.dispose);
      provider.items = [booking(1, DateTime(2026, 10, 26, 18))];
      expect(provider.upcoming.single.id, 1);
      clock = DateTime(2026, 10, 27);
      expect(provider.upcoming, isEmpty);
      expect(provider.history.single.id, 1);
      expect(provider.items.single.status, 'DaXacNhan');
    },
  );

  test('UTC and equivalent local timestamps use the same calendar day', () {
    final local = DateTime(2026, 10, 25, 18);
    expect(
      booking(1, local).isPastDateAt(today),
      booking(1, local.toUtc()).isPastDateAt(today.toUtc()),
    );
  });
}
