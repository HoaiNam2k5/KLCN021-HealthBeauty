import 'package:latlong2/latlong.dart';

class SpaLocation {
  static const name = 'HealthBeauty';
  static const address =
      '140 Lê Trọng Tấn, Tây Thạnh, Tân Phú, TP. Hồ Chí Minh';
  // Address coordinates from the map embedded by huit.edu.vn for 140 LTT.
  // Verified 2026-10-27; kept separate so a production branch can be updated.
  static const point = LatLng(10.806527989344023, 106.62643337487016);

  static Uri get mapUrl => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': address,
  });
  static Uri get directionsUrl => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': address,
  });
}
