import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/event.dart';
import '../models/shift.dart' show OvertimeSchedule;
import '../services/api_service.dart';
import '../services/location_service.dart';

/// Layar "Absen Sesi": Lembur Terjadwal/On-Call + Absensi Meeting & Pelatihan.
/// Seluruh validasi dilakukan "server" (MockServer) berdasar TABEL peserta —
/// user yang tidak ada di tabel peserta tidak akan bisa absen.
class AttendanceSessionsScreen extends StatefulWidget {
  const AttendanceSessionsScreen({super.key});

  @override
  State<AttendanceSessionsScreen> createState() => _AttendanceSessionsScreenState();
}

class _AttendanceSessionsScreenState extends State<AttendanceSessionsScreen> {
  List<OvertimeSchedule> _ot = [];
  List<WorkEvent> _ev = [];
  final Map<String, EventAttendance> _att = {}; // eventId (atau 'OT:id') -> absen
  bool _loading = true;
  String? _busyKey;


  String _d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}';
  String _t(DateTime x) =>
      '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

  String _whenLabel(DateTime s, DateTime e) {
    final now = DateTime.now();
    final isToday = _sameDay(s, now);
    final day = isToday
        ? 'Hari ini'
        : (_sameDay(s, now.add(const Duration(days: 1))) ? 'Besok' : _d(s));
    final range = '$day ${_t(s)}-${_t(e)}${e.isBefore(s.add(const Duration(hours: 6))) ? '' : ' (+1h)'}';
    return range;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    final ot = await ApiService.myOvertimes();
    final ev = await ApiService.myEvents();
    final att = <String, EventAttendance>{};
    for (final o in ot) {
      final a = await ApiService.eventAttendance('OT:${o.id}');
      if (a != null) att['OT:${o.id}'] = a;
    }
    for (final e in ev) {
      final a = await ApiService.eventAttendance(e.id);
      if (a != null) att[e.id] = a;
    }
    if (!mounted) return;
    setState(() {
      _ot = ot;
      _ev = ev;
      _att
        ..clear()
        ..addAll(att);
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _doCheck(String key, bool isIn, Future<void> Function(Position) run) async {
    setState(() => _busyKey = key);
    try {
      final pos = await LocationService.current();
      await run(pos);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isIn ? 'Absen masuk berhasil dicatat.' : 'Absen keluar berhasil dicatat.')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$err'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Widget _sessionCard({
    required String key,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String when,
    required String window,
    required EventAttendance? att,
    required DateTime start,
    required DateTime endClose,
    required bool scheduled, // sudah lewat batas akhir sesi?
    required Future<void> Function(bool isIn) doIt,
  }) {
    final busy = _busyKey == key;
    final hasIn = att?.checkIn != null;
    final hasOut = att?.checkOut != null;
    final now = DateTime.now();
    // Jendela absen masuk: mulai H-15 menit s/d 1 jam setelah sesi selesai.
    final inOpen = !now.isBefore(start.subtract(const Duration(minutes: 15)));
    final canIn = !hasIn && inOpen && !now.isAfter(endClose);
    // Absen keluar baru bisa sesudah check-in (server memvalidasi batas waktunya).
    final canOut = hasIn && !hasOut && !now.isAfter(endClose);
    final statusChip = att == null
        ? (scheduled
            ? const Chip(label: Text('Belum diabsen'))
            : const Chip(label: Text('Menunggu jadwal')))
        : Chip(
            avatar: Icon(Icons.check, size: 16, color: Colors.white),
            backgroundColor: att.status == 'Hadir' ? Colors.green : Colors.orange,
            label: Text('${att.status} - masuk ${att.checkIn}${att.checkOut != null ? ' - keluar ${att.checkOut}' : ''}',
                style: const TextStyle(color: Colors.white)),
          );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: color.withOpacity(.15), child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                Text(when, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(window, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [statusChip]),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy || !canIn ? null : () => doIt(true),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: Text(hasIn ? 'Sudah absen masuk' : 'Absen Masuk'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || !canOut ? null : () => doIt(false),
                    icon: const Icon(Icons.logout),
                    label: Text(hasOut ? 'Selesai' : 'Absen Keluar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lembur & Absen Sesi'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('LEMBUR TERJADWAL / ON-CALL',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  if (_ot.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Tidak ada penugasan lembur untuk Anda (tabel peserta kosong).')),
                  ..._ot.map((o) {
                    final key = 'OT:${o.id}';
                    final close = o.end.add(const Duration(hours: 1));
                    return _sessionCard(
                      key: key,
                      icon: o.kind == OvertimeSchedule.typeOnCall ? Icons.support_agent : Icons.work_outline,
                      color: o.kind == OvertimeSchedule.typeOnCall ? Colors.deepOrange : Colors.indigo,
                      title: o.title,
                      subtitle: '${o.kind} - ${o.hours.toStringAsFixed(1)} jam - upah x${o.rateX.toStringAsFixed(1)}'
                          '${o.kind == OvertimeSchedule.typeOnCall ? ' - lokasi bebas (GPS valid)' : ' - wajib di radius kantor'}',
                      when: _whenLabel(o.start, o.end),
                      window: 'Absen dibuka H-15 menit hingga 1 jam setelah selesai.',
                      att: _att[key],
                      start: o.start,
                      endClose: close,
                      scheduled: now.isAfter(close),
                      doIt: (isIn) => _doCheck(key, isIn, (pos) async {
                        await (isIn
                            ? ApiService.overtimeCheckIn(o.id, pos)
                            : ApiService.overtimeCheckOut(o.id, pos));
                      }),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('MEETING & PELATIHAN (UNDANGAN)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  if (_ev.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Tidak ada undangan meeting/pelatihan untuk Anda.')),
                  ..._ev.map((e) {
                    final close = e.checkOutClose;
                    return _sessionCard(
                      key: e.id,
                      icon: e.icon,
                      color: e.kind == WorkEvent.kindTraining ? Colors.teal : Colors.purple,
                      title: e.title,
                      subtitle: '${e.kind} - ${e.organizer} - ${e.location}',
                      when: _whenLabel(e.start, e.end),
                      window: e.windowLabel,
                      att: _att[e.id],
                      start: e.start,
                      endClose: close,
                      scheduled: now.isAfter(close),
                      doIt: (isIn) => _doCheck(e.id, isIn, (pos) async {
                        await (isIn
                            ? ApiService.eventCheckIn(e.id, pos)
                            : ApiService.eventCheckOut(e.id, pos));
                      }),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
