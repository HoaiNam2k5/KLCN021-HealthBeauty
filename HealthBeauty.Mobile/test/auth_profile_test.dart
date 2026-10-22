import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/core/token_storage.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/profile_provider.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
Dio transport(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = FakeAdapter(handler);
Map<String, Object?> session({
  String role = 'Customer',
  String access = 'new-access',
  String refresh = 'new-refresh',
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'accessTokenExpiresAt': '2030-01-01T00:00:00Z',
  'account': {
    'id': 1,
    'email': 'test@local.test',
    'name': 'Test',
    'role': role,
  },
};
Future<void> saveOld() => TokenStorage.save(
  'old-access',
  'old-refresh',
  accountJson: jsonEncode(session()['account']),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStorage.clear();
  });

  test(
    'concurrent 401 requests share a rotating refresh and retry with new access token',
    () async {
      await saveOld();
      var refreshCalls = 0;
      final client = ApiClient.withDio(
        dio: transport(
          (request) => response(
            {},
            request.headers['Authorization'] == 'Bearer new-access' ? 200 : 401,
          ),
        ),
        refreshDio: transport((request) async {
          refreshCalls++;
          expect(request.data, {'refreshToken': 'old-refresh'});
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return response(session());
        }),
      );
      final responses = await Future.wait([
        client.dio.get('/customers/me'),
        client.dio.get('/appointments'),
        client.dio.get('/customers/me/points'),
      ]);
      expect(responses.every((r) => r.statusCode == 200), true);
      expect(refreshCalls, 1);
      expect(await TokenStorage.refresh, 'new-refresh');
    },
  );

  test(
    'rejected shared refresh expires the session once and clears saved credentials',
    () async {
      await saveOld();
      var expired = 0;
      final client = ApiClient.withDio(
        dio: transport((_) => response({}, 401)),
        refreshDio: transport((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return response('Expired', 401);
        }),
      );
      client.onSessionExpired = () => expired++;
      await Future.wait([
        expectLater(
          client.dio.get('/customers/me'),
          throwsA(isA<DioException>()),
        ),
        expectLater(
          client.dio.get('/appointments'),
          throwsA(isA<DioException>()),
        ),
      ]);
      expect(expired, 1);
      expect(await TokenStorage.access, null);
      expect(await TokenStorage.refresh, null);
    },
  );

  test('temporary refresh server error keeps a saved session', () async {
    await saveOld();
    var expired = 0;
    final client = ApiClient.withDio(
      dio: transport((_) => response({}, 401)),
      refreshDio: transport((_) => response('Unavailable', 503)),
    );
    client.onSessionExpired = () => expired++;
    await expectLater(
      client.dio.get('/customers/me'),
      throwsA(isA<DioException>()),
    );
    expect(await TokenStorage.refresh, 'old-refresh');
    expect(expired, 0);
  });

  test('late refresh success cannot restore a logged-out session', () async {
    await saveOld();
    final started = Completer<void>();
    final finish = Completer<ResponseBody>();
    final client = ApiClient.withDio(
      dio: transport((_) => response({}, 401)),
      refreshDio: transport((_) {
        started.complete();
        return finish.future;
      }),
    );
    final request = expectLater(
      client.dio.get('/customers/me'),
      throwsA(isA<DioException>()),
    );
    await started.future;
    await TokenStorage.clear();
    finish.complete(response(session()));
    await request;
    expect(await TokenStorage.access, null);
    expect(await TokenStorage.accountJson, null);
  });

  test(
    'refresh completing after logout revokes its replacement token',
    () async {
      await saveOld();
      final started = Completer<void>();
      final finish = Completer<ResponseBody>();
      final revoked = <String>[];
      final client = ApiClient.withDio(
        dio: transport((request) {
          if (request.path == '/auth/logout') {
            revoked.add(request.data['refreshToken'] as String);
            if (request.data['refreshToken'] == 'new-refresh') {
              expect(request.headers['Authorization'], 'Bearer new-access');
            }
            return response({}, 204);
          }
          return response({}, 401);
        }),
        refreshDio: transport((_) {
          started.complete();
          return finish.future;
        }),
      );
      final auth = AuthProvider(client: client);
      await auth.tryAutoLogin();
      final request = expectLater(
        client.dio.get('/customers/me'),
        throwsA(isA<DioException>()),
      );
      await started.future;
      await auth.logout();
      finish.complete(response(session()));
      await request;
      expect(revoked, ['old-refresh', 'new-refresh']);
      expect(auth.account, null);
      expect(await TokenStorage.access, null);
      expect(await TokenStorage.refresh, null);
      auth.dispose();
    },
  );

  test(
    'stale refresh revokes only its own token after account switch',
    () async {
      await saveOld();
      final started = Completer<void>();
      final finish = Completer<ResponseBody>();
      final revoked = <String>[];
      final client = ApiClient.withDio(
        dio: transport((request) {
          if (request.path == '/auth/logout') {
            expect(request.headers['Authorization'], 'Bearer new-access');
            revoked.add(request.data['refreshToken'] as String);
            return response({}, 204);
          }
          return response({}, 401);
        }),
        refreshDio: transport((_) {
          started.complete();
          return finish.future;
        }),
      );
      final request = expectLater(
        client.dio.get('/customers/me'),
        throwsA(isA<DioException>()),
      );
      await started.future;
      await TokenStorage.save(
        'other-access',
        'other-refresh',
        accountJson: jsonEncode(session()['account']),
      );
      finish.complete(response(session()));
      await request;
      expect(revoked, ['new-refresh']);
      expect(await TokenStorage.access, 'other-access');
      expect(await TokenStorage.refresh, 'other-refresh');
    },
  );

  test(
    'late rejected refresh cannot clear a newly logged-in account',
    () async {
      await saveOld();
      final started = Completer<void>();
      final finish = Completer<ResponseBody>();
      final client = ApiClient.withDio(
        dio: transport((_) => response({}, 401)),
        refreshDio: transport((_) {
          started.complete();
          return finish.future;
        }),
      );
      final request = expectLater(
        client.dio.get('/customers/me'),
        throwsA(isA<DioException>()),
      );
      await started.future;
      await TokenStorage.save(
        'other-access',
        'other-refresh',
        accountJson: jsonEncode(session()['account']),
      );
      finish.complete(response('Old token', 401));
      await request;
      expect(await TokenStorage.access, 'other-access');
      expect(await TokenStorage.refresh, 'other-refresh');
    },
  );

  test(
    'Customer login stores the actual account DTO and trims email',
    () async {
      final client = ApiClient.withDio(
        dio: transport((request) {
          expect(request.path, '/auth/login');
          expect(request.data['email'], 'test@local.test');
          return response(session());
        }),
        refreshDio: transport((_) => response(session())),
      );
      final auth = AuthProvider(client: client);
      expect(await auth.login(' test@local.test ', 'password123'), true);
      expect(auth.account?.role, 'Customer');
      expect(auth.account?.id, 1);
      auth.dispose();
    },
  );

  test(
    'management accounts are rejected and their new refresh token is revoked',
    () async {
      var revoked = false;
      final client = ApiClient.withDio(
        dio: transport((request) {
          if (request.path == '/auth/logout') {
            revoked = true;
            expect(request.headers['Authorization'], 'Bearer new-access');
            expect(request.data, {'refreshToken': 'new-refresh'});
            return response({}, 204);
          }
          return response(session(role: 'Reception'));
        }),
        refreshDio: transport((_) => response(session())),
      );
      final auth = AuthProvider(client: client);
      expect(await auth.login('test@local.test', 'password123'), false);
      expect(auth.isLoggedIn, false);
      expect(revoked, true);
      expect(await TokenStorage.access, null);
      auth.dispose();
    },
  );

  test(
    'malformed login response reports an error instead of throwing out of provider',
    () async {
      final client = ApiClient.withDio(
        dio: transport((_) => response({'accessToken': 'only-access'})),
        refreshDio: transport((_) => response(session())),
      );
      final auth = AuthProvider(client: client);
      expect(await auth.login('test@local.test', 'password123'), false);
      expect(auth.error, isNotNull);
      expect(await TokenStorage.access, null);
      auth.dispose();
    },
  );

  test(
    'expired-access logout revokes rotated token without restoring session',
    () async {
      await saveOld();
      final revoked = <String>[];
      var refreshCalls = 0;
      final client = ApiClient.withDio(
        dio: transport((request) {
          expect(request.path, '/auth/logout');
          if (request.headers['Authorization'] == 'Bearer old-access') {
            return response({}, 401);
          }
          expect(request.headers['Authorization'], 'Bearer new-access');
          revoked.add(request.data['refreshToken'] as String);
          return response({}, 204);
        }),
        refreshDio: transport((request) async {
          refreshCalls++;
          expect(request.data, {'refreshToken': 'old-refresh'});
          expect(await TokenStorage.access, null);
          return response(session());
        }),
      );
      final auth = AuthProvider(client: client);
      await auth.tryAutoLogin();
      await auth.logout();
      expect(refreshCalls, 1);
      expect(revoked, ['new-refresh']);
      expect(auth.account, null);
      expect(await TokenStorage.access, null);
      expect(await TokenStorage.refresh, null);
      auth.dispose();
    },
  );

  test('late login cannot sign in after logout', () async {
    final started = Completer<void>();
    final finish = Completer<ResponseBody>();
    final client = ApiClient.withDio(
      dio: transport((_) {
        started.complete();
        return finish.future;
      }),
      refreshDio: transport((_) => response(session())),
    );
    final auth = AuthProvider(client: client);
    final request = auth.login('test@local.test', 'password123');
    await started.future;
    await auth.logout();
    finish.complete(response(session()));
    expect(await request, false);
    expect(auth.account, null);
    expect(await TokenStorage.access, null);
    auth.dispose();
  });

  test(
    'profile and point DTOs map actual current-customer endpoint responses',
    () async {
      final provider = ProfileProvider(
        dio: transport(
          (request) => response(
            request.path.endsWith('/points')
                ? {
                    'balance': 99,
                    'transactions': [
                      {
                        'giaoDichId': 7,
                        'soDiem': -3,
                        'loaiGiaoDich': 'DoiDiem',
                        'ngayGiaoDich': '2026-10-20T14:00:00',
                        'ghiChu': 'Test',
                      },
                    ],
                  }
                : {
                    'id': 3,
                    'fullName': 'Test Customer',
                    'phone': null,
                    'gender': null,
                    'rewardPoints': 99,
                  },
          ),
        ),
      )..bind(1);
      await provider.load();
      expect(provider.customer?.rewardPoints, 99);
      expect(provider.transactions.single.points, -3);
      expect(provider.transactions.single.id, 7);
      provider.dispose();
    },
  );

  test(
    'profile response from previous account is ignored after rebind',
    () async {
      final pending = <Completer<ResponseBody>>[];
      final started = Completer<void>();
      final provider = ProfileProvider(
        dio: transport((_) {
          final c = Completer<ResponseBody>();
          pending.add(c);
          if (pending.length == 2) started.complete();
          return c.future;
        }),
      )..bind(1);
      final load = provider.load();
      await started.future;
      provider.bind(2);
      pending[0].complete(
        response({'id': 1, 'fullName': 'Old', 'rewardPoints': 100}),
      );
      pending[1].complete(response({'transactions': []}));
      await load;
      expect(provider.customer, null);
      expect(provider.transactions, isEmpty);
      expect(provider.loading, false);
      provider.dispose();
    },
  );
  test('late profile load cannot overwrite a successful update', () async {
    final started = Completer<void>();
    final old = Completer<ResponseBody>();
    final provider = ProfileProvider(
      dio: transport((request) {
        if (request.method == 'PUT') {
          return response({'id': 1, 'fullName': 'New', 'rewardPoints': 100});
        }
        if (request.path.endsWith('/points')) {
          return response({'transactions': []});
        }
        started.complete();
        return old.future;
      }),
    )..bind(1);
    final load = provider.load();
    await started.future;
    expect(await provider.update(fullName: 'New'), true);
    old.complete(response({'id': 1, 'fullName': 'Old', 'rewardPoints': 100}));
    await load;
    expect(provider.customer?.fullName, 'New');
    provider.dispose();
  });

  test('forgot password and reset password invoke auth endpoints correctly', () async {
    final client = ApiClient.withDio(
      dio: transport((request) {
        if (request.path == '/auth/forgot-password') {
          expect(request.data['email'], 'test@local.test');
          return response({'message': 'Mã OTP đã gửi', 'debugOtp': '123456'});
        }
        if (request.path == '/auth/reset-password') {
          expect(request.data['email'], 'test@local.test');
          expect(request.data['otp'], '123456');
          expect(request.data['newPassword'], 'newpassword123');
          return response({'message': 'Thành công'});
        }
        return response({}, 404);
      }),
      refreshDio: transport((_) => response(session())),
    );
    final auth = AuthProvider(client: client);
    final forgotRes = await auth.forgotPassword('test@local.test');
    expect(forgotRes?['debugOtp'], '123456');

    final resetOk = await auth.resetPassword(
      email: 'test@local.test',
      otp: '123456',
      newPassword: 'newpassword123',
    );
    expect(resetOk, true);
    auth.dispose();
  });

  test('2FA login flow requests OTP and completes sign-in upon verification', () async {
    final client = ApiClient.withDio(
      dio: transport((request) {
        if (request.path == '/auth/login') {
          return response({
            'requiresTwoFactor': true,
            'email': 'customer@local.test',
            'message': 'Mã xác thực đã được gửi',
          });
        }
        if (request.path == '/auth/verify-2fa') {
          expect(request.data['email'], 'customer@local.test');
          expect(request.data['otp'], '654321');
          return response(session(role: 'Customer'));
        }
        if (request.path == '/auth/resend-2fa') {
          expect(request.data['email'], 'customer@local.test');
          return response({'message': 'Mã mới đã được gửi'});
        }
        return response({}, 404);
      }),
      refreshDio: transport((_) => response(session())),
    );
    final auth = AuthProvider(client: client);
    final loginOk = await auth.login('customer@local.test', 'password123');
    expect(loginOk, false);
    expect(auth.requiresTwoFactor, true);
    expect(auth.twoFactorEmail, 'customer@local.test');
    expect(auth.isLoggedIn, false);

    final resendOk = await auth.resendTwoFactor();
    expect(resendOk, true);

    final verifyOk = await auth.verifyTwoFactor('654321');
    expect(verifyOk, true);
    expect(auth.requiresTwoFactor, false);
    expect(auth.isLoggedIn, true);
    expect(auth.account?.role, 'Customer');
    auth.dispose();
  });

  test('Google login sends token payload and establishes customer session', () async {
    final client = ApiClient.withDio(
      dio: transport((request) {
        if (request.path == '/auth/google') {
          expect(request.data['email'], 'googleuser@local.test');
          expect(request.data['googleId'], 'gid_999888');
          expect(request.data['fullName'], 'Google Test User');
          expect(request.data['idToken'], 'mock-id-token');
          return response(session(role: 'Customer'));
        }
        return response({}, 404);
      }),
      refreshDio: transport((_) => response(session())),
    );
    final auth = AuthProvider(client: client);
    final ok = await auth.loginWithGoogleToken(
      email: 'googleuser@local.test',
      googleId: 'gid_999888',
      fullName: 'Google Test User',
      idToken: 'mock-id-token',
    );
    expect(ok, true);
    expect(auth.isLoggedIn, true);
    expect(auth.account?.role, 'Customer');
    auth.dispose();
  });
}

