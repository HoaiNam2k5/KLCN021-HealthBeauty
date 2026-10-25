import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/models/booking_contract.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';

const services = [
  Service(
    id: 1,
    categoryId: 1,
    name: 'First',
    price: 100000,
    durationMinutes: 60,
  ),
  Service(
    id: 2,
    categoryId: 1,
    name: 'Second',
    price: 200000,
    durationMinutes: 30,
  ),
];
const combo = Combo(
  id: 7,
  name: 'Package',
  price: 250000,
  active: true,
  items: [
    ComboItem(serviceId: 1, serviceName: 'First', quantity: 2),
    ComboItem(serviceId: 2, serviceName: 'Second', quantity: 1),
  ],
);

Map<String, dynamic> appointmentJson(
  int id, {
  int customerId = 1,
  String status = 'DaXacNhan',
  String? at,
  int duration = 60,
}) => {
  'id': id,
  'customerId': customerId,
  'staffId': 1,
  'appointmentAt': at ?? '2026-10-16T14:30:00',
  'status': status,
  'note': null,
  'items': [
    {
      'id': id,
      'serviceId': 1,
      'serviceName': 'First',
      'comboId': null,
      'expectedPrice': 100000,
      'durationMinutes': duration,
    },
  ],
};

Dio fakeDio(FutureOr<dynamic> Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final data = await respond(options);
          if (data is Error) throw data;
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        } catch (exception) {
          handler.reject(
            DioException(requestOptions: options, error: exception),
          );
        }
      },
    ),
  );
  return dio;
}

void main() {
  test('combo expands every component quantity without a voucher discount', () {
    final lines = buildBookingLines(
      services: [services[1]],
      combos: [combo],
      catalogServices: services,
    );
    expect(lines.map((line) => [line['serviceId'], line['comboId']]), [
      [2, null],
      [1, 7],
      [1, 7],
      [2, 7],
    ]);
    expect(lines.first['expectedPrice'], 200000);
    expect(bookingDurationMinutes(lines, services), 180);
  });

  test('missing combo component is rejected before booking', () {
    expect(
      () => buildBookingLines(
        services: [],
        combos: [combo],
        catalogServices: [services[0]],
      ),
      throwsFormatException,
    );
  });

  test('inactive and expired-on-appointment-date combos are rejected', () {
    final inactive = Combo(
      id: 1,
      name: 'Inactive',
      price: 1,
      active: false,
      items: combo.items,
    );
    expect(
      () => buildBookingLines(
        services: [],
        combos: [inactive],
        catalogServices: services,
      ),
      throwsFormatException,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ending = Combo(
      id: 1,
      name: 'Ending',
      price: 1,
      active: true,
      validTo: today.add(const Duration(days: 1)),
      items: combo.items,
    );
    expect(
      () => buildBookingLines(
        services: [],
        combos: [ending],
        catalogServices: services,
        appointmentDate: today.add(const Duration(days: 2)),
      ),
      throwsFormatException,
    );
  });

  test('invalid component quantities and empty selections are rejected', () {
    const invalid = Combo(
      id: 1,
      name: 'Invalid',
      price: 1,
      active: true,
      items: [ComboItem(serviceId: 1, serviceName: 'First', quantity: 0)],
    );
    expect(
      () => buildBookingLines(
        services: [],
        combos: [invalid],
        catalogServices: services,
      ),
      throwsFormatException,
    );
    expect(
      () => buildBookingLines(
        services: [],
        combos: [],
        catalogServices: services,
      ),
      throwsFormatException,
    );
  });

  test('local time stays local without a UTC suffix', () {
    expect(
      localBookingDateTime(DateTime(2026, 10, 16, 14, 30)),
      '2026-10-16T14:30:00',
    );
  });

  test('availability uses actual staff and TimeOnly fields', () {
    final slot = AvailableAppointmentSlot.fromJson({
      'nhanVienId': 2,
      'gioBatDau': '09:30:00',
      'gioKetThuc': '12:00:00',
    }, DateTime(2026, 10, 16));
    expect(slot.staffId, 2);
    expect(slot.start, DateTime(2026, 10, 16, 9, 30));
    expect(slot.end.difference(slot.start).inMinutes, 150);
    expect(
      () => AvailableAppointmentSlot.fromJson({
        'nhanVienId': 2,
        'gioBatDau': '25:30:00',
        'gioKetThuc': '12:00:00',
      }, DateTime(2026, 10, 16)),
      throwsFormatException,
    );
  });

  test('appointment durations and lifecycle match backend rules', () {
    final arrived = Appointment.fromJson(
      appointmentJson(1, status: 'DaDen', duration: 90),
    );
    expect(arrived.durationMinutes, 90);
    expect(arrived.canCancel, true);
    expect(arrived.canReschedule, false);
    for (final status in ['DangThucHien', 'HoanThanh', 'DaHuy']) {
      final item = Appointment.fromJson(appointmentJson(1, status: status));
      expect(item.canCancel, false);
      expect(item.canReschedule, false);
    }
  });

  test('conflicts use full intervals including previous-day bookings', () {
    final provider = AppointmentProvider(dio: fakeDio((_) => null))..bind(1);
    addTearDown(provider.dispose);
    provider.items = [
      Appointment.fromJson(
        appointmentJson(1, at: '2026-10-15T23:30:00', duration: 90),
      ),
    ];
    expect(provider.hasConflictAt(DateTime(2026, 10, 16, 0, 15)), true);
    expect(provider.hasConflictAt(DateTime(2026, 10, 16, 1)), false);
    expect(
      provider.hasConflictAt(DateTime(2026, 10, 15, 23), durationMinutes: 60),
      true,
    );
    provider.items = [provider.items.first.copyWith(status: 'DaHuy')];
    expect(provider.hasConflictAt(DateTime(2026, 10, 16, 0, 15)), false);
  });

  test('loads every appointment page beyond the first 100 rows', () async {
    final pages = <int>[];
    final provider = AppointmentProvider(
      dio: fakeDio((request) {
        final page = request.queryParameters['page'] as int;
        pages.add(page);
        return {
          'items': List.generate(
            page == 1 ? 100 : 2,
            (index) => appointmentJson((page - 1) * 100 + index + 1),
          ),
          'totalCount': 102,
        };
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    await provider.load();
    expect(pages, [1, 2]);
    expect(provider.items.length, 102);
    expect(provider.error, null);
    expect(provider.loading, false);
  });

  test(
    'availability request sends local date and entire booking duration',
    () async {
      final provider = AppointmentProvider(
        dio: fakeDio((request) {
          expect(request.path, '/appointments/availability');
          expect(request.queryParameters, {
            'date': '2026-10-16',
            'staffId': 2,
            'durationMinutes': 150,
          });
          return [
            {
              'nhanVienId': 2,
              'gioBatDau': '09:30:00',
              'gioKetThuc': '12:00:00',
            },
          ];
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      final slots = await provider.availableSlots(
        date: DateTime(2026, 10, 16),
        staffId: 2,
        durationMinutes: 150,
      );
      expect(slots.single.start.hour, 9);
    },
  );

  test('old account load response cannot overwrite new account data', () async {
    final oldResponse = Completer<dynamic>();
    var requests = 0;
    final provider = AppointmentProvider(
      dio: fakeDio(
        (_) => ++requests == 1
            ? oldResponse.future
            : {
                'items': [appointmentJson(2, customerId: 2)],
                'totalCount': 1,
              },
      ),
    )..bind(1);
    addTearDown(provider.dispose);
    final oldLoad = provider.load();
    await Future<void>.delayed(Duration.zero);
    provider.bind(2);
    await provider.load();
    oldResponse.complete({
      'items': [appointmentJson(1)],
      'totalCount': 1,
    });
    await oldLoad;
    expect(provider.items.single.customerId, 2);
    expect(provider.loading, false);
    expect(provider.error, null);
  });

  test(
    'old load error cannot clear new account loading flag or set its error',
    () async {
      final oldResponse = Completer<dynamic>();
      final newResponse = Completer<dynamic>();
      var requests = 0;
      final provider = AppointmentProvider(
        dio: fakeDio(
          (_) => ++requests == 1 ? oldResponse.future : newResponse.future,
        ),
      )..bind(1);
      addTearDown(provider.dispose);
      final oldLoad = provider.load();
      await Future<void>.delayed(Duration.zero);
      provider.bind(2);
      final newLoad = provider.load();
      await Future<void>.delayed(Duration.zero);
      oldResponse.complete(StateError('old account failed'));
      await oldLoad;
      expect(provider.loading, true);
      expect(provider.error, null);
      newResponse.complete({
        'items': [appointmentJson(2, customerId: 2)],
        'totalCount': 1,
      });
      await newLoad;
      expect(provider.items.single.customerId, 2);
    },
  );

  test(
    'old create response cannot enter new account cache or clear submitting',
    () async {
      final oldResponse = Completer<dynamic>();
      final newResponse = Completer<dynamic>();
      var requests = 0;
      final provider = AppointmentProvider(
        dio: fakeDio((request) {
          expect((request.data as Map)['appointmentAt'], '2026-10-16T14:30:00');
          return ++requests == 1 ? oldResponse.future : newResponse.future;
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      final oldCreate = provider.create(
        at: DateTime(2026, 10, 16, 14, 30),
        lines: [],
      );
      await Future<void>.delayed(Duration.zero);
      provider.bind(2);
      final newCreate = provider.create(
        at: DateTime(2026, 10, 16, 14, 30),
        lines: [],
      );
      await Future<void>.delayed(Duration.zero);
      oldResponse.complete(appointmentJson(1));
      expect(await oldCreate, null);
      expect(provider.items, isEmpty);
      expect(provider.submitting, true);
      newResponse.complete(appointmentJson(2, customerId: 2));
      expect((await newCreate)!.customerId, 2);
      expect(provider.items.single.customerId, 2);
    },
  );

  test(
    'old cancel response does not mutate same ID in another account',
    () async {
      final response = Completer<dynamic>();
      final provider = AppointmentProvider(dio: fakeDio((_) => response.future))
        ..bind(1);
      addTearDown(provider.dispose);
      provider.items = [Appointment.fromJson(appointmentJson(1))];
      final cancelling = provider.cancel(1);
      await Future<void>.delayed(Duration.zero);
      provider.bind(2);
      provider.items = [
        Appointment.fromJson(appointmentJson(1, customerId: 2)),
      ];
      response.complete(null);
      expect(await cancelling, false);
      expect(provider.items.single.status, 'DaXacNhan');
      expect(provider.error, null);
    },
  );

  test('old availability response is discarded after account rebind', () async {
    final response = Completer<dynamic>();
    final provider = AppointmentProvider(dio: fakeDio((_) => response.future))
      ..bind(1);
    addTearDown(provider.dispose);
    final slots = provider.availableSlots(
      date: DateTime(2026, 10, 16),
      durationMinutes: 30,
    );
    await Future<void>.delayed(Duration.zero);
    provider.bind(2);
    response.complete([
      {'nhanVienId': 1, 'gioBatDau': '09:30:00', 'gioKetThuc': '10:00:00'},
    ]);
    expect(await slots, isEmpty);
  });

  test(
    'completed appointment cancellation is blocked without a request',
    () async {
      var requests = 0;
      final provider = AppointmentProvider(
        dio: fakeDio((_) {
          requests++;
          return null;
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      provider.items = [
        Appointment.fromJson(appointmentJson(1, status: 'HoanThanh')),
      ];
      expect(await provider.cancel(1), false);
      expect(requests, 0);
    },
  );

  test(
    'reschedule sends the existing note and replaces cached appointment',
    () async {
      late RequestOptions captured;
      final provider = AppointmentProvider(
        dio: fakeDio((request) {
          captured = request;
          return {
            'customerPackageId': null,
            'fundingSource': 'Cash',
            'lichHenId': 1,
            'khachHangId': 1,
            'nhanVienId': 2,
            'ngayGioHen': '2026-11-20T09:30:00',
            'trangThai': 'DaXacNhan',
            'ghiChu': '[Nhắc hẹn: 30 phút trước] Giữ nguyên ghi chú',
            'chitietlichhens': [
              {
                'chiTietLichHenId': 1,
                'lichHenId': 1,
                'dichVuId': 1,
                'comboId': null,
                'giaDuKien': 100000,
                'durationMinutes': 60,
                'dichVu': {
                  'dichVuId': 1,
                  'tenDichVu': 'First',
                  'gia': 100000,
                  'thoiLuongPhut': 60,
                },
              },
            ],
          };
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      provider.items = [
        Appointment.fromJson({
          ...appointmentJson(1),
          'note': '[Nhắc hẹn: 30 phút trước] Giữ nguyên ghi chú',
        }),
      ];

      final updated = await provider.reschedule(
        id: 1,
        at: DateTime(2026, 11, 20, 9, 30),
        staffId: 2,
        note: provider.items.single.note,
      );

      expect(captured.method, 'POST');
      expect(captured.path, '/appointments/1/reschedule');
      expect(captured.data, {
        'appointmentAt': '2026-11-20T09:30:00',
        'staffId': 2,
        'note': '[Nhắc hẹn: 30 phút trước] Giữ nguyên ghi chú',
      });
      expect(updated?.appointmentAt, DateTime(2026, 11, 20, 9, 30));
      expect(provider.items.single.staffId, 2);
      expect(provider.items.single.items.single.serviceName, 'First');
      expect(provider.items.single.items.single.expectedPrice, 100000);
      expect(provider.submitting, false);
      expect(provider.error, null);
    },
  );

  test('reschedule is blocked locally for an ineligible appointment', () async {
    var requests = 0;
    final provider = AppointmentProvider(
      dio: fakeDio((_) {
        requests++;
        return null;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    provider.items = [
      Appointment.fromJson(appointmentJson(1, status: 'DaDen')),
    ];

    final result = await provider.reschedule(
      id: 1,
      at: DateTime.now().add(const Duration(days: 1)),
    );

    expect(result, null);
    expect(requests, 0);
    expect(provider.error, 'Lịch hẹn này không còn được phép đổi.');
  });

  test(
    'late reschedule response cannot overwrite a different account',
    () async {
      final response = Completer<dynamic>();
      final provider = AppointmentProvider(dio: fakeDio((_) => response.future))
        ..bind(1);
      addTearDown(provider.dispose);
      provider.items = [Appointment.fromJson(appointmentJson(1))];

      final changing = provider.reschedule(
        id: 1,
        at: DateTime.now().add(const Duration(days: 1)),
      );
      await Future<void>.delayed(Duration.zero);
      provider.bind(2);
      provider.items = [
        Appointment.fromJson(appointmentJson(1, customerId: 2)),
      ];
      response.complete(
        appointmentJson(
          1,
          at: DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        ),
      );

      expect(await changing, null);
      expect(provider.items.single.customerId, 2);
      expect(provider.submitting, false);
      expect(provider.error, null);
    },
  );
  for (final mutate in ['create', 'cancel']) {
    test('late load cannot overwrite successful $mutate', () async {
      final started = Completer<void>();
      final old = Completer<dynamic>();
      final provider = AppointmentProvider(
        dio: fakeDio((request) {
          if (request.method == 'GET') {
            started.complete();
            return old.future;
          }
          return request.method == 'POST' ? appointmentJson(2) : null;
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      provider.items = [Appointment.fromJson(appointmentJson(1))];
      final load = provider.load();
      await started.future;
      if (mutate == 'create') {
        expect(
          await provider.create(
            at: DateTime(2026, 10, 16),
            lines: [
              {'serviceId': 1},
            ],
          ),
          isNotNull,
        );
      } else {
        expect(await provider.cancel(1), true);
      }
      old.complete({
        'items': [appointmentJson(1)],
        'totalCount': 1,
      });
      await load;
      if (mutate == 'create') {
        expect(provider.items.map((item) => item.id), contains(2));
      } else {
        expect(provider.items.single.status, 'DaHuy');
      }
    });
  }
}
