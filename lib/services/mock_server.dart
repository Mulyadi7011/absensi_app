import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/event.dart';
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
  static late List<OvertimeSchedule> _overtimes;
  static late List<WorkEvent> _events;
  static final Map<String, EventAttendance> _eventAtts = {}; // key: eventId|email
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

    // tabel jadwal lembur + undangan meeting/pelatihan (kalender perusahaan)
    final ev = await _json('events.json');
    _overtimes = (ev['overtimes'] as List)
        .map((e) => OvertimeSchedule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    _events = (ev['events'] as List)
        .map((e) => WorkEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // riwayat dummy (hanya untuk user ber-flag seed_history)
    final h = (await _json('history.json')) as List;
    final today = _day(DateTime.now());
    for (final u in _users) {
      final email = u['email'] as String;
      final recs = _records.putIfAbsent(email, () => {});
      if (u['seed_history'] != true) continue;
      for (final e in h) {
        final m = Map<String, dynamic>.from(e);
        m['email'] = email;
        final date = today.subtract(Duration(days: m['days_ago'] as int));
        final s = _shiftOn(email, date);
        if (s == null) continue; // lewati hari libur
        m['date'] = _df.format(date);
        if (m['status'] == 'Hadir' || m['status'] == 'Terlambat') {
          m['shift'] = s.name;
          m['mode'] = 'WFO';
          m['break_min'] = s.breakMinutes;
          m['scheduled_start'] = s.start;
          m['scheduled_end'] = s.end;
          m['tolerance_min'] = s.toleranceMin;
          if (m['status'] == 'Terlambat') m['late_min'] = _m(m['check_in']) - _m(s.start);
        }
        // validasi event dari tabel peserta & absen yang tercatat pada sesi ini
        final dayStr = m['date'] as String;
        m['event_titles'] = _events
            .where((x) =>
                _day(x.start) == date &&
                x.participants.any((p) => p.email.toLowerCase() == email.toLowerCase()))
            .map((x) => x.title)
            .toList();
        final ot = _overtimes
            .where((x) => _otBelongsTo(x, date) && x.involves(email))
            .toList();
        if (ot.isNotEmpty) {
          final att = _eventAtts[_ek('OT:${ot.first.id}', email)];
          m['overtime_scheduled'] = true;
          m['overtime_attended'] = att?.checkIn != null;
          m['overtime_kind'] = ot.first.kind;
          m['overtime_title'] = ot.first.title;
          m['overtime_start'] = _tf.format(ot.first.start);
          m['overtime_end'] = _tf.format(ot.first.end);
          m['overtime_rate_x'] = ot.first.rateX;
        }
        recs[dayStr] = Attendance.fromJson(m);
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

  /// Tanggal "kepemilikan" record absensi untuk sesi lembur yang melewati tengah malam.
  static bool _otBelongsTo(OvertimeSchedule o, DateTime day) =>
      _day(o.start) == day || (o.crossesMidnight && _day(o.end) == day);

  static WorkEvent? _eventById(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  static String _ek(String eventId, String email) => '$eventId|$email';

  /// Jadwal kerja masing-masing karyawan pada hari [date] — sumber jam kerja & toleransi.
  static Map<String, dynamic> _workHours(String email, DateTime date) {
    final s = _shiftOn(email, date);
    return {
      'shift': s?.name,
      'scheduled_start': s?.start,
      'scheduled_end': s?.end,
      'tolerance_min': s?.toleranceMin ?? 0,
    };
  }

  /// Judul meeting/pelatihan yang diundang (validasi keanggotaan dari tabel peserta).
  static List<String> _invitedTitles(String email, DateTime date) => _events
      .where((x) => _day(x.start) == date && x.isParticipant(email))
      .map((x) => x.title)
      .toList();

  /// Info jadwal lembur (Terjadwal/On-Call) milik user pada tanggal [date], dari tabel lembur.
  static Map<String, dynamic>? _otInfoAt(String email, DateTime date) {
    final matches = _overtimes.where((o) => o.involves(email) && _otBelongsTo(o, date)).toList();
    if (matches.isEmpty) return null;
    final o = matches.first;
    final att = _eventAtts[_ek('OT:${o.id}', email)];
    return {
      'overtime_scheduled': true,
      'overtime_attended': att?.checkIn != null,
      'overtime_kind': o.kind,
      'overtime_title': o.title,
      'overtime_start': _tf.format(o.start),
      'overtime_end': _tf.format(o.end),
      'overtime_rate_x': o.rateX,
    };
  }

  Attendance _enrich(Attendance a) {
    final wh = _workHours(a.email, _d(a.date));
    final ot = _otInfoAt(a.email, _d(a.date));
    final m = a.toJson();
    for (final k in ['shift', 'scheduled_start', 'scheduled_end', 'tolerance_min']) {
      if (m[k] == null && wh[k] != null) m[k] = wh[k];
    }
    if (ot != null) {
      m['overtime_scheduled'] = ot['overtime_scheduled'];
      m['overtime_attended'] = ot['overtime_attended'];
      m['overtime_kind'] ??= ot['overtime_kind'];
      m['overtime_title'] ??= ot['overtime_title'];
      m['overtime_start'] ??= ot['overtime_start'];
      m['overtime_end'] ??= ot['overtime_end'];
      m['overtime_rate_x'] ??= ot['overtime_rate_x'];
    }
    if ((m['event_titles'] as List?)?.isEmpty ?? true) {
      m['event_titles'] = _invitedTitles(a.email, _d(a.date));
    }
    return Attendance.fromJson(m);
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
      // lembur dari TABEL jadwal lembur (Terjadwal / On-Call), bukan pengajuan mandiri
      for (final o in _overtimes) {
        if (o.involves(email) && _otBelongsTo(o, d)) {
          tags.add('${o.kind == OvertimeSchedule.typeOnCall ? 'On-Call' : 'Lembur'} '
              '${_tf.format(o.start)}–${_tf.format(o.end)}');
        }
      }
      // undangan meeting/pelatihan (validasi dari tabel peserta)
      final evts = _events
          .where((e) => _day(e.start) == d && e.isParticipant(email))
          .map((e) => '${e.kind}: ${e.title}')
          .toList();
      return DaySchedule(d, _shiftOn(email, d), tags, evts);
    });
  }

  // ---------------- absensi ----------------
  static Future<Attendance?> today(String email) async {
    await init();
    final inst = _instance(email, DateTime.now());
    if (inst == null) return null;
    final a = _records[email]?[_df.format(inst.date)];
    return a == null ? null : _enrich(a);
  }

  static Future<List<Attendance>> history(String email) async {
    await init();
    final l = (_records[email] ?? {}).values.map(_enrich).toList();
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
    final wh = {
      'scheduled_start': inst.shift.start,
      'scheduled_end': inst.shift.end,
      'tolerance_min': inst.shift.toleranceMin,
    };
    final ot = _otInfoAt(email, inst.date);
    return recs[key] = Attendance.fromJson({
      'date': key,
      'email': email,
      'check_in': _tf.format(now),
      'status': late ? 'Terlambat' : 'Hadir',
      'office': mode == 'WFH' ? 'Rumah (WFH)' : mode == 'DINAS' ? 'Dinas Luar' : _office(email).name,
      'distance_m': d,
      'shift': inst.shift.name,
      'mode': mode,
      'break_min': inst.shift.breakMinutes,
      'late_min': late ? now.difference(inst.start).inMinutes : 0,
      ...wh,
      if (ot != null) ...ot,
      'event_titles': _invitedTitles(email, inst.date),
    });
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

  // ---------------- lembur terjadwal / on-call ----------------
  /// Jadwal lembur user yang sedang/sudah berlangsung hari ini (dari tabel lembur).
  static Future<List<OvertimeSchedule>> myOvertimes(String email) async {
    await init();
    final l = _overtimes.where((o) => o.involves(email)).toList();
    l.sort((a, b) => a.start.compareTo(b.start));
    return l;
  }

  /// Check in sesi lembur — validasi dari TABEL peserta lembur (bukan pengajuan mandiri).
  static Future<EventAttendance> overtimeCheckIn(String email, String otId,
      Map<String, dynamic> p) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 400));
    final o = _overtimes.firstWhere(
      (x) => x.id == otId,
      orElse: () => throw Exception('Jadwal lembur tidak ditemukan.'),
    );
    if (!o.involves(email)) {
      throw Exception('Anda tidak terdaftar di tabel peserta lembur "${o.title}".');
    }
    final now = DateTime.now();
    if (now.isBefore(o.start.subtract(const Duration(minutes: 15)))) {
      throw Exception('Absen lembur dibuka 15 menit sebelum mulai (${_tf.format(o.start)}).');
    }
    if (now.isAfter(o.end.add(const Duration(hours: 1)))) {
      throw Exception('Absen lembur sesi ini sudah ditutup.');
    }
    final d = _otValidate(p, o);
    final key = _ek('OT:${o.id}', email);
    final prev = _eventAtts[key];
    final late = now.isAfter(o.start.add(const Duration(minutes: 10)));
    return _eventAtts[key] = EventAttendance(
      eventId: 'OT:${o.id}',
      userEmail: email,
      checkIn: prev?.checkIn ?? _tf.format(now),
      checkOut: prev?.checkOut,
      distanceM: d,
      status: late ? 'Terlambat' : 'Hadir',
    );
  }

  static Future<EventAttendance> overtimeCheckOut(String email, String otId,
      Map<String, dynamic> p) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 400));
    final o = _overtimes.firstWhere(
      (x) => x.id == otId,
      orElse: () => throw Exception('Jadwal lembur tidak ditemukan.'),
    );
    final key = _ek('OT:${o.id}', email);
    final prev = _eventAtts[key];
    if (prev == null || prev.checkIn == null) {
      throw Exception('Anda belum check in lembur pada sesi ini.');
    }
    if (prev.checkOut != null) throw Exception('Anda sudah check out lembur sesi ini.');
    if (DateTime.now().isBefore(o.end.subtract(const Duration(minutes: 15)))) {
      throw Exception('Check out lembur belum dibuka (sesi berakhir ${_tf.format(o.end)}).');
    }
    _otValidate(p, o);
    return _eventAtts[key] = EventAttendance(
      eventId: prev.eventId,
      userEmail: email,
      checkIn: prev.checkIn,
      checkOut: _tf.format(DateTime.now()),
      distanceM: prev.distanceM,
      status: prev.status,
    );
  }

  /// Validasi GPS umum: anti fake-GPS & ambang akurasi. [radiusCheck] opsional
  /// (mis. radius kantor untuk lembur terjadwal). Mengembalikan jarak (m) bila dihitung.
  static double? _gpsBase(Map<String, dynamic> p, {double Function()? distanceTo}) {
    if (p['is_mocked'] == true) {
      throw Exception('Terdeteksi lokasi palsu (Fake GPS). Nonaktifkan aplikasi mock location.');
    }
    final acc = (p['accuracy'] as num).toDouble();
    if (acc > (_rules['max_accuracy_m'] as num)) {
      throw Exception('Akurasi GPS rendah (${acc.round()} m). Pindah ke area terbuka lalu coba lagi.');
    }
    return distanceTo?.call();
  }

  /// Validasi lokasi sesi: Lembur Terjadwal wajib di radius kantor; On-Call cukup GPS valid
  /// (bisa dari rumah/mana pun — lokasi hanya dicatat). Meeting/Pelatihan (o == null):
  /// di dalam radius kantor ATAU sesuai lokasi event (lokasi dicatat tanpa batas ketat).
  static double? _otValidate(Map<String, dynamic> p, OvertimeSchedule? o, {String? location}) {
    return _gpsBase(p, distanceTo: () {
      if (o != null && o.kind == OvertimeSchedule.typeOnCall) return null;
      if (location != null && location.trim().isNotEmpty) return null; // meeting/training: dicatat
      final lat = p['latitude'] as double, lng = p['longitude'] as double;
      final officeId = p['office_id'] as String?;
      Office? off;
      for (final x in _offices) {
        if (x.id == officeId) { off = x; break; }
      }
      off ??= _offices.first; // fallback: kantor pertama (mis. payload tanpa office_id)
      final d = distance(lat, lng, off.latitude, off.longitude);
      if (d > off.radiusM) {
        throw Exception('Anda ${d.round()} m dari ${off.name}. Maksimal ${off.radiusM.round()} m.');
      }
      return d;
    });
  }

  // ---------------- meeting & pelatihan ----------------
  /// Undangan meeting/pelatihan user (validasi keanggotaan lewat tabel peserta).
  static Future<List<WorkEvent>> myEvents(String email) async {
    await init();
    final l = _events.where((e) => e.isParticipant(email)).toList();
    l.sort((a, b) => a.start.compareTo(b.start));
    return l;
  }

  static Future<EventAttendance?> eventAttendance(String email, String eventId) async {
    await init();
    return _eventAtts[_ek(eventId, email)];
  }

  /// Absen kehadiran meeting/pelatihan — HANYA boleh jika email ada di tabel peserta.
  static Future<EventAttendance> eventCheckIn(String email, String eventId,
      Map<String, dynamic> p) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 400));
    final e = _eventById(eventId) ?? throw Exception('Undangan tidak ditemukan.');
    if (!e.isParticipant(email)) {
      throw Exception('Anda tidak diundang (tidak ada di tabel peserta "${e.title}").');
    }
    final now = DateTime.now();
    if (now.isBefore(e.checkInOpen)) {
      throw Exception('Absen ${e.kind.toLowerCase()} belum dibuka (${e.windowLabel}).');
    }
    if (now.isAfter(e.checkOutClose)) {
      throw Exception('Absen ${e.kind.toLowerCase()} untuk sesi ini sudah ditutup.');
    }
    final d = _gpsBase(p); // validasi GPS; lokasi event dicatat tanpa batas radius
    final key = _ek(eventId, email);
    final prev = _eventAtts[key];
    final late = now.isAfter(e.start.add(const Duration(minutes: 10)));
    final res = _eventAtts[key] = EventAttendance(
      eventId: eventId,
      userEmail: email,
      checkIn: prev?.checkIn ?? _tf.format(now),
      checkOut: prev?.checkOut,
      distanceM: d,
      status: late ? 'Terlambat' : 'Hadir',
    );
    // catat kehadiran pada record harian bila sudah ada (validasi tabel peserta)
    final dayKey = _df.format(_day(e.start));
    final rec = _records[email]?[dayKey];
    if (rec != null && !rec.eventTitles.contains(e.title)) {
      _records[email]![dayKey] = Attendance.fromJson({
        ...rec.toJson(),
        'event_titles': [...rec.eventTitles, e.title],
      });
    }
    return res;
  }

  static Future<EventAttendance> eventCheckOut(String email, String eventId,
      Map<String, dynamic> p) async {
    await init();
    await Future.delayed(const Duration(milliseconds: 400));
    final e = _eventById(eventId) ?? throw Exception('Undangan tidak ditemukan.');
    final key = _ek(eventId, email);
    final prev = _eventAtts[key];
    if (prev == null || prev.checkIn == null) {
      throw Exception('Anda belum absen masuk pada ${e.kind.toLowerCase()} ini.');
    }
    if (prev.checkOut != null) throw Exception('Anda sudah absen keluar pada sesi ini.');
    if (DateTime.now().isAfter(e.checkOutClose)) {
      throw Exception('Absen keluar sudah ditutup (${e.windowLabel}).');
    }
    _gpsBase(p);
    return _eventAtts[key] = EventAttendance(
      eventId: eventId,
      userEmail: email,
      checkIn: prev.checkIn,
      checkOut: _tf.format(DateTime.now()),
      distanceM: prev.distanceM,
      status: prev.status,
    );
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

    if (type == 'Lembur') {
      throw Exception(
          'Lembur kini mengikuti jadwal dari tabel lembur (Terjadwal/On-Call). '
          'Absen lewat menu "Lembur & On-Call".');
    }
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
        email: r.userEmail,
        checkIn: r.startTime,
        checkOut: r.endTime,
        status: isLate ? 'Terlambat' : 'Hadir',
        office: _office(r.userEmail).name,
        shift: s.name,
        breakMin: s.breakMinutes,
        lateMin: isLate ? late : 0,
        scheduledStart: s.start,
        scheduledEnd: s.end,
        toleranceMin: s.toleranceMin,
      );
    } else if (['Izin', 'Sakit', 'Cuti'].contains(r.type)) {
      final today = _day(DateTime.now());
      for (var d = _d(r.startDate); !d.isAfter(_d(r.endDate)); d = d.add(const Duration(days: 1))) {
        if (d.isAfter(today) || _shiftOn(r.userEmail, d) == null) continue;
        recs[_df.format(d)] =
            Attendance(date: _df.format(d), email: r.userEmail, status: 'Izin', office: r.type);
      }
    }
    // WFH / Dinas Luar: dibaca langsung dari daftar pengajuan (validasi absen).
    // Lembur TIDAK lagi lewat pengajuan — sumbernya tabel jadwal lembur (Terjadwal/On-Call).
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

    // Lembur dihitung dari TABEL jadwal lembur (Terjadwal/On-Call) + absen lembur yang dilakukan.
    // Jam pertama 1,5x, jam berikutnya 2x (upah per jam = gaji / 173), dikali rate_x sesi.
    final ot = <OvertimeItem>[];
    for (final o in _overtimes) {
      if (!o.involves(email)) continue;
      final att = _eventAtts[_ek('OT:${o.id}', email)];
      if (att == null || att.checkIn == null) continue; // hanya sesi yang diabsen yang dibayar
      final dayKey = _df.format(_day(o.start));
      if (_d(dayKey).year != year || _d(dayKey).month != month) continue;
      final endT = att.checkOut != null ? _m(att.checkOut!) : _m(_tf.format(o.end));
      var mins = endT - _m(att.checkIn!);
      if (mins <= 0) mins += 1440; // sesi melewati tengah malam
      ot.add(OvertimeItem(dayKey, att.checkIn!, att.checkOut ?? _tf.format(o.end),
          mins / 60.0, kind: o.kind, title: o.title, attended: true));
    }
    final otHours = ot.fold<double>(0, (s, i) => s + i.hours);

    final hourly = salary / (_pay['overtime_divisor'] as num);
    var otPay = 0.0;
    for (final i in ot) {
      final first = min(i.hours, 1.0), rest = max(0.0, i.hours - 1.0);
      otPay += hourly * (first * (_pay['overtime_first_hour_x'] as num) +
          rest * (_pay['overtime_next_hour_x'] as num));
    }

    // Kehadiran meeting/pelatihan bulan ini (validasi dari tabel peserta)
    final evAtt = _eventAtts.values.where((a) {
      final e = _eventById(a.eventId);
      return a.userEmail == email &&
          e != null &&
          a.checkIn != null &&
          e.start.year == year &&
          e.start.month == month;
    }).toList();
    final eventAttended = evAtt.length;
    final eventInvited = _events
        .where((e) =>
            e.isParticipant(email) && e.start.year == year && e.start.month == month)
        .length;

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
      eventAttended: eventAttended,
      eventInvited: eventInvited,
      baseSalary: salary,
      mealAllowance: (hadir + telat) * (_pay['meal_allowance_per_day'] as num).toDouble(),
      overtimePay: otPay,
      lateDeduction: lateMin * (_pay['late_deduction_per_min'] as num).toDouble(),
      alpaDeduction: alpa * salary / (_pay['working_days'] as num),
    );
  }
}
