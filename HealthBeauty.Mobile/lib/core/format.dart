/// Các hàm định dạng dùng chung (không cần gói intl).
library;

String two(int n) => n.toString().padLeft(2, '0');

/// 650000 -> "650.000 ₫"
String vnd(num v) {
  final s = v.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write('.');
  }
  return '${v < 0 ? '-' : ''}$buf ₫';
}

String timeStr(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dateStr(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

const weekdayVi = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// DateTime.weekday: 1 = Thứ Hai ... 7 = Chủ nhật
String weekdayStr(DateTime d) => weekdayVi[d.weekday - 1];

String durationStr(int minutes) {
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
