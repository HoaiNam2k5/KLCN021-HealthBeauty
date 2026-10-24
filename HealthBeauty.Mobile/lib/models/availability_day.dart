class AvailableAppointmentDay {
  final DateTime date;
  final List<DateTime> starts;

  const AvailableAppointmentDay({required this.date, required this.starts});

  factory AvailableAppointmentDay.fromJson(Map<String, dynamic> json) {
    final value = json['date'] as String;
    final date = DateTime.parse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        date.toIso8601String().split('T').first != value) {
      throw const FormatException('Invalid availability date.');
    }
    final starts =
        (json['startTimes'] as List)
            .map((raw) {
              final parts = (raw as String).split(':');
              if (parts.length < 2 || parts.length > 3) {
                throw const FormatException('Invalid availability time.');
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
                throw const FormatException('Invalid availability time.');
              }
              return DateTime(
                date.year,
                date.month,
                date.day,
                hour,
                minute,
                second,
              );
            })
            .toSet()
            .toList()
          ..sort();
    return AvailableAppointmentDay(date: date, starts: starts);
  }
}

/// Use the same filtered starts for calendar markers and nearest-date selection.
List<DateTime> bookableAvailabilityStarts(
  Iterable<AvailableAppointmentDay> days, {
  required DateTime now,
  required bool Function(DateTime) canBookDate,
  required bool Function(DateTime) hasConflict,
}) =>
    days
        .where((day) => canBookDate(day.date))
        .expand((day) => day.starts)
        .where((start) => start.isAfter(now) && !hasConflict(start))
        .toSet()
        .toList()
      ..sort();
