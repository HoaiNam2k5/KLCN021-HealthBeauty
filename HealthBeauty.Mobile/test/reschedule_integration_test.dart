import 'dart:async';

import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/models/booking_contract.dart';
import 'package:app_doancunhan/models/account.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/screens/reschedule_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

final original = Appointment(
  id: 7,
  customerId: 1,
  staffId: 4,
  appointmentAt: DateTime(2098, 1, 1, 9),
  status: 'DaXacNhan',
  note: 'Keep this note',
  customerPackageId: 12,
  invoiceId: 20,
  invoiceStatus: 'ChuaThanhToan',
  hasReviewed: true,
  reviewStars: 5,
  reviewComment: 'Feedback',
  reviewReply: 'Reply',
  reviewedAt: DateTime(2026, 10, 20),
  reviewRepliedAt: DateTime(2026, 10, 21),
  items: const [
    AppointmentItem(
      id: 3,
      serviceId: 8,
      serviceName: 'Care',
      expectedPrice: 0,
      durationMinutes: 45,
    ),
  ],
);
final target = DateTime(2098, 1, 2, 10);
Map<String, dynamic> detail(DateTime at) => {
  'lichHenId': 7,
  'khachHangId': 1,
  'nhanVienId': 4,
  'ngayGioHen': localBookingDateTime(at),
  'trangThai': 'DaXacNhan',
  'ghiChu': 'Keep this note',
  'customerPackageId': 12,
  'chitietlichhens': [
    {
      'chiTietLichHenId': 3,
      'dichVuId': 8,
      'comboId': null,
      'giaDuKien': 0,
      'durationMinutes': 45,
      'dichVu': {'tenDichVu': 'Care'},
    },
  ],
};

Dio transport(FutureOr<dynamic> Function(RequestOptions) reply) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) async {
        try {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: await reply(request),
            ),
          );
        } on DioException catch (error) {
          handler.reject(error);
        } catch (error) {
          handler.reject(DioException(requestOptions: request, error: error));
        }
      },
    ),
  );
  return dio;
}

void main() {
  test('detail DTO preserves paid-package, invoice, review, services and assigned staff', () {
    final data = detail(target)..remove('customerPackageId');
    final updated = Appointment.fromRescheduleJson(data, fallback: original);
    expect(updated.appointmentAt, target);
    expect(updated.customerPackageId, 12);
    expect(updated.staffId, 4);
    expect(updated.note, original.note);
    expect(updated.items.single.durationMinutes, 45);
    expect(updated.items.single.serviceName, 'Care');
    expect(updated.invoiceId, 20);
    expect(updated.invoiceStatus, original.invoiceStatus);
    expect(updated.reviewComment, original.reviewComment);
    expect(updated.reviewReply, original.reviewReply);
    expect(updated.reviewRepliedAt, original.reviewRepliedAt);
  });

  test(
    'different appointment identity cannot overwrite the owned cached booking',
    () {
      expect(
        () => Appointment.fromRescheduleJson(
          detail(target)..['lichHenId'] = 99,
          fallback: original,
        ),
        throwsFormatException,
      );
    },
  );

  test('successful reschedule posts only new time and retained staff/note, updates cache', () async {
    final provider =
        AppointmentProvider(
            dio: transport((request) {
              expect(request.method, 'POST');
              expect(request.path, '/appointments/7/reschedule');
              expect(request.extra, contains('sessionGeneration'));
              expect(request.data, {
                'appointmentAt': localBookingDateTime(target),
                'staffId': 4,
                'note': 'Keep this note',
              });
              return detail(target);
            }),
          )
          ..bind(1)
          ..items = [original];
    addTearDown(provider.dispose);
    final updated = await provider.reschedule(id: 7, at: target);
    expect(updated?.customerPackageId, 12);
    expect(provider.items.single.appointmentAt, target);
    expect(provider.error, isNull);
  });

  test('timeout after committed POST reconciles by GET instead of reporting false failure', () async {
    var posts = 0, reads = 0;
    final provider =
        AppointmentProvider(
            dio: transport((request) {
              if (request.method == 'POST') {
                posts++;
                throw DioException(
                  requestOptions: request,
                  type: DioExceptionType.receiveTimeout,
                );
              }
              reads++;
              expect(request.path, '/appointments/7');
              return detail(target);
            }),
          )
          ..bind(1)
          ..items = [original];
    addTearDown(provider.dispose);
    expect(
      (await provider.reschedule(id: 7, at: target))?.appointmentAt,
      target,
    );
    expect(posts, 1);
    expect(reads, 1);
    expect(provider.hasUncertainReschedule(7), false);
    expect(provider.error, isNull);
  });

  test('uncertain outcome locks a second POST and later checks the pending result only', () async {
    var posts = 0, reads = 0;
    final provider =
        AppointmentProvider(
            dio: transport((request) {
              if (request.method == 'POST') {
                posts++;
                return {};
              }
              reads++;
              return detail(reads == 1 ? original.appointmentAt : target);
            }),
          )
          ..bind(1)
          ..items = [original];
    addTearDown(provider.dispose);
    expect(await provider.reschedule(id: 7, at: target), isNull);
    expect(provider.hasUncertainReschedule(7), true);
    expect(await provider.cancel(7), false);
    expect(
      (await provider.reschedule(id: 7, at: target))?.appointmentAt,
      target,
    );
    expect(posts, 1);
    expect(reads, 2);
    expect(provider.hasUncertainReschedule(7), false);
  });

  test(
    'late response after account change cannot replace new-account data',
    () async {
      final started = Completer<void>(),
          finish = Completer<Map<String, dynamic>>();
      final provider =
          AppointmentProvider(
              dio: transport((request) {
                started.complete();
                return finish.future;
              }),
            )
            ..bind(1)
            ..items = [original];
      addTearDown(provider.dispose);
      final pending = provider.reschedule(id: 7, at: target);
      await started.future;
      provider.bind(2);
      finish.complete(detail(target));
      expect(await pending, isNull);
      expect(provider.items, isEmpty);
      expect(provider.submitting, false);
      expect(provider.hasUncertainReschedule(7), false);
    },
  );

  test(
    'pre-update list request cannot overwrite successful reschedule',
    () async {
      final started = Completer<void>(),
          oldList = Completer<Map<String, dynamic>>();
      final provider =
          AppointmentProvider(
              dio: transport((request) {
                if (request.method == 'POST') return detail(target);
                started.complete();
                return oldList.future;
              }),
            )
            ..bind(1)
            ..items = [original];
      addTearDown(provider.dispose);
      final loading = provider.load();
      await started.future;
      expect(await provider.reschedule(id: 7, at: target), isNotNull);
      oldList.complete({
        'items': [
          {
            'id': 7,
            'customerId': 1,
            'staffId': 4,
            'appointmentAt': localBookingDateTime(original.appointmentAt),
            'status': 'DaXacNhan',
            'items': [],
          },
        ],
        'totalCount': 1,
      });
      await loading;
      expect(provider.items.single.appointmentAt, target);
      expect(provider.items.single.customerPackageId, 12);
    },
  );

  test('only waiting/confirmed appointments can change and availability excludes owned ID', () async {
    var reads = 0;
    final provider = AppointmentProvider(
      dio: transport((request) {
        reads++;
        expect(request.path, '/appointments/availability');
        expect(request.queryParameters['excludeAppointmentId'], 7);
        return [];
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    for (final status in ['DaDen', 'DangThucHien', 'HoanThanh', 'DaHuy']) {
      provider.items = [original.copyWith(status: status)];
      expect(await provider.reschedule(id: 7, at: target), isNull);
    }
    provider.items = [original];
    expect(
      await provider.reschedule(id: 7, at: original.appointmentAt),
      isNull,
    );
    expect(await provider.reschedule(id: 7, at: DateTime(2000)), isNull);
    await provider.availableSlots(
      date: target,
      staffId: 4,
      durationMinutes: 45,
      excludeAppointmentId: 7,
    );
    expect(reads, 1);
  });

  test(
    'authoritative cancellation resolves uncertainty without retrying mutation',
    () async {
      var posts = 0;
      final provider =
          AppointmentProvider(
              dio: transport((request) {
                if (request.method == 'POST') {
                  posts++;
                  return {};
                }
                return detail(original.appointmentAt)..['trangThai'] = 'DaHuy';
              }),
            )
            ..bind(1)
            ..items = [original];
      addTearDown(provider.dispose);
      expect(await provider.reschedule(id: 7, at: target), isNull);
      expect(posts, 1);
      expect(provider.items.single.status, 'DaHuy');
      expect(provider.hasUncertainReschedule(7), false);
    },
  );

  for (final past in [false, true]) {
    testWidgets(
      'calendar safely focuses ${past ? "past" : "more-than-60-day"} original booking',
      (tester) async {
        final now = DateTime.now();
        final at = now.add(Duration(days: past ? -10 : 500));
        final row = original.copyWith(appointmentAt: at);
        final dio = transport((request) => []);
        final provider = AppointmentProvider(dio: dio)
          ..bind(1)
          ..items = [row];
        final auth = AuthProvider(
          client: ApiClient.withDio(dio: dio, refreshDio: dio),
        )..account = Account(id: 1, email: 'test@example.invalid');
        addTearDown(provider.dispose);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: auth),
            ],
            child: MaterialApp(home: RescheduleScreen(appointment: row)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final calendar = tester.widget<TableCalendar>(
          find.byType(TableCalendar),
        );
        expect(calendar.focusedDay.isBefore(calendar.firstDay), false);
        expect(calendar.focusedDay.isAfter(calendar.lastDay), false);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
