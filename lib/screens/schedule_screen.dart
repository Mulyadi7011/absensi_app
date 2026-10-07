import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<DaySchedule> _days = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.schedule(14);
      if (!mounted) return;
      setState(() {
        _days = d;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _rule(AppColors c, IconData i, String t, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, size: 18, color: c.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                  Text(s, style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Kerja')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: c.muted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Aturan Absensi',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                              _rule(c, Icons.timer_outlined, 'Toleransi keterlambatan',
                                  'Mengikuti shift (lihat di bawah). Lewat toleransi = Terlambat dan masuk perhitungan potongan.'),
                              _rule(c, Icons.business, 'Kantor (WFO)',
                                  'Wajib berada dalam radius kantor.'),
                              _rule(c, Icons.home_work_outlined, 'WFH',
                                  'Butuh pengajuan disetujui. Absen hanya di radius rumah terdaftar.'),
                              _rule(c, Icons.flight_takeoff, 'Dinas Luar',
                                  'Butuh pengajuan disetujui. Lokasi dicatat tanpa batas radius.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('14 Hari ke Depan',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 8),
                      ..._days.asMap().entries.map((e) => _dayCard(c, e.value, e.key == 0)),
                    ],
                  ),
                ),
    );
  }

  Widget _dayCard(AppColors c, DaySchedule d, bool isToday) {
    final s = d.shift;
    final tone = s == null ? c.neutral : (s.crossesMidnight ? c.info : c.success);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isToday ? c.primary : c.border, width: isToday ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 54,
              decoration:
                  BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${d.date.day}',
                      style: TextStyle(
                          color: tone.fg, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(DateFormat('MMM', 'id_ID').format(d.date).toUpperCase(),
                      style: TextStyle(
                          color: tone.fg, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${DateFormat('EEEE', 'id_ID').format(d.date)}${isToday ? ' (hari ini)' : ''}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 2),
                  if (s == null)
                    Text('Libur', style: TextStyle(color: c.muted))
                  else ...[
                    Text('${s.name} • ${s.hours}${s.crossesMidnight ? ' (+1 hari)' : ''}',
                        style: TextStyle(fontSize: 13, color: c.text)),
                    Text('Istirahat ${s.breakLabel} • toleransi ${s.toleranceMin} menit',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                  if (d.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: d.tags.map((t) => StatusPill(status: t)).toList(),
                    ),
                  ],
                  if (d.events.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...d.events.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(Icons.event_available, size: 14, color: c.info.fg),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text('Undangan: $e',
                                    style: TextStyle(fontSize: 12, color: c.info.fg)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
