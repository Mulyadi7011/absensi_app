import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await ApiService.notifications();
      if (!mounted) return;
      setState(() => _items = l); // tampilkan status belum dibaca dulu
      await ApiService.markAllRead(); // lalu tandai dibaca
    } catch (_) {
      // abaikan
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text('Belum ada notifikasi', style: TextStyle(color: c.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _items.map((n) {
                    final t = n.kind == 'approval'
                        ? c.warning
                        : n.kind == 'reminder'
                            ? c.success
                            : c.info;
                    final icon = n.kind == 'approval'
                        ? Icons.fact_check_outlined
                        : n.kind == 'reminder'
                            ? Icons.alarm
                            : Icons.info_outline;
                    return Card(
                      color: n.read ? c.surface : t.bg.withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: t.bg, borderRadius: BorderRadius.circular(12)),
                              child: Icon(icon, color: t.fg, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700, color: c.text)),
                                  Text(n.body, style: TextStyle(color: c.text)),
                                  const SizedBox(height: 2),
                                  Text(timeAgo(n.time),
                                      style: TextStyle(fontSize: 11, color: c.muted)),
                                ],
                              ),
                            ),
                            if (!n.read)
                              Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration:
                                      BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
