import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/availability_day.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';

Dio fakeDio(FutureOr<dynamic> Function(RequestOptions) reply) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) async {
        handler.resolve(
          Response(
            requestOptions: request,
            data: await reply(request),
            statusCode: 200,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  test(
    'range request uses local dates, selected employee and full duration',
    () async {
      final provider = AppointmentProvider(
        dio: fakeDio((request) {
          expect(request.path, '/appointments/availability/days');
          expect(request.queryParameters, {
            'from': '2030-01-01',
            'to': '2030-03-02',
            'staffId': 2,
            'durationMinutes': 150,
          });
          return [
            {
              'date': '2030-01-03',
              'startTimes': ['10:30:00', '09:00:00', '10:30:00'],
            },
          ];
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      final days = await provider.availableDays(
        from: DateTime(2030, 1, 1),
        to: DateTime(2030, 3, 2),
        staffId: 2,
        durationMinutes: 150,
      );
      expect(days.single.starts, [
        DateTime(2030, 1, 3, 9),
        DateTime(2030, 1, 3, 10, 30),
      ]);
    },
  );

  test(
    'any employee omits staffId and excessive range never calls API',
    () async {
      var calls = 0;
      final provider = AppointmentProvider(
        dio: fakeDio((request) {
          calls++;
          expect(request.queryParameters.containsKey('staffId'), false);
          return [];
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.availableDays(
        from: DateTime(2030, 1, 1),
        to: DateTime(2030, 1, 1),
        durationMinutes: 60,
      );
      await expectLater(
        provider.availableDays(
          from: DateTime(2030, 1, 1),
          to: DateTime(2030, 3, 3),
          durationMinutes: 60,
        ),
        throwsFormatException,
      );
      expect(calls, 1);
    },
  );

  test('old range result is discarded after account change', () async {
    final reply = Completer<dynamic>();
    final provider = AppointmentProvider(dio: fakeDio((_) => reply.future))
      ..bind(1);
    addTearDown(provider.dispose);
    final pending = provider.availableDays(
      from: DateTime(2030, 1, 1),
      to: DateTime(2030, 1, 2),
      durationMinutes: 60,
    );
    await Future<void>.delayed(Duration.zero);
    provider.bind(2);
    reply.complete([
      {
        'date': '2030-01-01',
        'startTimes': ['09:00:00'],
      },
    ]);
    expect(await pending, isEmpty);
  });

  test('nearest available time skips conflicts, expired times and invalid combo days', () {
    final days = [
      AvailableAppointmentDay.fromJson({
        'date': '2030-01-03',
        'startTimes': ['09:00:00'],
      }),
      AvailableAppointmentDay.fromJson({
        'date': '2030-01-02',
        'startTimes': ['09:00:00', '10:00:00'],
      }),
      AvailableAppointmentDay.fromJson({
        'date': '2030-01-01',
        'startTimes': ['09:00:00'],
      }),
    ];
    final starts = bookableAvailabilityStarts(
      days,
      now: DateTime(2030, 1, 1, 12),
      canBookDate: (day) => day.day < 3,
      hasConflict: (start) => start.day == 2 && start.hour == 9,
    );
    expect(starts, [DateTime(2030, 1, 2, 10)]);
  });

  test('malformed dates and times cannot create marked dates', () {
    expect(
      () => AvailableAppointmentDay.fromJson({
        'date': '2030-02-30',
        'startTimes': [],
      }),
      throwsFormatException,
    );
    expect(
      () => AvailableAppointmentDay.fromJson({
        'date': '2030-01-01',
        'startTimes': ['24:00:00'],
      }),
      throwsFormatException,
    );
    expect(
      bookableAvailabilityStarts(
        [],
        now: DateTime(2030),
        canBookDate: (_) => true,
        hasConflict: (_) => false,
      ),
      isEmpty,
    );
  });
}
