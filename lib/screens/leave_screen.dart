import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave.dart';
import '../models/pengajuan.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'leave_form_screen.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  LeaveSummary? _s;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ApiService.leaves();
      if (!mounted) return;
      setState(() => _s = s);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm() async {
    final s = _s!;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LeaveFormScreen(remaining: s.quota - s.used)),
    );
    if (ok == true) _load();
  }

  String _range(Pengajuan l) {
    final f = DateFormat('d MMM yyyy', 'id_ID');
    final a = DateTime.parse(l.startDate), b = DateTime.parse(l.endDate);
    return l.days == 1 ? f.format(a) : '${f.format(a)} - ${f.format(b)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('Izin & Cuti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: s == null ? null : _openForm,
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('Ajukan', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? Center(child: Text('Gagal memuat data', style: TextStyle(color: c.muted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: c.gradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sisa cuti tahun ini',
                                style: TextStyle(color: c.onPrimary.withValues(alpha: 0.8))),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('${s.quota - s.used}',
                                    style: TextStyle(
                                        color: c.onPrimary,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 6),
                                Text('hari', style: TextStyle(color: c.onPrimary)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: s.quota == 0 ? 0 : s.used / s.quota,
                                minHeight: 8,
                                color: c.onPrimary,
                                backgroundColor: c.onPrimary.withValues(alpha: 0.25),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Terpakai ${s.used} dari ${s.quota} hari',
                                style: TextStyle(
                                    fontSize: 12, color: c.onPrimary.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Pengajuan Saya',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 8),
                      if (s.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                              child: Text('Belum ada pengajuan',
                                  style: TextStyle(color: c.muted))),
                        ),
                      ...s.items.map((l) {
                        final t = c.forStatus(l.status);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: t.bg, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(l.icon, color: t.fg),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${l.type} - ${l.days} hari',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700, color: c.text)),
                                      const SizedBox(height: 2),
                                      Text(_range(l),
                                          style: TextStyle(fontSize: 12, color: c.muted)),
                                      const SizedBox(height: 4),
                                      Text(l.reason, style: TextStyle(color: c.text)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusPill(status: l.status),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
