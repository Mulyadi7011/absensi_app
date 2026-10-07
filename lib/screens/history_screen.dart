import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/rekap.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Attendance> _all = [];
  Rekap? _rekap;
  String? _rekapError;
  bool _loading = true;
  bool _exporting = false;
  late DateTime _month;

  static final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _load();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m.replaceFirst('Exception: ', ''))));

  Future<void> _load() async {
    try {
      final h = await ApiService.history();
      if (!mounted) return;
      setState(() => _all = h);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _loadRekap();
  }

  Future<void> _loadRekap() async {
    try {
      final r = await ApiService.recap(_month.year, _month.month);
      if (!mounted) return;
      setState(() {
        _rekap = r;
        _rekapError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _rekap = null;
          _rekapError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  bool get _isCurrent {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  List<Attendance> get _items {
    final l = _all.where((a) {
      final d = DateTime.tryParse(a.date);
      return d != null && d.year == _month.year && d.month == _month.month;
    }).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _rekap = null;
    });
    _loadRekap();
  }

  Future<void> _export() async {
    final r = _rekap;
    if (r == null) return;
    setState(() => _exporting = true);
    try {
      final name = await ApiService.userName();
      final asc = _items.reversed.toList();
      await ExportService.exportMonth(name: name, rekap: r, records: asc);
    } catch (e) {
      if (mounted) _toast('Gagal export: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat'),
          actions: [
            IconButton(
              tooltip: 'Export Excel',
              onPressed: (_rekap == null || _exporting) ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Harian'), Tab(text: 'Rekap & Gaji')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                              onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                          Text(DateFormat('MMMM yyyy', 'id_ID').format(_month),
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                          IconButton(
                              onPressed: _isCurrent ? null : () => _shift(1),
                              icon: const Icon(Icons.chevron_right)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: TabBarView(children: [_daily(c), _rekapTab(c)])),
                ],
              ),
      ),
    );
  }

  Widget _daily(AppColors c) {
    final items = _items;
    int n(String s) => items.where((a) => a.status == s).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              StatTile(label: 'Hadir', value: n('Hadir'), tone: c.success),
              StatTile(label: 'Terlambat', value: n('Terlambat'), tone: c.warning),
              StatTile(label: 'Izin', value: n('Izin'), tone: c.info),
              StatTile(label: 'Alpa', value: n('Alpa'), tone: c.danger),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child: Text('Tidak ada data di bulan ini', style: TextStyle(color: c.muted))),
            ),
          ...items.map((a) => AttendanceTile(a: a, onTap: () => _detail(a))),
        ],
      ),
    );
  }

  Widget _line(AppColors c, String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(k, style: TextStyle(color: c.muted))),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: bold ? 16 : 14,
                    color: color ?? c.text)),
          ],
        ),
      );

  Widget _rekapTab(AppColors c) {
    final r = _rekap;
    if (_rekapError != null) {
      return Center(child: Text(_rekapError!, style: TextStyle(color: c.muted)));
    }
    if (r == null) return const Center(child: CircularProgressIndicator());
    final f = DateFormat('d MMM', 'id_ID');
    return RefreshIndicator(
      onRefresh: _loadRekap,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              StatTile(label: 'Hadir', value: r.hadir, tone: c.success),
              StatTile(label: 'Terlambat', value: r.terlambat, tone: c.warning),
              StatTile(label: 'Izin', value: r.izin, tone: c.info),
              StatTile(label: 'Alpa', value: r.alpa, tone: c.danger),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _line(c, 'Total jam kerja',
                      '${r.workMinutes ~/ 60} j ${r.workMinutes % 60} m'),
                  _line(c, 'Total terlambat', '${r.lateMinutes} menit'),
                  _line(c, 'Total lembur', '${r.overtimeHours.toStringAsFixed(1)} jam'),
                  if (r.eventInvited > 0)
                    _line(c, 'Kehadiran meeting/pelatihan',
                        '${r.eventAttended}/${r.eventInvited} undangan'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimasi Gaji',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 8),
                  _line(c, 'Gaji pokok', _rp.format(r.baseSalary)),
                  _line(c, 'Tunjangan makan (${r.hadir + r.terlambat} hari)',
                      _rp.format(r.mealAllowance)),
                  _line(c, 'Uang lembur (${r.overtimeHours.toStringAsFixed(1)} jam)',
                      _rp.format(r.overtimePay), color: c.success.fg),
                  _line(c, 'Potongan terlambat (${r.lateMinutes} menit)',
                      '- ${_rp.format(r.lateDeduction)}', color: c.danger.fg),
                  _line(c, 'Potongan alpa (${r.alpa} hari)',
                      '- ${_rp.format(r.alpaDeduction)}', color: c.danger.fg),
                  Divider(color: c.border),
                  _line(c, 'Total diterima', _rp.format(r.net), bold: true),
                  const SizedBox(height: 4),
                  Text('Estimasi, belum termasuk pajak dan BPJS.',
                      style: TextStyle(fontSize: 11, color: c.muted)),
                ],
              ),
            ),
          ),
          if (r.overtime.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Rincian Lembur',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
            ...r.overtime.map((o) => Card(
                  child: ListTile(
                    leading: Icon(
                        o.kind == 'On-Call' ? Icons.support_agent : Icons.more_time,
                        color: o.kind == 'On-Call' ? Colors.deepOrange : c.primary),
                    title: Text('${o.title.isEmpty ? f.format(DateTime.parse(o.date)) : o.title}'
                        ' • ${o.kind}'),
                    subtitle: Text('${f.format(DateTime.parse(o.date))} · ${o.start} – ${o.end}'
                        '${o.attended ? '' : ' · belum diabsen'}'),
                    trailing: Text('${o.hours.toStringAsFixed(1)} jam',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.table_view),
            label: const Text('Export laporan Excel'),
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: TextStyle(color: c.muted)),
            Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
          ],
        ),
      );

  void _detail(Attendance a) {
    final d = DateTime.tryParse(a.date);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        d == null ? a.date : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d),
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                  ),
                  StatusPill(status: a.status),
                ],
              ),
              const SizedBox(height: 8),
              _row(c, 'Shift', a.shift ?? '-'),
              Divider(color: c.border),
              _row(c, 'Jam masuk', a.checkIn ?? '-'),
              Divider(color: c.border),
              _row(c, 'Jam pulang', a.checkOut ?? '-'),
              Divider(color: c.border),
              _row(c, 'Istirahat', a.breakMin == 0 ? '-' : '${a.breakMin} menit'),
              Divider(color: c.border),
              _row(c, 'Jam kerja bersih', fmtDur(a.duration)),
              Divider(color: c.border),
              _row(c, 'Terlambat', a.lateMin == 0 ? '-' : '${a.lateMin} menit'),
              Divider(color: c.border),
              _row(c, 'Lokasi', a.office ?? '-'),
              Divider(color: c.border),
              _row(c, 'Jarak', a.distance == null ? '-' : '${a.distance!.round()} m'),
            ],
          ),
        );
      },
    );
  }
}
