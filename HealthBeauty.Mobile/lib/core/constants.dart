import 'package:flutter/foundation.dart';

class Constants {
  // Android emulator reaches the development machine through 10.0.2.2.
  // Override for a physical phone, web, iOS or a deployed HTTPS API.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? '/api/v1' : 'http://10.0.2.2:5230/api/v1',
  );
}
