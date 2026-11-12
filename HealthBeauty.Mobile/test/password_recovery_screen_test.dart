import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'auth_profile_test.dart' as fixtures;

void main() {
  testWidgets('recovery waits 60 seconds before requesting a replacement OTP', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    final dio = fixtures.transport((request) {
      expect(request.path, '/auth/forgot-password');
      expect(request.data['email'], 'customer@example.invalid');
      requests++;
      return fixtures.response({'message': 'Yêu cầu đã được tiếp nhận.'});
    });
    final auth = AuthProvider(
      client: ApiClient.withDio(
        dio: dio,
        refreshDio: fixtures.transport(
          (_) => throw StateError('Refresh is not used by password recovery'),
        ),
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: 'customer@example.invalid'),
        ),
      ),
    );
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Gửi lại (60s)'))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi lại mã OTP'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Gửi lại (60s)'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
