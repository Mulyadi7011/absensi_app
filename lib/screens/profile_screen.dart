import 'package:flutter/material.dart';
import '../models/office.dart';
import '../models/shift.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/theme_picker.dart';
import 'attendance_sessions_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '', _email = '', _role = 'employee';
  Office? _office;
  Shift? _shift;
  ReminderSettings _rem = const ReminderSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final name = await ApiService.userName();
      final email = await ApiService.userEmail();
      final role = await ApiService.role();
      final office = await ApiService.office();
      final rem = await ReminderSettings.load();
      Shift? shift;
      try {
        shift = (await ApiService.currentShift())?.shift;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _name = name;
        _email = email;
        _role = role;
        _office = office;
        _shift = shift;
        _rem = rem;
      });
    } catch (_) {
      // tampilkan data yang ada
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRem({bool? inn, bool? out, int? min}) async {
    await ReminderSettings.save(checkIn: inn, checkOut: out, minutes: min);
    final r = await ReminderSettings.load();
    if (mounted) setState(() => _rem = r);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda perlu login ulang untuk memakai aplikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Widget _icon(AppColors c, IconData icon, {Color? bg, Color? fg}) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: bg ?? c.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: fg ?? c.primary, size: 20),
      );

  Widget _info(AppColors c, IconData icon, String label, String value) => ListTile(
        leading: _icon(c, icon),
        title: Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
        subtitle: Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
      );

  Widget _section(AppColors c, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.muted)),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: c.gradient, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: c.onPrimary,
                        child: Text(initialsOf(_name),
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: c.primary)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_name,
                                style: TextStyle(
                                    color: c.onPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text(_email,
                                style: TextStyle(color: c.onPrimary.withValues(alpha: 0.8))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                  color: c.onPrimary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(_role == 'supervisor' ? 'Atasan' : 'Karyawan',
                                  style: TextStyle(
                                      color: c.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _section(c, 'PENEMPATAN'),
                Card(
                  child: Column(
                    children: [
                      _info(c, Icons.business, 'Kantor', _office?.name ?? '-'),
                      Divider(color: c.border),
                      _info(c, Icons.schedule, 'Shift saat ini',
                          _shift == null ? '-' : '${_shift!.name} • ${_shift!.hours}'),
                      Divider(color: c.border),
                      _info(c, Icons.radar, 'Radius absen',
                          _office == null ? '-' : '${_office!.radiusM.round()} m dari kantor'),
                    ],
                  ),
                ),
                _section(c, 'PENGINGAT ABSEN'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: _icon(c, Icons.login),
                        title: const Text('Pengingat check in'),
                        value: _rem.checkIn,
                        onChanged: (v) => _setRem(inn: v),
                      ),
                      Divider(color: c.border),
                      SwitchListTile(
                        secondary: _icon(c, Icons.logout),
                        title: const Text('Pengingat check out'),
                        value: _rem.checkOut,
                        onChanged: (v) => _setRem(out: v),
                      ),
                      Divider(color: c.border),
                      ListTile(
                        leading: _icon(c, Icons.alarm),
                        title: const Text('Ingatkan sebelum'),
                        trailing: DropdownButton<int>(
                          value: _rem.minutes,
                          underline: const SizedBox(),
                          items: const [5, 10, 15, 30]
                              .map((m) => DropdownMenuItem(value: m, child: Text('$m menit')))
                              .toList(),
                          onChanged: (v) => _setRem(min: v),
                        ),
                      ),
                    ],
                  ),
                ),
                _section(c, 'TAMPILAN'),
                const ThemePicker(),
                _section(c, 'ABSENSI SESI'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: _icon(c, Icons.work_outline),
                        title: const Text('Lembur Terjadwal / On-Call'),
                        subtitle: const Text('Absen lembur — validasi dari tabel peserta'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AttendanceSessionsScreen())),
                      ),
                      Divider(color: c.border),
                      ListTile(
                        leading: _icon(c, Icons.groups_outlined),
                        title: const Text('Meeting & Pelatihan'),
                        subtitle: const Text('Absen kehadiran undangan — validasi tabel peserta'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AttendanceSessionsScreen())),
                      ),
                    ],
                  ),
                ),
                _section(c, 'APLIKASI'),
                Card(
                  child: Column(
                    children: [
                      _info(c, Icons.info_outline, 'Versi aplikasi', '1.1.0'),
                      Divider(color: c.border),
                      ListTile(
                        leading: _icon(c, Icons.logout, bg: c.danger.bg, fg: c.danger.fg),
                        title: Text('Keluar',
                            style: TextStyle(color: c.danger.fg, fontWeight: FontWeight.w700)),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
