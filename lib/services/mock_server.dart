import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/notification.dart';
import '../models/office.dart';
import '../models/pengajuan.dart';
import '../models/rekap.dart';
import '../models/shift.dart';

/// Meniru backend memakai file JSON di assets/data/.
/// Semua aturan bisnis ada DI SINI (bukan di UI) supaya mudah dipindah ke backend.
class MockServer {
  static bool _ready = false;
  static late Map<String, dynamic> _rules, _pay, _patterns;
  static late List<Office> _offices;
  static late List<Map<String, dynamic>> _users;
  static late Map<String, Shift> _shifts;
  static final Map<String, Map<String, Attendance>> _records = {};
  static late List<Pengajuan> _requests;
  static late List<AppNotification> _notifs;
  static int _seq = 100;

  static final _df = DateFormat('yyyy-MM-dd');
  static final _tf = DateFormat('HH:mm');
  static DateTime _d(String s) => DateTime.parse(s);
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static int _m(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static Future<dynamic> _json(String f) async =>
      jsonDecode(await rootBundle.loadString('assets/data/$f'));

  static Future<void> init() async {
    if (_ready) return;
    final cfg = await _json('offices.json');
    _rules = cfg['rules'];
    _offices = (cfg['offices'] as List).map((e) => Office.fromJson(e)).toList();
    _users = ((await _json('users.json')) as List).cast<Map<String, dynamic>>();
    final sh = await _json('shifts.json');
    _shifts = {for (final s in sh['shifts']) s['id'] as String: Shift.fromJson(s)};
    _patterns = Map<String, dynamic>.from(sh['patterns']);
    _pay = await _json('payroll.json');

    // riwayat dummy (hanya untuk user ber-flag seed_history)
    final h = (await _json('history.json')) as List;
    final today = _day(DateTime.now());
    for (final u in _users) {
      final email = u['email'] as String;
      final recs = _records.putIfAbsent(email, () => {});
      if (u['seed_history'] != true) continue;
      for (final e in h) {
        final m = Map<String, dynamic>.from(e);
        final date = today.subtract(Duration(days: m['days_ago'] as int));
        final s = _shiftOn(email, date);
        if (s == null) continue; // lewati hari libur
        m['date'] = _df.format(date);
        if (m['status'] == 'Hadir' || m['status'] == 'Terlambat') {
          m['shift'] = s.name;
          m['mode'] = 'WFO';
          m['break_min'] = s.breakMinutes;
          if (m['status'] == 'Terlambat') m['late_min'] = _m(m['check_in']) - _m(s.start);
        }
        recs[m['date']] = Attendance.fromJson(m);
      }
    }

    final rq = (await _json('requests.json')) as List;
    _requests = rq.map((e) {
      final m = Map<String, dynamic>.from(e);
      m['start_date'] = _df.format(today.add(Duration(days: m['start_offset'] as int)));
      m['end_date'] = _df.format(today.add(Duration(days: m['end_offset'] as int)));
      return Pengajuan.fromJson(m);
    }).toList();

    final nt = (await _json('notifications.json')) as List;
    _notifs = nt
        .map((e) => AppNotification(
              id: 'N${_seq++}',
              email: e['email'],
              title: e['title'],
              body: e['body'],
              kind: e['kind'],
              time: DateTime.now().subtract(Duration(minutes: e['minutes_ago'] as int)),
              read: e['read'] == true,
            ))
        .toList();
    _ready = true;
  }

  // ---------------- helper ----------------
  static Map<String, dynamic> _user(String email) => _users.firstWhere(
        (u) => u['email'] == email,
        orElse: () => throw Exception('Pengguna tidak ditemukan. Silakan login ulang.'),
      );

  static Office _office(String email) => _offices.firstWhere(
        (o) => o.id == _user(email)['office_id'],
        orElse: () => throw Exception('Kantor tidak ditemukan. Silakan login ulang.'),
      );

  static Shift? _shiftOn(String email, DateTime d) {
    final list = _patterns[email] as List?;
    final id = list == null ? null : list[d.weekday - 1];
    return id == null ? null : _shifts[id];
  }

  static bool _hasApproved(String email, String type, DateTime date) =>
      _requests.any((r) =>
          r.userEmail == email &&
          r.type == type &&
          r.status == 'Disetujui' &&
          !date.isBefore(_d(r.startDate)) &&
          !date.isAfter(_d(r.endDate)));

  static ShiftInstance _make(DateTime day, Shift s) {
    final a = s.start.split(':'), b = s.end.split(':');
    final start = DateTime(day.year, day.month, day.day, int.parse(a[0]), int.parse(a[1]));
    var end = DateTime(day.year, day.month, day.day, int.parse(b[0]), int.parse(b[1]));
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1)); // shift malam
    return ShiftInstance(day, s, start, end);
  }

  /// Shift yang sedang berlaku. Jendela absen: 3 jam sebelum mulai s/d 3 jam setelah selesai.
  /// Shift malam yang dimulai kemarin tetap dikenali setelah lewat tengah malam.
  static ShiftInstance? _instance(String email, DateTime now) {
    final today = _day(now);
    for (final day in [today, today.subtract(const Duration(days: 1))]) {
      final s = _shiftOn(email, day);
      if (s == null) continue;
      final i = _make(day, s);
      if (!now.isBefore(i.start.subtract(const Duration(hours: 3))) &&
          !now.isAfter(i.end.add(const Duration(hours: 3)))) {
        return i;
      }
    }
    if (_rules['enforce_shift_window'] == true) return null;
    // mode dev: tetap boleh absen di luar jendela (pakai shift hari ini)
    return _make(today, _shiftOn(email, today) ?? _shifts.values.first);
  }

  static double _rad(double d) => d * pi / 180;

  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(a));
  }

  // ---------------- auth ----------------
  static Future<Map<String, dynamic>> login(String email, String password) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 600));
    final found = _users.where(
        (u) => u['email'] == email.toLowerCase() && u['password'] == password);
    if (found.isEmpty) throw Exception('Email atau password salah');
    return found.first;
  }

  static Future<Office> office(String id) async {
    await init();
    return _offices.firstWhere(
      (o) => o.id == id,
      orElse: () => throw Exception('Kantor tidak ditemukan. Silakan keluar lalu login ulang.'),
    );
  }

  // ---------------- shift & jadwal ----------------
  static Future<ShiftInstance?> currentShift(String email) async {
    await init();
    return _instance(email, DateTime.now());
  }

  static Future<List<String>> allowedModes(String email) async {
    await init();
    final date = _instance(email, DateTime.now())?.date ?? _day(DateTime.now());
    return [
      'WFO',
      if (_hasApproved(email, 'WFH', date)) 'WFH',
      if (_hasApproved(email, 'Dinas Luar', date)) 'DINAS',
    ];
  }

  static Future<List<DaySchedule>> schedule(String email, int days) async {
    await init();
    final today = _day(DateTime.now());
    return List.generate(days, (i) {
      final d = today.add(Duration(days: i));
      final tags = <String>[];
      for (final r in _requests) {
        if (r.userEmail != email || r.status != 'Disetujui') continue;
        if (d.isBefore(_d(r.startDate)) || d.isAfter(_d(r.endDate))) continue;
        if (r.type == 'Lembur') {
          tags.add('Lembur ${r.startTime}–${r.endTime}');
        } else if (r.type != 'Koreksi Absen') {
          tags.add(r.type);
        }
      }
      return DaySchedule(d, _shiftOn(email, d), tags);
    });
  }

  // ---------------- absensi ----------------
  static Future<Attendance?> today(String email) async {
    await init();
    final inst = _instance(email, DateTime.now());
    if (inst == null) return null;
    return _records[email]?[_df.format(inst.date)];
  }

  static Future<List<Attendance>> history(String email) async {
    await init();
    final l = (_records[email] ?? {}).values.toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  /// Validasi lokasi sesuai mode: WFO (radius kantor), WFH (pengajuan + radius rumah),
  /// DINAS (pengajuan disetujui, lokasi hanya dicatat). Mengembalikan jarak (m) bila relevan.
  static double? _validate(String email, String mode, ShiftInstance inst, Map<String, dynamic> p) {
    if (p['is_mocked'] == true) {
      throw Exception('Terdeteksi lokasi palsu (Fake GPS). Nonaktifkan aplikasi mock location.');
    }
    final acc = (p['accuracy'] as num).toDouble();
    if (acc > (_rules['max_accuracy_m'] as num)) {
      throw Exception('Akurasi GPS rendah (${acc.round()} m). Pindah ke area terbuka lalu coba lagi.');
    }
    final lat = p['latitude'] as double, lng = p['longitude'] as double;

    if (mode == 'DINAS') {
      if (!_hasApproved(email, 'Dinas Luar', inst.date)) {
        throw Exception('Tidak ada pengajuan Dinas Luar yang disetujui untuk hari ini.');
      }
      return null;
    }
    if (mode == 'WFH') {
      if (!_hasApproved(email, 'WFH', inst.date)) {
        throw Exception('Tidak ada pengajuan WFH yang disetujui untuk hari ini.');
      }
      final h = _user(email)['home'];
      final d = distance(lat, lng, h['latitude'], h['longitude']);
      if (d > (h['radius_m'] as num)) {
        throw Exception('Anda ${d.round()} m dari lokasi rumah terdaftar. Maksimal ${h['radius_m']} m.');
      }
      return d;
    }
    final o = _office(email);
    final d = distance(lat, lng, o.latitude, o.longitude);
    if (d > o.radiusM) {
      throw Exception('Anda ${d.round()} m dari ${o.name}. Maksimal ${o.radiusM.round()} m.');
    }
    return d;
  }

  static Future<Attendance> checkIn(String email, String mode, Map<String, dynamic> p) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    final inst = _instance(email, now);
    if (inst == null) {
      throw Exception('Di luar jadwal shift. Check in dibuka 3 jam sebelum shift mulai.');
    }
    final key = _df.format(inst.date);
    final recs = _records.putIfAbsent(email, () => {});
    if (recs[key]?.checkIn != null) throw Exception('Anda sudah check in untuk shift ini');

    final d = _validate(email, mode, inst, p);
    final late = now.isAfter(inst.start.add(Duration(minutes: inst.shift.toleranceMin)));
    return recs[key] = Attendance(
      date: key,
      checkIn: _tf.format(now),
      status: late ? 'Terlambat' : 'Hadir',
      office: mode == 'WFH' ? 'Rumah (WFH)' : mode == 'DINAS' ? 'Dinas Luar' : _office(email).name,
      distance: d,
      shift: inst.shift.name,
      mode: mode,
      breakMin: inst.shift.breakMinutes,
      lateMin: late ? now.difference(inst.start).inMinutes : 0,
    );
  }

  static Future<Attendance> checkOut(String email, Map<String, dynamic> p) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 400));
    final inst = _instance(email, DateTime.now());
    if (inst == null) throw Exception('Di luar jadwal shift.');
    final key = _df.format(inst.date);
    final rec = _records[email]?[key];
    if (rec == null || rec.checkIn == null) throw Exception('Anda belum check in untuk shift ini');
    if (rec.checkOut != null) throw Exception('Anda sudah check out untuk shift ini');
    _validate(email, rec.mode, inst, p);
    return _records[email]![key] = rec.copyWith(checkOut: _tf.format(DateTime.now()));
  }

  // ---------------- pengajuan & persetujuan ----------------
  static int _usedCuti(String email) => _requests
      .where((r) => r.userEmail == email && r.type == 'Cuti' && r.status != 'Ditolak')
      .fold(0, (s, r) => s + r.days);

  static Future<List<int>> leaveBalance(String email) async {
    await init();
    return [_rules['leave_quota'] as int, _usedCuti(email)];
  }

  static Future<List<Pengajuan>> requests(String email) async {
    await init();
    return _requests.where((r) => r.userEmail == email).toList();
  }

  static Future<List<Pengajuan>> approvals(String email) async {
    await init();
    final mine = _requests.where((r) => r.approver == email).toList();
    return [
      ...mine.where((r) => r.status == 'Menunggu'),
      ...mine.where((r) => r.status != 'Menunggu'),
    ];
  }

  static Future<void> submitRequest(
    String email, {
    required String type,
    required DateTime start,
    required DateTime end,
    String? startTime,
    String? endTime,
    required String reason,
    String? attachment,
  }) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 500));
    final days = end.difference(start).inDays + 1;
    final today = _day(DateTime.now());

    if (type == 'Cuti' && _usedCuti(email) + days > (_rules['leave_quota'] as int)) {
      throw Exception('Sisa cuti tidak cukup untuk $days hari.');
    }
    if (type == 'Sakit' && days > 1 && attachment == null) {
      throw Exception('Sakit lebih dari 1 hari wajib melampirkan surat dokter.');
    }
    if (type == 'Lembur' || type == 'Koreksi Absen') {
      if (startTime == null || endTime == null) throw Exception('Jam wajib diisi.');
    }
    if (type == 'Lembur') {
      var mins = _m(endTime!) - _m(startTime!);
      if (mins <= 0) mins += 1440;
      if (mins > 240) throw Exception('Lembur maksimal 4 jam per hari.');
    }
    if (type == 'Koreksi Absen') {
      if (!_day(start).isBefore(today)) throw Exception('Koreksi hanya untuk tanggal yang sudah lewat.');
      if (today.difference(_day(start)).inDays > 7) {
        throw Exception('Koreksi maksimal 7 hari ke belakang.');
      }
    }
    const leaveLike = ['Izin', 'Sakit', 'Cuti'];
    for (final x in _requests) {
      if (x.userEmail != email || x.status == 'Ditolak') continue;
      final sameKind = leaveLike.contains(type) && leaveLike.contains(x.type);
      final sameCorrection = type == 'Koreksi Absen' && x.type == type;
      if ((sameKind || sameCorrection) &&
          !end.isBefore(_d(x.startDate)) &&
          !start.isAfter(_d(x.endDate))) {
        throw Exception('Tanggal bertabrakan dengan pengajuan lain.');
      }
    }

    final u = _user(email);
    final approver = u['approver'] as String?;
    final r = Pengajuan(
      id: 'R${_seq++}',
      userEmail: email,
      userName: u['name'],
      type: type,
      startDate: _df.format(start),
      endDate: _df.format(end),
      startTime: startTime,
      endTime: endTime,
      reason: reason,
      attachment: attachment,
      approver: approver,
      status: approver == null ? 'Disetujui' : 'Menunggu',
      approverNote: approver == null ? 'Disetujui otomatis (tanpa atasan)' : null,
    );
    _requests.insert(0, r);
    if (approver == null) {
      _applyEffects(r);
    } else {
      _notify(approver, 'Pengajuan baru', '${u['name']} mengajukan $type.', 'approval');
    }
  }

  static Future<void> decide(String email, String id, bool approve, String note) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _requests.indexWhere((r) => r.id == id);
    if (i < 0) throw Exception('Pengajuan tidak ditemukan.');
    final r = _requests[i];
    if (r.approver != email) throw Exception('Anda bukan approver pengajuan ini.');
    if (r.status != 'Menunggu') throw Exception('Pengajuan sudah diproses.');
    final n = r.copyWith(
        status: approve ? 'Disetujui' : 'Ditolak', approverNote: note.isEmpty ? null : note);
    _requests[i] = n;
    if (approve) _applyEffects(n);
    _notify(
      r.userEmail,
      approve ? 'Pengajuan disetujui' : 'Pengajuan ditolak',
      '${r.type} ${approve ? 'disetujui' : 'ditolak'}${note.isEmpty ? '' : ': $note'}',
      'info',
    );
  }

  /// Dampak pengajuan yang disetujui terhadap data absensi.
  static void _applyEffects(Pengajuan r) {
    final recs = _records.putIfAbsent(r.userEmail, () => {});
    if (r.type == 'Koreksi Absen') {
      final s = _shiftOn(r.userEmail, _d(r.startDate)) ?? _shifts.values.first;
      final late = _m(r.startTime!) - _m(s.start);
      final isLate = late > s.toleranceMin;
      recs[r.startDate] = Attendance(
        date: r.startDate,
        checkIn: r.startTime,
        checkOut: r.endTime,
        status: isLate ? 'Terlambat' : 'Hadir',
        office: _office(r.userEmail).name,
        shift: s.name,
        breakMin: s.breakMinutes,
        lateMin: isLate ? late : 0,
      );
    } else if (['Izin', 'Sakit', 'Cuti'].contains(r.type)) {
      final today = _day(DateTime.now());
      for (var d = _d(r.startDate); !d.isAfter(_d(r.endDate)); d = d.add(const Duration(days: 1))) {
        if (d.isAfter(today) || _shiftOn(r.userEmail, d) == null) continue;
        recs[_df.format(d)] = Attendance(date: _df.format(d), status: 'Izin', office: r.type);
      }
    }
    // Lembur / WFH / Dinas Luar: dibaca langsung dari daftar pengajuan (payroll & validasi absen)
  }

  // ---------------- notifikasi ----------------
  static void _notify(String email, String title, String body, String kind) {
    _notifs.insert(
      0,
      AppNotification(
          id: 'N${_seq++}', email: email, title: title, body: body, kind: kind,
          time: DateTime.now(), read: false),
    );
  }

  static Future<List<AppNotification>> notifications(String email) async {
    await init();
    final l = _notifs.where((n) => n.email == email).toList();
    l.sort((a, b) => b.time.compareTo(a.time));
    return l;
  }

  static Future<int> unread(String email) async {
    await init();
    return _notifs.where((n) => n.email == email && !n.read).length;
  }

  static Future<void> markAllRead(String email) async {
    await init();
    for (var i = 0; i < _notifs.length; i++) {
      if (_notifs[i].email == email && !_notifs[i].read) {
        _notifs[i] = _notifs[i].copyWith(read: true);
      }
    }
  }

  // ---------------- rekap & payroll ----------------
  static Future<Rekap> recap(String email, int year, int month) async {
    await init();
    final salary = (_user(email)['salary'] as num).toDouble();
    final recs = (_records[email] ?? {}).values.where((a) {
      final d = _d(a.date);
      return d.year == year && d.month == month;
    }).toList();
    int c(String s) => recs.where((a) => a.status == s).length;
    final hadir = c('Hadir'), telat = c('Terlambat'), izin = c('Izin'), alpa = c('Alpa');
    final workMin = recs.fold<int>(0, (s, a) => s + (a.duration?.inMinutes ?? 0));
    final lateMin = recs.fold<int>(0, (s, a) => s + a.lateMin);

    final ot = _requests
        .where((r) =>
            r.userEmail == email &&
            r.type == 'Lembur' &&
            r.status == 'Disetujui' &&
            _d(r.startDate).year == year &&
            _d(r.startDate).month == month)
        .map((r) => OvertimeItem(r.startDate, r.startTime!, r.endTime!, r.overtimeHours))
        .toList();
    final otHours = ot.fold<double>(0, (s, i) => s + i.hours);

    // Lembur: jam pertama 1,5x, jam berikutnya 2x (upah per jam = gaji / 173)
    final hourly = salary / (_pay['overtime_divisor'] as num);
    var otPay = 0.0;
    for (final i in ot) {
      final first = min(i.hours, 1.0), rest = max(0.0, i.hours - 1.0);
      otPay += hourly * (first * (_pay['overtime_first_hour_x'] as num) +
          rest * (_pay['overtime_next_hour_x'] as num));
    }

    return Rekap(
      year: year,
      month: month,
      hadir: hadir,
      terlambat: telat,
      izin: izin,
      alpa: alpa,
      workMinutes: workMin,
      lateMinutes: lateMin,
      overtimeHours: otHours,
      overtime: ot,
      baseSalary: salary,
      mealAllowance: (hadir + telat) * (_pay['meal_allowance_per_day'] as num).toDouble(),
      overtimePay: otPay,
      lateDeduction: lateMin * (_pay['late_deduction_per_min'] as num).toDouble(),
      alpaDeduction: alpa * salary / (_pay['working_days'] as num),
    );
  }
}
