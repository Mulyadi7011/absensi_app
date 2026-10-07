import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'schedule_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  final _tick = [0, 0, 0, 0, 0]; // key berubah -> tab dimuat ulang saat dipilih

  void _go(int i) => setState(() {
        if (i != _i && i != 0) _tick[i]++;
        _i = i;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: [
          DashboardScreen(onSeeAll: () => _go(2)),
          ScheduleScreen(key: ValueKey('s${_tick[1]}')),
          HistoryScreen(key: ValueKey('h${_tick[2]}')),
          RequestsScreen(key: ValueKey('r${_tick[3]}')),
          ProfileScreen(key: ValueKey('p${_tick[4]}')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Pengajuan'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
