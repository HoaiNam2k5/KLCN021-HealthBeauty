import 'dart:io';

import 'package:app_doancunhan/models/availability_day.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final day = AvailableAppointmentDay.fromJson({
    'date': '2030-01-02',
    'startTimes': ['10:00:00', '09:00:00', '10:00:00'],
  });
  check(
    day.starts.length == 2 && day.starts.first == DateTime(2030, 1, 2, 9),
    'Local time sorting and deduplication',
  );
  var starts = bookableAvailabilityStarts(
    [day],
    now: DateTime(2030),
    canBookDate: (_) => true,
    hasConflict: (start) => start.hour == 9,
  );
  check(
    starts.single == DateTime(2030, 1, 2, 10),
    'Later same-day slot remains after customer conflict',
  );
  starts = bookableAvailabilityStarts(
    [day],
    now: DateTime(2030),
    canBookDate: (_) => false,
    hasConflict: (_) => false,
  );
  check(starts.isEmpty, 'Expired combo day excluded');
  starts = bookableAvailabilityStarts(
    [day],
    now: DateTime(2030, 1, 2, 10),
    canBookDate: (_) => true,
    hasConflict: (_) => false,
  );
  check(starts.isEmpty, 'Past and current start excluded');
  final later = AvailableAppointmentDay.fromJson({
    'date': '2030-01-03',
    'startTimes': ['08:00:00'],
  });
  starts = bookableAvailabilityStarts(
    [later, day],
    now: DateTime(2030),
    canBookDate: (_) => true,
    hasConflict: (_) => false,
  );
  check(
    starts.first == DateTime(2030, 1, 2, 9),
    'Nearest works with unsorted API dates',
  );
  var rejected = 0;
  for (final row in [
    {'date': '2030-02-30', 'startTimes': []},
    {
      'date': '2030-01-01',
      'startTimes': ['24:00:00'],
    },
    {
      'date': '2030-01-01',
      'startTimes': ['09:60:00'],
    },
  ]) {
    try {
      AvailableAppointmentDay.fromJson(row);
    } on FormatException {
      rejected++;
    }
  }
  check(rejected == 3, 'Invalid dates and times rejected');
  stdout.writeln('AVAILABILITY_CALENDAR_CONTRACT: 6/6 PASS');
}
