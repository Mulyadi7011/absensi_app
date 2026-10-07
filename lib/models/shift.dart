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

  String get hours => '$start - $end';
  String get breakLabel => '$breakStart - $breakEnd';
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
  final List<String> tags; // WFH, Dinas Luar, Cuti, Lembur 17:00-20:00, ...
  final List<String> events; // judul Meeting/Pelatihan yang diundang hari itu
  const DaySchedule(this.date, this.shift, this.tags, [this.events = const []]);
}

/// Parser tanggal untuk data demo: mendukung format absolut ISO ("2026-10-07T17:30")
/// maupun relatif ("today HH:mm" / "tomorrow HH:mm").
class ShiftParser {
  static DateTime parseWhen(String s, {DateTime? today}) {
    final t = today ?? DateTime.now();
    final m = RegExp(r'^(today|tomorrow) (\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m != null) {
      final base = DateTime(t.year, t.month, t.day)
          .add(Duration(days: m.group(1) == 'tomorrow' ? 1 : 0));
      return base.add(Duration(hours: int.parse(m.group(2)!), minutes: int.parse(m.group(3)!)));
    }
    return DateTime.parse(s);
  }
}

/// Jadwal lembur dari tabel "lembur" (kalender perusahaan): terjadwal atau on-call.
/// Bukan pengajuan mandiri - kehadiran lembur divalidasi lewat absen lembur pada event ini.
class OvertimeSchedule {
  static const typeScheduled = 'Terjadwal';
  static const typeOnCall = 'On-Call';
  static const types = [typeScheduled, typeOnCall];

  final String id, title, kind; // kind: Terjadwal | On-Call
  final DateTime start, end;
  final List<String> participants; // email yang dijadwalkan/on-call (tabel peserta)
  final double rateX; // pengali upah lembur untuk sesi ini

  const OvertimeSchedule({
    required this.id,
    required this.title,
    required this.kind,
    required this.start,
    required this.end,
    required this.participants,
    this.rateX = 1.5,
  });

  factory OvertimeSchedule.fromJson(Map<String, dynamic> j) => OvertimeSchedule(
        id: '${j['id']}',
        title: j['title'] ?? '',
        kind: j['kind'] ?? typeScheduled,
        start: ShiftParser.parseWhen(j['start']),
        end: ShiftParser.parseWhen(j['end']),
        participants: (j['participants'] as List).cast<String>(),
        rateX: (j['rate_x'] as num?)?.toDouble() ?? 1.5,
      );

  bool get crossesMidnight => end.day != start.day || end.month != start.month;
  bool involves(String email) =>
      participants.any((e) => e.toLowerCase() == email.toLowerCase());

  double get hours {
    var d = end.difference(start).inMinutes;
    if (d < 0) d += 1440;
    return d / 60.0;
  }
}
