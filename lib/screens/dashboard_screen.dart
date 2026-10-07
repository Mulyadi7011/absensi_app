import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/office.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  String _name = '';
  Office? _office;
  ShiftInstance? _shift;
  List<String> _modes = ['WFO'];
  String _mode = 'WFO';
  int _unread = 0;
  ReminderSettings _rem = const ReminderSettings();
  Attendance? _today;
  List<Attendance> _history = [];
  bool _loading = true;
  bool _busy = false;

  Position? _pos;
  String? _locError;
  LocationIssue? _issue;
  bool _locBusy = false;

  static const _modeLabel = {'WFO': 'Kantor', 'WFH': 'WFH', 'DINAS': 'Dinas Luar'};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg.replaceFirst('Exception: ', ''))));

  Future<T> _safe<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _load() async {
    try {
      final name = await ApiService.userName();
      final office = await ApiService.office();
      final today = await ApiService.today();
      final history = await ApiService.history();
      final shift = await _safe<ShiftInstance?>(ApiService.currentShift, null);
      final modes = await _safe<List<String>>(ApiService.allowedModes, ['WFO']);
      final unread = await _safe<int>(ApiService.unreadCount, 0);
      final rem = await ReminderSettings.load();
      if (!mounted) return;
      setState(() {
        _name = name;
        _office = office;
        _today = today;
        _history = history;
        _shift = shift;
        _modes = modes;
        if (!modes.contains(_mode)) _mode = 'WFO';
        _unread = unread;
        _rem = rem;
      });
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() => _locBusy = true);
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      setState(() {
        _pos = p;
        _locError = null;
        _issue = null;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _pos = null;
        _locError = e.message;
        _issue = e.issue;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pos = null;
        _locError = 'Gagal membaca lokasi. Coba lagi.';
        _issue = null;
      });
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  Future<void> _absen() async {
    setState(() => _busy = true);
    try {
      final pos = await LocationService.current();
      final res = _today?.checkIn == null
          ? await ApiService.checkIn(pos, _mode)
          : await ApiService.checkOut(pos);
      if (!mounted) return;
      setState(() {
        _today = res;
        _pos = pos;
        _locError = null;
      });
      _toast(res.checkOut == null ? 'Check In berhasil' : 'Check Out berhasil');
      ApiService.history().then((h) {
        if (mounted) setState(() => _history = h);
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locError = e.message;
        _issue = e.issue;
      });
      _toast(e.message);
    } catch (e) {
      if (mounted) {
        _toast(e.toString());
        _refreshLocation();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNotifs() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    final n = await _safe<int>(ApiService.unreadCount, 0);
    if (mounted) setState(() => _unread = n);
  }

  String _greeting() {
    final h = _now.hour;
    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  /// Banner pengingat check in / check out sesuai shift.
  String? _reminder() {
    final s = _shift;
    if (s == null) return null;
    final lead = Duration(minutes: _rem.minutes);
    if (_today?.checkIn == null && _rem.checkIn && !_now.isBefore(s.start.subtract(lead))) {
      return _now.isBefore(s.start)
          ? '${s.shift.name} dimulai ${s.shift.start}. Jangan lupa check in.'
          : 'Anda belum check in. ${s.shift.name} dimulai ${s.shift.start}.';
    }
    if (_today?.checkIn != null &&
        _today?.checkOut == null &&
        _rem.checkOut &&
        !_now.isBefore(s.end.subtract(lead))) {
      return '${s.shift.name} berakhir ${s.shift.end}. Jangan lupa check out.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final top = MediaQuery.of(context).padding.top;
    int n(String s) => _history.where((e) => e.status == s).length;
    final banner = _reminder();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            Container(height: top, color: c.primary),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _header(c),
                          Transform.translate(
                            offset: const Offset(0, -48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (banner != null) _banner(c, banner),
                                  _actionCard(c),
                                  const SizedBox(height: 8),
                                  _locationCard(c),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      StatTile(label: 'Hadir', value: n('Hadir'), tone: c.success),
                                      StatTile(label: 'Terlambat', value: n('Terlambat'), tone: c.warning),
                                      StatTile(label: 'Izin', value: n('Izin'), tone: c.info),
                                      StatTile(label: 'Alpa', value: n('Alpa'), tone: c.danger),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Riwayat Terbaru',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: c.text)),
                                      TextButton(
                                          onPressed: widget.onSeeAll,
                                          child: const Text('Lihat semua')),
                                    ],
                                  ),
                                  if (_history.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Center(
                                          child: Text('Belum ada riwayat',
                                              style: TextStyle(color: c.muted))),
                                    ),
                                  ..._history.take(3).map((a) => AttendanceTile(a: a)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppColors c) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 72),
        decoration: BoxDecoration(
          gradient: c.gradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(),
                      style: TextStyle(color: c.onPrimary.withValues(alpha: 0.75))),
                  const SizedBox(height: 2),
                  Text(_name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.onPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  if (_office != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business, size: 14, color: c.onPrimary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                                _shift == null
                                    ? _office!.name
                                    : '${_office!.name} - ${_shift!.shift.name}'
                                      ' - jam kerja ${_shift!.shift.start}-${_shift!.shift.end}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.onPrimary, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: _openNotifs,
              tooltip: 'Notifikasi',
              icon: Badge(
                label: Text('$_unread'),
                isLabelVisible: _unread > 0,
                child: Icon(Icons.notifications_outlined, color: c.onPrimary),
              ),
            ),
            CircleAvatar(
              radius: 22,
              backgroundColor: c.onPrimary.withValues(alpha: 0.18),
              child: Text(initialsOf(_name),
                  style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  Widget _banner(AppColors c, String text) => Card(
        color: c.warning.bg,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.alarm, color: c.warning.fg),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: TextStyle(color: c.warning.fg, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      );

  Widget _actionCard(AppColors c) {
    final checkedIn = _today?.checkIn != null;
    final done = _today?.checkOut != null;
    final bg = checkedIn ? c.primary : c.accent;
    final fg = checkedIn ? c.onPrimary : c.onAccent;
    final s = _shift?.shift;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now),
                style: TextStyle(color: c.muted)),
            const SizedBox(height: 4),
            Text(DateFormat('HH:mm:ss').format(_now),
                style: TextStyle(
                  fontSize: 46,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            if (s != null) ...[
              const SizedBox(height: 6),
              Text('${s.name} - ${s.hours} - istirahat ${s.breakLabel}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.muted)),
              if (s.crossesMidnight)
                Text('Shift melewati tengah malam',
                    style: TextStyle(fontSize: 12, color: c.info.fg)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _timeCell(c, Icons.login, 'Masuk', _today?.checkIn)),
                Container(width: 1, height: 40, color: c.border),
                Expanded(child: _timeCell(c, Icons.logout, 'Pulang', _today?.checkOut)),
              ],
            ),
            if (_today != null && _today!.checkIn != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  StatusPill(status: _today!.status),
                  if (_today!.mode != 'WFO') StatusPill(status: _modeLabel[_today!.mode] ?? ''),
                ],
              ),
            ],
            if (!checkedIn && _modes.length > 1) ...[
              const SizedBox(height: 14),
              Text('Absen dari', style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _modes
                    .map((m) => ChoiceChip(
                          label: Text(_modeLabel[m] ?? m),
                          selected: _mode == m,
                          selectedColor: c.accent.withValues(alpha: 0.2),
                          side: BorderSide(color: _mode == m ? c.primary : c.border),
                          onSelected: (_) => setState(() => _mode = m),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
                onPressed: (_busy || done) ? null : _absen,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(checkedIn ? Icons.logout : Icons.login),
                label: Text(done
                    ? 'ABSEN SHIFT INI SELESAI'
                    : (checkedIn ? 'CHECK OUT' : 'CHECK IN')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeCell(AppColors c, IconData icon, String label, String? value) => Column(
        children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 2),
          Text(value ?? '--:--',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
        ],
      );

  Widget _locationCard(AppColors c) {
    final o = _office;
    final mode = _today?.checkIn != null ? _today!.mode : _mode;
    Tone tone;
    IconData icon;
    String title;
    String? detail;

    if (_locBusy && _pos == null) {
      tone = c.neutral;
      icon = Icons.gps_not_fixed;
      title = 'Mencari lokasi...';
    } else if (_locError != null) {
      tone = c.danger;
      icon = Icons.location_off;
      title = 'Lokasi tidak tersedia';
      detail = _locError;
    } else if (_pos != null && o != null) {
      final acc = _pos!.accuracy;
      if (_pos!.isMocked) {
        tone = c.danger;
        icon = Icons.gpp_bad;
        title = 'Fake GPS terdeteksi';
        detail = 'Akurasi +/-${acc.round()} m';
      } else if (acc > LocationService.maxAccuracyM) {
        tone = c.warning;
        icon = Icons.gps_not_fixed;
        title = 'Akurasi GPS rendah';
        detail = 'Akurasi +/-${acc.round()} m';
      } else if (mode != 'WFO') {
        tone = c.success;
        icon = Icons.location_on;
        title = 'Lokasi terdeteksi';
        detail = mode == 'WFH'
            ? 'Mode WFH: jarak ke rumah terdaftar diverifikasi saat absen - +/-${acc.round()} m'
            : 'Mode Dinas Luar: lokasi dicatat tanpa batas radius - +/-${acc.round()} m';
      } else {
        final d = LocationService.distance(_pos!, o.latitude, o.longitude);
        detail = 'Jarak ${d.round()} m dari ${o.name} (maks ${o.radiusM.round()} m) - '
            'akurasi +/-${acc.round()} m';
        if (d > o.radiusM) {
          tone = c.warning;
          icon = Icons.wrong_location;
          title = 'Di luar area kantor';
        } else {
          tone = c.success;
          icon = Icons.location_on;
          title = 'Di dalam area kantor';
        }
      }
    } else {
      tone = c.neutral;
      icon = Icons.location_searching;
      title = 'Lokasi belum diperiksa';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: tone.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                  if (detail != null)
                    Text(detail, style: TextStyle(fontSize: 12, color: c.muted)),
                  if (_issue != null)
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => LocationService.openSettings(_issue!),
                      child: const Text('Buka pengaturan'),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: _locBusy ? null : _refreshLocation,
              icon: _locBusy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              tooltip: 'Perbarui lokasi',
            ),
          ],
        ),
      ),
    );
  }
}
