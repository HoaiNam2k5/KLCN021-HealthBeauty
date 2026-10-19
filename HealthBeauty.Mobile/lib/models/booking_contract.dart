import 'catalog.dart';

/// The API accepts local wall-clock time and calculates prices itself.
String localBookingDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

List<Map<String, dynamic>> buildBookingLines({
  required Iterable<Service> services,
  required Iterable<Combo> combos,
  required Iterable<Service> catalogServices,
  DateTime? appointmentDate,
}) {
  final available = {
    for (final service in catalogServices) service.id: service,
  };
  final lines = <Map<String, dynamic>>[];
  for (final service in services) {
    if (!available.containsKey(service.id)) {
      throw const FormatException('Dịch vụ không còn khả dụng.');
    }
    lines.add({
      'serviceId': service.id,
      'comboId': null,
      'expectedPrice': available[service.id]!.price,
    });
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final bookingDay = appointmentDate == null
      ? today
      : DateTime(
          appointmentDate.year,
          appointmentDate.month,
          appointmentDate.day,
        );
  for (final combo in combos) {
    if (!combo.active ||
        combo.items.isEmpty ||
        (combo.validFrom != null &&
            (today.isBefore(combo.validFrom!) ||
                bookingDay.isBefore(combo.validFrom!))) ||
        (combo.validTo != null &&
            (today.isAfter(combo.validTo!) ||
                bookingDay.isAfter(combo.validTo!)))) {
      throw const FormatException('Combo không còn hiệu lực vào ngày hẹn.');
    }
    final seen = <int>{};
    for (final component in combo.items) {
      if (!available.containsKey(component.serviceId) ||
          component.quantity < 1 ||
          !seen.add(component.serviceId)) {
        throw const FormatException('Combo có thành phần không còn khả dụng.');
      }
      for (var copy = 0; copy < component.quantity; copy++) {
        lines.add({
          'serviceId': component.serviceId,
          'comboId': combo.id,
          'expectedPrice': 0,
        });
      }
    }
  }
  if (lines.isEmpty) {
    throw const FormatException('Chọn ít nhất một dịch vụ hoặc combo.');
  }
  return lines;
}

int bookingDurationMinutes(
  List<Map<String, dynamic>> lines,
  Iterable<Service> services,
) {
  final available = {for (final service in services) service.id: service};
  return lines.fold(0, (sum, line) {
    final service = available[line['serviceId']];
    if (service == null) {
      throw const FormatException('Không xác định được thời lượng dịch vụ.');
    }
    return sum + (service.durationMinutes > 0 ? service.durationMinutes : 30);
  });
}

class AvailableAppointmentSlot {
  final int staffId;
  final DateTime start;
  final DateTime end;

  const AvailableAppointmentSlot({
    required this.staffId,
    required this.start,
    required this.end,
  });

  factory AvailableAppointmentSlot.fromJson(
    Map<String, dynamic> json,
    DateTime date,
  ) {
    DateTime time(dynamic value) {
      final parts = (value as String).split(':');
      if (parts.length < 2 || parts.length > 3) {
        throw const FormatException('Invalid slot time.');
      }
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final second = parts.length == 3 ? int.parse(parts[2]) : 0;
      if (hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          second < 0 ||
          second > 59) {
        throw const FormatException('Invalid slot time.');
      }
      return DateTime(date.year, date.month, date.day, hour, minute, second);
    }

    final staffId = (json['nhanVienId'] as num).toInt();
    final start = time(json['gioBatDau']);
    final end = time(json['gioKetThuc']);
    if (staffId <= 0 || !end.isAfter(start)) {
      throw const FormatException('Invalid availability slot.');
    }
    return AvailableAppointmentSlot(staffId: staffId, start: start, end: end);
  }
}
