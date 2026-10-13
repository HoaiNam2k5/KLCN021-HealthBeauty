import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _s = FlutterSecureStorage();
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kAccount = 'account_data';

  static Future<void> save(String access, String? refresh, {String? accountJson}) async {
    await _s.write(key: _kAccess, value: access);
    if (refresh != null) await _s.write(key: _kRefresh, value: refresh);
    if (accountJson != null) await _s.write(key: _kAccount, value: accountJson);
  }

  static Future<String?> get access => _s.read(key: _kAccess);
  static Future<String?> get refresh => _s.read(key: _kRefresh);
  static Future<String?> get accountJson => _s.read(key: _kAccount);
  static Future<void> clear() => _s.deleteAll();
}
