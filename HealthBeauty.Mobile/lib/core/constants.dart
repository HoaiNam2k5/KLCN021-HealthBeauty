import 'package:flutter/foundation.dart';

class Constants {
  // Use the deployed API on mobile and the current origin on web.
  // Override with API_BASE_URL when running against another environment.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? '/api/v1' : 'https://healthbeauty.duckdns.org/api/v1',
  );
}
