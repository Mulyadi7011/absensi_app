import 'package:flutter/material.dart';

class Leave {
  final String id;
  final String type; // Izin | Sakit | Cuti
  final String startDate; // yyyy-MM-dd
  final String endDate;
  final String reason;
  final String status; // Menunggu | Disetujui | Ditolak

  Leave({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  factory Leave.fromJson(Map<String, dynamic> j) => Leave(
        id: '${j['id']}',
        type: j['type'] ?? 'Izin',
        startDate: j['start_date'] ?? '',
        endDate: j['end_date'] ?? '',
        reason: j['reason'] ?? '',
        status: j['status'] ?? 'Menunggu',
      );

  int get days =>
      DateTime.parse(endDate).difference(DateTime.parse(startDate)).inDays + 1;


  IconData get icon {
    switch (type) {
      case 'Sakit':
        return Icons.medical_services_outlined;
      case 'Cuti':
        return Icons.beach_access_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }
}

class LeaveSummary {
  final int quota;
  final int used;
  final List<Leave> items;
  LeaveSummary(this.quota, this.used, this.items);
}
