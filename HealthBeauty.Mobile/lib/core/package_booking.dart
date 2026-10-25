import '../models/catalog.dart';
import '../models/service_package.dart';

List<Map<String, dynamic>> buildPackageBookingLines({
  required CustomerServicePackage package,
  required Map<int, int> quantities,
  required Iterable<Service> services,
  DateTime? appointmentAt,
}) {
  if (!package.canUseAt(appointmentAt ?? DateTime.now())) {
    throw const FormatException(
      'Gói chưa thanh toán, đã hết hạn hoặc không còn lượt khả dụng.',
    );
  }
  if (quantities.isEmpty) {
    throw const FormatException('Chọn dịch vụ muốn sử dụng trong gói.');
  }
  final catalog = {for (final service in services) service.id: service};
  var minutes = 0;
  for (final selection in quantities.entries) {
    final balance = package.service(selection.key);
    final service = catalog[selection.key];
    if (balance == null ||
        service == null ||
        selection.value < 1 ||
        selection.value > balance.available) {
      throw const FormatException(
        'Dịch vụ không thuộc gói, đã ngừng cung cấp hoặc không còn đủ lượt.',
      );
    }
    minutes +=
        selection.value *
        (service.durationMinutes > 0 ? service.durationMinutes : 30);
  }
  if (minutes > 1440) {
    throw const FormatException(
      'Thời lượng vượt quá 24 giờ. Vui lòng tách thành nhiều lịch hẹn.',
    );
  }
  return [
    for (final selection in quantities.entries)
      for (var i = 0; i < selection.value; i++)
        {'serviceId': selection.key, 'comboId': null, 'expectedPrice': 0},
  ];
}
