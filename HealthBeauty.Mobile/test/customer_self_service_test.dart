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
import 'package:app_doancunhan/models/customer.dart';

class _Adapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) reply;
  _Adapter(this.reply);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (stream != null) await stream.drain<void>();
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio transport(FutureOr<ResponseBody> Function(RequestOptions) reply) =>
    Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = _Adapter(reply);
ResponseBody body(Object? value, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
const png = [137, 80, 78, 71, 13, 10, 26, 10];
Map<String, dynamic> profile([
  String? avatar = 'https://example.test/avatar.png',
]) => {
  'id': 1,
  'fullName': 'Customer',
  'rewardPoints': 42,
  'avatarUrl': avatar,
};
Map<String, dynamic> session() => {
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'account': {'id': 1, 'email': 'customer@example.test', 'role': 'Customer'},
};
Future<void> saveSession() => TokenStorage.save(
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
    'avatar sends multipart own endpoint and maps updated profile',
    () async {
      final provider = ProfileProvider(
        dio: transport((request) {
          expect(request.path, '/customers/me/avatar');
          expect(request.method, 'POST');
          final file = (request.data as FormData).files.single;
          expect(file.key, 'File');
          expect(file.value.contentType.toString(), 'image/png');
          expect(request.queryParameters, isEmpty);
          return body(profile());
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      expect(await provider.updateAvatar(bytes: png), true);
      expect(provider.customer?.avatarUrl, 'https://example.test/avatar.png');
      expect(provider.customer?.rewardPoints, 42);
      expect(provider.avatarSaving, false);
    },
  );

  test('invalid image does not call API or erase existing profile', () async {
    var calls = 0;
    final provider = ProfileProvider(
      dio: transport((_) {
        calls++;
        return body(profile());
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final original = Customer.fromJson(profile());
    provider.customer = original;
    expect(await provider.updateAvatar(bytes: [1, 2, 3]), false);
    expect(calls, 0);
    expect(provider.customer, same(original));
    expect(provider.error, contains('PNG'));
  });

  test('late avatar response cannot update another account', () async {
    final started = Completer<void>();
    final reply = Completer<ResponseBody>();
    final provider = ProfileProvider(
      dio: transport((_) {
        started.complete();
        return reply.future;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final pending = provider.updateAvatar(bytes: png);
    await started.future;
    provider.bind(2);
    reply.complete(body(profile()));
    expect(await pending, false);
    expect(provider.customer, null);
    expect(provider.avatarSaving, false);
  });

  test('deleting avatar uses own DELETE endpoint', () async {
    final provider = ProfileProvider(
      dio: transport((request) {
        expect(request.path, '/customers/me/avatar');
        expect(request.method, 'DELETE');
        return body(profile(null));
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    expect(await provider.updateAvatar(remove: true), true);
    expect(provider.customer?.avatarUrl, null);
  });

  test(
    'expired access retries a cloned multipart upload after refresh',
    () async {
      await saveSession();
      var attempts = 0;
      final client = ApiClient.withDio(
        dio: transport((request) {
          attempts++;
          expect((request.data as FormData).files.single.key, 'File');
          return request.headers['Authorization'] == 'Bearer new-access'
              ? body(profile())
              : body(null, 401);
        }),
        refreshDio: transport((_) => body(session())),
      );
      final provider = ProfileProvider(dio: client.dio)..bind(1);
      addTearDown(provider.dispose);
      expect(await provider.updateAvatar(bytes: png), true);
      expect(attempts, 2);
    },
  );

  test(
    'password change keeps whitespace and clears revoked local session',
    () async {
      await saveSession();
      final client = ApiClient.withDio(
        dio: transport((request) {
          expect(request.path, '/auth/change-password');
          expect(request.data, {
            'currentPassword': ' old-password ',
            'newPassword': ' new-password ',
          });
          return body(null, 204);
        }),
        refreshDio: transport((_) => body(session())),
      );
      final auth = AuthProvider(client: client);
      addTearDown(auth.dispose);
      await auth.tryAutoLogin();
      expect(
        await auth.changePassword(' old-password ', ' new-password '),
        true,
      );
      expect(auth.account, null);
      expect(await TokenStorage.access, null);
      expect(auth.isLoading, false);
    },
  );

  test('wrong old password preserves current login', () async {
    await saveSession();
    final client = ApiClient.withDio(
      dio: transport((_) => body('wrong', 400)),
      refreshDio: transport((_) => body(session())),
    );
    final auth = AuthProvider(client: client);
    addTearDown(auth.dispose);
    await auth.tryAutoLogin();
    expect(await auth.changePassword('old-password', 'new-password'), false);
    expect(auth.account, isNotNull);
    expect(await TokenStorage.access, 'old-access');
    expect(auth.error, contains('hiện tại'));
  });

  test(
    'password change refreshes expired access before clearing rotated session',
    () async {
      await saveSession();
      var attempts = 0;
      final client = ApiClient.withDio(
        dio: transport((request) {
          attempts++;
          return body(
            null,
            request.headers['Authorization'] == 'Bearer new-access' ? 204 : 401,
          );
        }),
        refreshDio: transport((_) => body(session())),
      );
      final auth = AuthProvider(client: client);
      addTearDown(auth.dispose);
      await auth.tryAutoLogin();
      expect(await auth.changePassword('old-password', 'new-password'), true);
      expect(attempts, 2);
      expect(await TokenStorage.access, null);
    },
  );

  test(
    'refresh rotation preserves login identity but logout and login replace it',
    () async {
      await saveSession();
      final identity = TokenStorage.sessionGeneration;
      expect(
        await TokenStorage.saveIfCurrent(
          TokenStorage.generation,
          'rotated-access',
          'rotated-refresh',
          accountJson: jsonEncode(session()['account']),
        ),
        true,
      );
      expect(TokenStorage.sessionGeneration, identity);
      await TokenStorage.clear();
      expect(TokenStorage.sessionGeneration, greaterThan(identity));
      final loggedOut = TokenStorage.sessionGeneration;
      await saveSession();
      expect(TokenStorage.sessionGeneration, greaterThan(loggedOut));
    },
  );

  test(
    'old avatar 401 never refreshes or replays under a newly logged-in account',
    () async {
      await saveSession();
      var requests = 0;
      var refreshes = 0;
      final started = Completer<void>();
      final reply = Completer<ResponseBody>();
      final client = ApiClient.withDio(
        dio: transport((_) {
          requests++;
          started.complete();
          return reply.future;
        }),
        refreshDio: transport((_) {
          refreshes++;
          return body(session());
        }),
      );
      final provider = ProfileProvider(dio: client.dio)..bind(1);
      addTearDown(provider.dispose);
      final pending = provider.updateAvatar(bytes: png);
      await started.future;
      await TokenStorage.clear();
      await TokenStorage.save(
        'account-B-access',
        'account-B-refresh',
        accountJson: jsonEncode({
          'id': 2,
          'email': 'b@example.test',
          'role': 'Customer',
        }),
      );
      provider.bind(2);
      reply.complete(body(null, 401));
      expect(await pending, false);
      expect(requests, 1);
      expect(refreshes, 0);
      expect(await TokenStorage.access, 'account-B-access');
      expect(provider.customer, null);
    },
  );

  test(
    'queued sensitive request is canceled if its login changes before sending',
    () async {
      await saveSession();
      final identity = TokenStorage.sessionGeneration;
      var requests = 0;
      final client = ApiClient.withDio(
        dio: transport((_) {
          requests++;
          return body(null, 204);
        }),
        refreshDio: transport((_) => body(session())),
      );
      final pending = client.dio.put(
        '/auth/change-password',
        data: {
          'currentPassword': 'old-password',
          'newPassword': 'new-password',
        },
        options: Options(extra: {'sessionGeneration': identity}),
      );
      final rejected = expectLater(
        pending,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'canceled',
            DioExceptionType.cancel,
          ),
        ),
      );
      await TokenStorage.save(
        'account-B-access',
        'account-B-refresh',
        accountJson: jsonEncode({
          'id': 2,
          'email': 'b@example.test',
          'role': 'Customer',
        }),
      );
      await rejected;
      expect(requests, 0);
      expect(await TokenStorage.access, 'account-B-access');
    },
  );
}
