import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pengajuan.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'request_form_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<Pengajuan> _mine = [], _team = [];
  List<int> _balance = [12, 0];
  bool _supervisor = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m.replaceFirst('Exception: ', ''))));

  Future<void> _load() async {
    try {
      final role = await ApiService.role();
      final mine = await ApiService.requests();
      final bal = await ApiService.leaveBalance();
      final team = role == 'supervisor' ? await ApiService.approvals() : <Pengajuan>[];
      if (!mounted) return;
      setState(() {
        _supervisor = role == 'supervisor';
        _mine = mine;
        _team = team;
        _balance = bal;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm() async {
    final ok = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => RequestFormScreen(remaining: _balance[0] - _balance[1])));
    if (ok == true) _load();
  }

  Future<void> _decide(Pengajuan r, bool approve) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Setujui pengajuan?' : 'Tolak pengajuan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.userName} - ${r.type}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: approve ? 'Catatan (opsional)' : 'Alasan penolakan (wajib)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (!approve && ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(approve ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.decide(r.id, approve, ctrl.text.trim());
      if (!mounted) return;
      _toast(approve ? 'Pengajuan disetujui' : 'Pengajuan ditolak');
      _load();
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  String _range(Pengajuan r) {
    final f = DateFormat('d MMM yyyy', 'id_ID');
    final a = DateTime.parse(r.startDate), b = DateTime.parse(r.endDate);
    final d = r.days == 1 ? f.format(a) : '${f.format(a)} - ${f.format(b)}';
    return r.hasTime ? '$d - ${r.startTime}-${r.endTime}' : d;
  }

  Widget _card(AppColors c, Pengajuan r, {bool team = false}) {
    final t = c.forStatus(r.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(r.icon, color: t.fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${team ? '${r.userName} - ' : ''}${r.type}${r.days > 1 ? ' - ${r.days} hari' : ''}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                      const SizedBox(height: 2),
                      Text(_range(r), style: TextStyle(fontSize: 12, color: c.muted)),
                      const SizedBox(height: 4),
                      Text(r.reason, style: TextStyle(color: c.text)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(status: r.status),
              ],
            ),
            if (r.attachment != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.attach_file, size: 16, color: c.muted),
                const SizedBox(width: 4),
                Text(r.attachment!, style: TextStyle(fontSize: 12, color: c.muted)),
              ]),
            ],
            if (r.approverNote != null) ...[
              const SizedBox(height: 8),
              Text('Catatan atasan: ${r.approverNote}',
                  style: TextStyle(fontSize: 12, color: c.muted, fontStyle: FontStyle.italic)),
            ],
            if (team && r.status == 'Menunggu') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: c.danger.fg,
                          side: BorderSide(color: c.danger.fg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _decide(r, false),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(64, 42)),
                      onPressed: () => _decide(r, true),
                      child: const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mineTab(AppColors c) {
    final remaining = _balance[0] - _balance[1];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: c.gradient, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sisa cuti tahun ini',
                    style: TextStyle(color: c.onPrimary.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text('$remaining hari',
                    style: TextStyle(
                        color: c.onPrimary, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _balance[0] == 0 ? 0 : _balance[1] / _balance[0],
                    minHeight: 8,
                    color: c.onPrimary,
                    backgroundColor: c.onPrimary.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Terpakai ${_balance[1]} dari ${_balance[0]} hari',
                    style: TextStyle(fontSize: 12, color: c.onPrimary.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Pengajuan Saya',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 8),
          if (_mine.isEmpty)
            Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text('Belum ada pengajuan', style: TextStyle(color: c.muted)))),
          ..._mine.map((r) => _card(c, r)),
        ],
      ),
    );
  }

  Widget _teamTab(AppColors c) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (_team.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                      child: Text('Tidak ada pengajuan tim', style: TextStyle(color: c.muted)))),
            ..._team.map((r) => _card(c, r, team: true)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pending = _team.where((r) => r.status == 'Menunggu').length;
    return DefaultTabController(
      length: _supervisor ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pengajuan'),
          bottom: _supervisor
              ? TabBar(tabs: [
                  const Tab(text: 'Saya'),
                  Tab(text: pending > 0 ? 'Persetujuan ($pending)' : 'Persetujuan'),
                ])
              : null,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading || _error != null ? null : _openForm,
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          elevation: 2,
          icon: const Icon(Icons.add),
          label: const Text('Ajukan', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: c.muted)))
                : _supervisor
                    ? TabBarView(children: [_mineTab(c), _teamTab(c)])
                    : _mineTab(c),
      ),
    );
  }
}
