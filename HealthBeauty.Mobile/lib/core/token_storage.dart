import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _accountKey = 'account_data';
  static Future<void> _writes = Future.value();
  static int _generation = 0;
  static int get generation => _generation;

  // Serialize secure-storage writes so an in-flight refresh cannot outlive logout.
  static Future<void> _enqueue(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> save(
    String access,
    String? refresh, {
    String? accountJson,
  }) {
    _generation++;
    return _enqueue(() async {
      await _storage.write(key: _accessKey, value: access);
      if (refresh == null) {
        await _storage.delete(key: _refreshKey);
      } else {
        await _storage.write(key: _refreshKey, value: refresh);
      }
      if (accountJson == null) {
        await _storage.delete(key: _accountKey);
      } else {
        await _storage.write(key: _accountKey, value: accountJson);
      }
    });
  }

  static Future<bool> saveIfCurrent(
    int expected,
    String access,
    String refresh, {
    required String accountJson,
  }) async {
    if (_generation != expected) return false;
    final write = save(access, refresh, accountJson: accountJson);
    final savedGeneration = _generation;
    await write;
    return _generation == savedGeneration;
  }

  static Future<String?> _read(String key) async {
    await _writes;
    return _storage.read(key: key);
  }

  static Future<String?> get access => _read(_accessKey);
  static Future<String?> get refresh => _read(_refreshKey);
  static Future<String?> get accountJson => _read(_accountKey);

  static Future<void> clear() {
    _generation++;
    return _enqueue(() async {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _accountKey);
    });
  }

  static Future<bool> clearIfCurrent(int expected) async {
    if (_generation != expected) return false;
    final write = clear();
    final clearedGeneration = _generation;
    await write;
    return _generation == clearedGeneration;
  }
}
