import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../theme/app_theme.dart';

String initialsOf(String name) => name
    .trim()
    .split(' ')
    .where((s) => s.isNotEmpty)
    .take(2)
    .map((s) => s[0].toUpperCase())
    .join();

String fmtDur(Duration? d) =>
    d == null ? '-' : '${d.inHours} j ${d.inMinutes % 60} m';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

/// Label status berbentuk pill tonal.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final t = context.c.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(color: t.fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Kotak ringkasan angka (tonal).
class StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Tone tone;
  const StatTile({super.key, required this.label, required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tone.fg)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tone.fg)),
          ],
        ),
      ),
    );
  }
}

/// Baris riwayat: blok tanggal tonal + jam + status.
class AttendanceTile extends StatelessWidget {
  final Attendance a;
  final VoidCallback? onTap;
  const AttendanceTile({super.key, required this.a, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = c.forStatus(a.status);
    final d = DateTime.tryParse(a.date);
    final time = a.checkIn == null
        ? 'Tanpa catatan jam'
        : '${a.checkIn} – ${a.checkOut ?? 'belum pulang'}${a.lateMin > 0 ? ' • telat ${a.lateMin} m' : ''}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 54,
                decoration:
                    BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(d == null ? '' : '${d.day}',
                        style: TextStyle(
                            color: t.fg, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(d == null ? '' : DateFormat('MMM', 'id_ID').format(d).toUpperCase(),
                        style: TextStyle(
                            color: t.fg, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d == null ? a.date : DateFormat('EEEE', 'id_ID').format(d),
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 2),
                    Text(a.office == null ? time : '$time • ${a.office}',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: a.status),
            ],
          ),
        ),
      ),
    );
  }
}
