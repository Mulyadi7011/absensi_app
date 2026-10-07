class Shift {
  final String id, name, start, end, breakStart, breakEnd;
  final int toleranceMin;

  const Shift({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.breakStart,
    required this.breakEnd,
    required this.toleranceMin,
  });

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'],
        name: j['name'],
        start: j['start'],
        end: j['end'],
        breakStart: j['break_start'],
        breakEnd: j['break_end'],
        toleranceMin: j['tolerance_min'],
      );

  static int _m(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool get crossesMidnight => _m(end) <= _m(start);

  int get breakMinutes {
    var d = _m(breakEnd) - _m(breakStart);
    if (d < 0) d += 1440;
    return d;
  }

  String get hours => '$start – $end';
  String get breakLabel => '$breakStart – $breakEnd';
}

/// Satu kejadian shift pada tanggal tertentu (start/end sudah berupa DateTime,
/// end otomatis +1 hari bila shift melewati tengah malam).
class ShiftInstance {
  final DateTime date, start, end;
  final Shift shift;
  const ShiftInstance(this.date, this.shift, this.start, this.end);
}

class DaySchedule {
  final DateTime date;
  final Shift? shift; // null = libur
  final List<String> tags; // WFH, Dinas Luar, Cuti, Lembur 17:00–20:00, ...
  const DaySchedule(this.date, this.shift, this.tags);
}
