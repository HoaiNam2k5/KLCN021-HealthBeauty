import 'dart:io';

import 'package:app_doancunhan/core/avatar_image.dart';
import 'package:app_doancunhan/core/password_change.dart';
import 'package:app_doancunhan/models/customer.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final tests = <void Function()>[
    () => check(
      Customer.fromJson({'id': 1, 'fullName': 'Old'}).avatarUrl == null,
      'Legacy profile without avatar',
    ),
    () => check(
      Customer.fromJson({
            'id': 1,
            'avatarUrl': ' https://example.test/avatar.png ',
          }).avatarUrl ==
          'https://example.test/avatar.png',
      'Avatar URL retained',
    ),
    () => check(
      avatarImageContentType([137, 80, 78, 71, 13, 10, 26, 10]) == 'image/png',
      'PNG signature',
    ),
    () => check(
      avatarImageContentType([255, 216, 255, 0]) == 'image/jpeg',
      'JPEG signature',
    ),
    () => check(
      avatarImageContentType([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]) ==
          'image/webp',
      'WebP signature',
    ),
    () => check(
      avatarImageContentType([137, 80]) == null &&
          avatarImageContentType([1, 2, 3]) == null,
      'Invalid image signatures',
    ),
    () => check(maximumAvatarBytes == 5242880, '5MB avatar bound'),
    () => check(
      validatePasswordChange('', 'valid-new-pass') != null,
      'Current password required',
    ),
    () => check(
      validatePasswordChange('old-password', 'short') != null,
      'Minimum password length',
    ),
    () => check(
      validatePasswordChange('old-password', 'a' * 129) != null,
      'Maximum password length',
    ),
    () => check(
      validatePasswordChange('old-password', 'old-password') != null,
      'Same password rejected',
    ),
    () => check(
      validatePasswordChange(' password ', 'password') == null,
      'Passwords are not trimmed',
    ),
  ];
  for (final test in tests) {
    test();
  }
  stdout.writeln(
    'CUSTOMER_SELF_SERVICE_CONTRACT: ${tests.length}/${tests.length} PASS',
  );
}
