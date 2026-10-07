class Attendance {
  final String date; // yyyy-MM-dd (tanggal MULAI shift)
  final String? checkIn; // HH:mm
  final String? checkOut; // HH:mm
  final String status; // Hadir | Terlambat | Izin | Alpa
  final String? office; // tempat absen / jenis izin
  final double? distance; // jarak (m) saat absen
  final String? shift; // nama shift
  final String email; // pemilik record (untuk validasi jadwal lembur & tabel peserta)
  final String mode; // WFO | WFH | DINAS
  final int breakMin; // menit istirahat (dikurangi dari jam kerja)
  final int lateMin; // menit terlambat (untuk potongan gaji)

  /// Jam kerja sesuai jadwal shift karyawan hari itu (HH:mm–HH:mm), untuk UI/dashboard.
  final String? scheduledStart, scheduledEnd;
  final int toleranceMin; // toleransi keterlambatan dari shift yang dijadwalkan

  /// Lembur tervalidasi dari tabel jadwal lembur (Terjadwal/On-Call), bukan pengajuan mandiri.
  final bool overtimeScheduled;
  final bool overtimeAttended; // sudah absen lembur (check in/out sesi lembur)
  final String? overtimeTitle, overtimeKind;
  final String? overtimeStart, overtimeEnd; // HH:mm sesi lembur terjadwal
  final double overtimeRateX;

  /// Kehadiran meeting/pelatihan yang diundang (validasi dari tabel peserta).
  final List<String> eventTitles;

  Attendance({
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.office,
    this.distance,
    this.shift,
    this.email = '',
    this.mode = 'WFO',
    this.breakMin = 0,
    this.lateMin = 0,
    this.scheduledStart,
    this.scheduledEnd,
    this.toleranceMin = 0,
    this.overtimeScheduled = false,
    this.overtimeAttended = false,
    this.overtimeTitle,
    this.overtimeKind,
    this.overtimeStart,
    this.overtimeEnd,
    this.overtimeRateX = 0,
    this.eventTitles = const [],
  });

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        date: j['date'] ?? '',
        checkIn: j['check_in'],
        checkOut: j['check_out'],
        status: j['status'] ?? 'Hadir',
        office: j['office'],
        distance: (j['distance_m'] as num?)?.toDouble(),
        shift: j['shift'],
        email: j['email'] ?? '',
        mode: j['mode'] ?? 'WFO',
        breakMin: (j['break_min'] as num?)?.toInt() ?? 0,
        lateMin: (j['late_min'] as num?)?.toInt() ?? 0,
        scheduledStart: j['scheduled_start'],
        scheduledEnd: j['scheduled_end'],
        toleranceMin: (j['tolerance_min'] as num?)?.toInt() ?? 0,
        overtimeScheduled: j['overtime_scheduled'] == true,
        overtimeAttended: j['overtime_attended'] == true,
        overtimeTitle: j['overtime_title'],
        overtimeKind: j['overtime_kind'],
        overtimeStart: j['overtime_start'],
        overtimeEnd: j['overtime_end'],
        overtimeRateX: (j['overtime_rate_x'] as num?)?.toDouble() ?? 0,
        eventTitles: (j['event_titles'] as List?)?.cast<String>() ?? const [],
      );

  Attendance copyWith({String? checkOut}) => Attendance(
        date: date,
        checkIn: checkIn,
        checkOut: checkOut ?? this.checkOut,
        status: status,
        office: office,
        distance: distance,
        shift: shift,
        email: email,
        mode: mode,
        breakMin: breakMin,
        lateMin: lateMin,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        toleranceMin: toleranceMin,
        overtimeScheduled: overtimeScheduled,
        overtimeAttended: overtimeAttended,
        overtimeTitle: overtimeTitle,
        overtimeKind: overtimeKind,
        overtimeStart: overtimeStart,
        overtimeEnd: overtimeEnd,
        overtimeRateX: overtimeRateX,
        eventTitles: eventTitles,
      );

  /// Jam kerja SESUAI JADWAL shift masing-masing karyawan (tanpa istirahat).
  Duration get scheduledDuration {
    if (scheduledStart == null || scheduledEnd == null) return Duration.zero;
    int m(String s) {
      final x = s.split(':');
      return int.parse(x[0]) * 60 + int.parse(x[1]);
    }

    var d = m(scheduledEnd!) - m(scheduledStart!);
    if (d <= 0) d += 1440; // shift malam melewati tengah malam
    return Duration(minutes: d);
  }

  /// Jam kerja bersih (sudah dikurangi istirahat, aman untuk shift lewat tengah malam).
  Duration? get duration {
    if (checkIn == null || checkOut == null) return null;
    int m(String s) {
      final x = s.split(':');
      return int.parse(x[0]) * 60 + int.parse(x[1]);
    }

    var d = m(checkOut!) - m(checkIn!);
    if (d < 0) d += 1440;
    d -= breakMin;
    return Duration(minutes: d < 0 ? 0 : d);
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'email': email,
        'check_in': checkIn,
        'check_out': checkOut,
        'status': status,
        'office': office,
        'distance_m': distance,
        'shift': shift,
        'mode': mode,
        'break_min': breakMin,
        'late_min': lateMin,
        'scheduled_start': scheduledStart,
        'scheduled_end': scheduledEnd,
        'tolerance_min': toleranceMin,
        'overtime_scheduled': overtimeScheduled,
        'overtime_attended': overtimeAttended,
        'overtime_title': overtimeTitle,
        'overtime_kind': overtimeKind,
        'overtime_start': overtimeStart,
        'overtime_end': overtimeEnd,
        'overtime_rate_x': overtimeRateX,
        'event_titles': eventTitles,
      };
}
