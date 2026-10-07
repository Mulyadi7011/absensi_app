class Attendance {
  final String date; // yyyy-MM-dd (tanggal MULAI shift)
  final String? checkIn; // HH:mm
  final String? checkOut; // HH:mm
  final String status; // Hadir | Terlambat | Izin | Alpa
  final String? office; // tempat absen / jenis izin
  final double? distance; // jarak (m) saat absen
  final String? shift; // nama shift
  final String mode; // WFO | WFH | DINAS
  final int breakMin; // menit istirahat (dikurangi dari jam kerja)
  final int lateMin; // menit terlambat (untuk potongan gaji)

  Attendance({
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.office,
    this.distance,
    this.shift,
    this.mode = 'WFO',
    this.breakMin = 0,
    this.lateMin = 0,
  });

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        date: j['date'] ?? '',
        checkIn: j['check_in'],
        checkOut: j['check_out'],
        status: j['status'] ?? 'Hadir',
        office: j['office'],
        distance: (j['distance_m'] as num?)?.toDouble(),
        shift: j['shift'],
        mode: j['mode'] ?? 'WFO',
        breakMin: (j['break_min'] as num?)?.toInt() ?? 0,
        lateMin: (j['late_min'] as num?)?.toInt() ?? 0,
      );

  Attendance copyWith({String? checkOut}) => Attendance(
        date: date,
        checkIn: checkIn,
        checkOut: checkOut ?? this.checkOut,
        status: status,
        office: office,
        distance: distance,
        shift: shift,
        mode: mode,
        breakMin: breakMin,
        lateMin: lateMin,
      );

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
}
