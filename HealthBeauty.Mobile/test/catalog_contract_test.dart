import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handle;
  _Adapter(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

Dio _dio(Future<ResponseBody> Function(RequestOptions) handle) =>
    Dio(BaseOptions(baseUrl: 'http://example.test/api/v1'))
      ..httpClientAdapter = _Adapter(handle);
ResponseBody _body(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
Map<String, dynamic> _voucher(
  String code, {
  Object? flag,
  DateTime? expiresAt,
}) => {
  'voucherId': 1,
  'maCode': code,
  'giaTriGiam': 100000,
  'tenKhuyenMai': 'Care',
  'hanSuDung': (expiresAt ?? DateTime.now().add(const Duration(days: 1)))
      .toIso8601String(),
  'trangThai': ?flag,
};
Map<String, dynamic> _validation({bool valid = true}) => {
  'valid': valid,
  'maCode': 'SAVE',
  'giaTriGiam': 100000,
  'tenKhuyenMai': 'Care',
  'hanSuDung': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
};
Map<String, dynamic> _offer({
  int id = 41,
  int pointsCost = 250,
  DateTime? expiresAt,
}) => {
  'id': id,
  'promotionId': 9,
  'promotionName': 'Đổi điểm chăm sóc da',
  'discountValue': 75000,
  'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(days: 10)))
      .toIso8601String(),
  'pointsCost': pointsCost,
};

void main() {
  test(
    'validation DTO respects valid flag and exposes code and discount cap',
    () {
      final valid = VoucherCheck.fromJson(_validation());
      expect(valid.valid, isTrue);
      expect(valid.code, 'SAVE');
      expect(valid.title, 'Care');
      expect(valid.value, 100000);
      expect(VoucherCheck.fromJson(_validation(valid: false)).valid, isFalse);
      expect(
        () => VoucherCheck.fromJson({'valid': true}),
        throwsFormatException,
      );
      expect(
        () => VoucherCheck.fromJson({'maCode': 'SAVE'}),
        throwsFormatException,
      );
    },
  );

  test(
    'personal endpoint omits flag, explicit disabled flags are respected',
    () {
      final now = DateTime.now();
      expect(
        CustomerVoucher.fromJson(_voucher('OPEN')).isAvailableAt(now),
        isTrue,
      );
      expect(
        CustomerVoucher.fromJson(_voucher('FALSE', flag: false))
            .isAvailableAt(now),
        isFalse,
      );
      expect(
        CustomerVoucher.fromJson(_voucher('ZERO', flag: 0)).isAvailableAt(now),
        isFalse,
      );
      expect(
        CustomerVoucher.fromJson(_voucher('ONE', flag: 1)).isAvailableAt(now),
        isTrue,
      );
    },
  );

  test('expiry boundary is inclusive and expired vouchers cannot be shown', () {
    final now = DateTime(2026, 10, 20, 12);
    expect(
      CustomerVoucher.fromJson(_voucher('EXACT', expiresAt: now))
          .isAvailableAt(now),
      isTrue,
    );
    expect(
      CustomerVoucher.fromJson(
        _voucher('OLD', expiresAt: now.subtract(const Duration(seconds: 1))),
      ).isAvailableAt(now),
      isFalse,
    );
    final response = _validation()
      ..['hanSuDung'] = now
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
    expect(VoucherCheck.fromJson(response, now: now).valid, isFalse);
  });

  test('validation POST uses normalized query code and actual response field names', () async {
    RequestOptions? request;
    final provider = CatalogProvider(
      dio: _dio((options) async {
        if (options.path == '/promotions/vouchers/validate') {
          request = options;
          return _body(_validation());
        }
        return _body([]);
      }),
    );
    addTearDown(provider.dispose);
    provider.bind(1);
    final result = await provider.validateVoucher(' save ');
    expect(request?.method, 'POST');
    expect(request?.queryParameters, {'code': 'SAVE'});
    expect(request?.data, isNull);
    expect(result.valid, isTrue);
    expect(result.code, 'SAVE');
    expect(result.value, 100000);
  });

  test(
    'validation handles 404, false and malformed successful responses',
    () async {
      var response = _body({'valid': false}, 404);
      final provider = CatalogProvider(
        dio: _dio(
          (options) async => options.path == '/promotions/vouchers/validate'
              ? response
              : _body([]),
        ),
      );
      addTearDown(provider.dispose);
      provider.bind(1);
      expect((await provider.validateVoucher('SAVE')).valid, isFalse);
      response = _body(_validation(valid: false));
      expect((await provider.validateVoucher('SAVE')).valid, isFalse);
      response = _body([]);
      final malformed = await provider.validateVoucher('SAVE');
      expect(malformed.valid, isFalse);
      expect(malformed.message, contains('định dạng'));
    },
  );

  test(
    'empty code and signed-out state do not request personal validation',
    () async {
      var validationCalls = 0;
      final provider = CatalogProvider(
        dio: _dio((options) async {
          if (options.path == '/promotions/vouchers/validate') {
            validationCalls++;
          }
          return _body([]);
        }),
      );
      addTearDown(provider.dispose);
      expect((await provider.validateVoucher('SAVE')).valid, isFalse);
      provider.bind(1);
      expect((await provider.validateVoucher('   ')).valid, isFalse);
      expect(validationCalls, 0);
    },
  );

  test('voucher list filters explicit disabled and expired rows', () async {
    final provider = CatalogProvider(
      dio: _dio(
        (options) async => _body(
          options.path == '/customers/me/vouchers'
              ? [
                  _voucher('CURRENT'),
                  _voucher('DISABLED', flag: false),
                  _voucher(
                    'EXPIRED',
                    expiresAt: DateTime.now().subtract(const Duration(days: 1)),
                  ),
                ]
              : [],
        ),
      ),
    );
    addTearDown(provider.dispose);
    provider.bind(1);
    await provider.loadMyVouchers();
    expect(provider.myVouchers.map((voucher) => voucher.code), ['CURRENT']);
  });

  test('voucher offer DTO validates point cost and expiry', () {
    final offer = VoucherOffer.fromJson(_offer());
    expect(offer.id, 41);
    expect(offer.pointsCost, 250);
    expect(offer.discountValue, 75000);
    expect(offer.isAvailableAt(DateTime.now()), isTrue);
    expect(
      () => VoucherOffer.fromJson(_offer(pointsCost: 0)),
      throwsFormatException,
    );
  });

  test('loads point offers and redeems one into the customer wallet', () async {
    var redeemed = false;
    RequestOptions? redeemRequest;
    final provider = CatalogProvider(
      dio: _dio((options) async {
        if (options.path == '/customers/me/voucher-offers') {
          return _body([_offer()]);
        }
        if (options.path == '/customers/me/vouchers/41/redeem') {
          redeemRequest = options;
          redeemed = true;
          return _body({
            'voucherId': 41,
            'code': 'POINTS-41',
            'pointsSpent': 250,
            'remainingPoints': 750,
          });
        }
        if (options.path == '/customers/me/vouchers') {
          return _body(redeemed ? [_voucher('POINTS-41')] : []);
        }
        return _body([]);
      }),
    );
    addTearDown(provider.dispose);
    provider.bind(1);
    await provider.loadVoucherOffers();
    expect(provider.voucherOffers.single.pointsCost, 250);

    final result = await provider.redeemVoucher(41);

    expect(redeemRequest?.method, 'POST');
    expect(redeemRequest?.data, isNull);
    expect(result?.code, 'POINTS-41');
    expect(result?.remainingPoints, 750);
    expect(provider.voucherOffers, isEmpty);
    expect(provider.myVouchers.single.code, 'POINTS-41');
    expect(provider.redeemingVoucherId, isNull);
    expect(provider.offerError, isNull);
  });

  test(
    'failed point redemption keeps the offer and exposes API error',
    () async {
      final provider = CatalogProvider(
        dio: _dio((options) async {
          if (options.path == '/customers/me/voucher-offers') {
            return _body([_offer()]);
          }
          if (options.path.endsWith('/redeem')) {
            return _body('Insufficient reward points.', 400);
          }
          return _body([]);
        }),
      );
      addTearDown(provider.dispose);
      provider.bind(1);
      await provider.loadVoucherOffers();

      expect(await provider.redeemVoucher(41), isNull);
      expect(provider.voucherOffers.single.id, 41);
      expect(provider.offerError, isNotNull);
      expect(provider.redeemingVoucherId, isNull);
    },
  );

  for (final lateFailure in [false, true]) {
    test(
      'account switch ignores late ${lateFailure ? 'failed' : 'successful'} personal response',
      () async {
        final old = Completer<ResponseBody>();
        final started = Completer<void>();
        var calls = 0;
        final provider = CatalogProvider(
          dio: _dio((options) async {
            if (options.path != '/customers/me/vouchers') return _body([]);
            if (++calls == 1) {
              started.complete();
              return old.future;
            }
            return _body([_voucher('ACCOUNT-B')]);
          }),
        );
        addTearDown(provider.dispose);
        provider.bind(1);
        final previous = provider.loadMyVouchers();
        await started.future;
        provider.bind(2);
        expect(provider.myVouchers, isEmpty);
        await provider.loadMyVouchers();
        old.complete(
          lateFailure ? _body('failure', 500) : _body([_voucher('ACCOUNT-A')]),
        );
        await previous;
        expect(provider.myVouchers.map((voucher) => voucher.code), [
          'ACCOUNT-B',
        ]);
        expect(provider.voucherError, isNull);
        expect(provider.vouchersLoading, isFalse);
      },
    );
  }

  test(
    'logout clears personal cache immediately and public catalog survives',
    () async {
      final provider = CatalogProvider(
        dio: _dio(
          (options) async => _body(
            options.path == '/customers/me/vouchers' ? [_voucher('OWNED')] : [],
          ),
        ),
      );
      addTearDown(provider.dispose);
      provider.categories = [const ServiceCategory(id: 1, name: 'Public')];
      provider.bind(1);
      await provider.loadMyVouchers();
      expect(provider.myVouchers, isNotEmpty);
      provider.bind(null);
      expect(provider.myVouchers, isEmpty);
      expect(provider.staffList, isEmpty);
      expect(provider.voucherError, isNull);
      expect(provider.categories.single.name, 'Public');
    },
  );

  test(
    'failed personal refresh exposes error and removes previous data',
    () async {
      var fail = false;
      final provider = CatalogProvider(
        dio: _dio((options) async {
          if (options.path != '/customers/me/vouchers') return _body([]);
          return fail ? _body('failure', 500) : _body([_voucher('OLD-CACHE')]);
        }),
      );
      addTearDown(provider.dispose);
      provider.bind(1);
      await provider.loadMyVouchers();
      fail = true;
      await provider.loadMyVouchers();
      expect(provider.myVouchers, isEmpty);
      expect(provider.voucherError, isNotNull);
    },
  );

  test(
    'malformed personal voucher DTO exposes parsing error without stale rows',
    () async {
      final provider = CatalogProvider(
        dio: _dio(
          (options) async => _body(
            options.path == '/customers/me/vouchers'
                ? [
                    {'unexpected': 'shape'},
                  ]
                : [],
          ),
        ),
      );
      addTearDown(provider.dispose);
      provider.bind(1);
      await provider.loadMyVouchers();
      expect(provider.myVouchers, isEmpty);
      expect(provider.voucherError, contains('định dạng'));
    },
  );

  test(
    'staff uses customer-readable DTO and clears stale list on failure',
    () async {
      var fail = false;
      final provider = CatalogProvider(
        dio: _dio((options) async {
          if (options.path != '/staff') return _body([]);
          return fail
              ? _body('failure', 403)
              : _body([
                  {
                    'nhanVienId': 7,
                    'hoTen': 'Staff',
                    'chucVu': 'Therapist',
                    'chuyenMon': 'Facial',
                    'soDienThoai': '0901234567',
                  },
                ]);
        }),
      );
      addTearDown(provider.dispose);
      provider.bind(1);
      await provider.loadStaff();
      expect(provider.staffById(7)?.fullName, 'Staff');
      fail = true;
      await provider.loadStaff();
      expect(provider.staffList, isEmpty);
      expect(provider.staffError, isNotNull);
    },
  );

  test(
    'voucher validation from a previous account cannot stay valid',
    () async {
      final pending = Completer<ResponseBody>();
      final started = Completer<void>();
      final provider = CatalogProvider(
        dio: _dio((options) async {
          if (options.path == '/promotions/vouchers/validate') {
            started.complete();
            return pending.future;
          }
          return _body([]);
        }),
      );
      addTearDown(provider.dispose);
      provider.bind(1);
      final check = provider.validateVoucher('SAVE');
      await started.future;
      provider.bind(2);
      pending.complete(_body(_validation()));
      expect((await check).valid, isFalse);
    },
  );

  test(
    'late completion after disposal cannot populate personal state',
    () async {
      final pending = Completer<ResponseBody>();
      final started = Completer<void>();
      final provider = CatalogProvider(
        dio: _dio((options) async {
          if (options.path == '/customers/me/vouchers') {
            started.complete();
            return pending.future;
          }
          return _body([]);
        }),
      );
      provider.bind(1);
      final load = provider.loadMyVouchers();
      await started.future;
      provider.dispose();
      pending.complete(_body([_voucher('LATE')]));
      await load;
      expect(provider.myVouchers, isEmpty);
    },
  );
}
