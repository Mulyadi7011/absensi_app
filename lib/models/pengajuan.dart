import 'package:flutter/material.dart';

/// Pengajuan generik: Izin, Sakit, Cuti, Lembur, WFH, Dinas Luar, Koreksi Absen.
class Pengajuan {
  static const types = ['Izin', 'Sakit', 'Cuti', 'Lembur', 'WFH', 'Dinas Luar', 'Koreksi Absen'];

  final String id, userEmail, userName, type, startDate, endDate, reason, status;
  final String? startTime, endTime, attachment, approver, approverNote;

  const Pengajuan({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.startTime,
    this.endTime,
    this.attachment,
    this.approver,
    this.approverNote,
  });

  factory Pengajuan.fromJson(Map<String, dynamic> j) => Pengajuan(
        id: '${j['id']}',
        userEmail: j['user_email'] ?? '',
        userName: j['user_name'] ?? '',
        type: j['type'] ?? 'Izin',
        startDate: j['start_date'] ?? '',
        endDate: j['end_date'] ?? '',
        reason: j['reason'] ?? '',
        status: j['status'] ?? 'Menunggu',
        startTime: j['start_time'],
        endTime: j['end_time'],
        attachment: j['attachment'],
        approver: j['approver'],
        approverNote: j['approver_note'],
      );

  Pengajuan copyWith({String? status, String? approverNote}) => Pengajuan(
        id: id,
        userEmail: userEmail,
        userName: userName,
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        status: status ?? this.status,
        startTime: startTime,
        endTime: endTime,
        attachment: attachment,
        approver: approver,
        approverNote: approverNote ?? this.approverNote,
      );

  int get days =>
      DateTime.parse(endDate).difference(DateTime.parse(startDate)).inDays + 1;

  bool get hasTime => startTime != null && endTime != null;

  double get overtimeHours {
    if (type != 'Lembur' || !hasTime) return 0;
    int m(String s) {
      final p = s.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    var d = m(endTime!) - m(startTime!);
    if (d <= 0) d += 1440; // lembur melewati tengah malam
    return d / 60.0;
  }

  IconData get icon {
    switch (type) {
      case 'Sakit':
        return Icons.medical_services_outlined;
      case 'Cuti':
        return Icons.beach_access_outlined;
      case 'Lembur':
        return Icons.more_time;
      case 'WFH':
        return Icons.home_work_outlined;
      case 'Dinas Luar':
        return Icons.flight_takeoff;
      case 'Koreksi Absen':
        return Icons.edit_calendar_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }
}
