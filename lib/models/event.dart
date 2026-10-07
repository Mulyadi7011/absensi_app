import 'package:flutter/material.dart';
import 'shift.dart' show ShiftParser;

/// Undangan Meeting / Pelatihan dari kalender perusahaan.
/// Validasi kehadiran berbasis "tabel peserta" ([participants]):
/// hanya email yang terdaftar di tabel peserta yang boleh absen untuk event ini.
class EventParticipant {
  final String email, name;
  final bool attended; // hasil validasi saat diundang (sudah pernah absen?)

  const EventParticipant({
    required this.email,
    required this.name,
    this.attended = false,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> j) => EventParticipant(
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        attended: j['attended'] == true,
      );

  Map<String, dynamic> toJson() => {'email': email, 'name': name, 'attended': attended};
}

class WorkEvent {
  static const kindMeeting = 'Meeting';
  static const kindTraining = 'Pelatihan';
  static const kinds = [kindMeeting, kindTraining];

  final String id, title, kind, organizer, location;
  final DateTime start, end;
  final List<EventParticipant> participants;

  /// Absen kehadiran event hanya dibuka mulai [checkInLeadMin] menit sebelum mulai
  /// sampai [checkOutLagMin] menit setelah selesai.
  final int checkInLeadMin, checkOutLagMin;

  const WorkEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.organizer,
    required this.location,
    required this.start,
    required this.end,
    required this.participants,
    this.checkInLeadMin = 15,
    this.checkOutLagMin = 30,
  });

  factory WorkEvent.fromJson(Map<String, dynamic> j) => WorkEvent(
        id: '${j['id']}',
        title: j['title'] ?? '',
        kind: j['kind'] ?? kindMeeting,
        organizer: j['organizer'] ?? '',
        location: j['location'] ?? '',
        start: ShiftParser.parseWhen(j['start']),
        end: ShiftParser.parseWhen(j['end']),
        participants: (j['participants'] as List)
            .map((e) => EventParticipant.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        checkInLeadMin: (j['check_in_lead_min'] as num?)?.toInt() ?? 15,
        checkOutLagMin: (j['check_out_lag_min'] as num?)?.toInt() ?? 30,
      );

  bool get crossesMidnight => end.day != start.day || end.month != start.month;

  bool isParticipant(String email) =>
      participants.any((p) => p.email.toLowerCase() == email.toLowerCase());

  EventParticipant? participant(String email) {
    for (final p in participants) {
      if (p.email.toLowerCase() == email.toLowerCase()) return p;
    }
    return null;
  }

  DateTime get checkInOpen => start.subtract(Duration(minutes: checkInLeadMin));
  DateTime get checkOutClose => end.add(Duration(minutes: checkOutLagMin));

  IconData get icon => kind == kindTraining ? Icons.school_outlined : Icons.groups_outlined;

  String get windowLabel =>
      'Absen dibuka ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} '
      '(H-${checkInLeadMin ~/ 60 > 0 ? '${checkInLeadMin ~/ 60} jam' : '$checkInLeadMin menit'} sebelum) '
      'hingga ${checkOutLagMin} menit setelah selesai';
}

/// Hasil absensi pada satu event (dicatat per peserta, tervalidasi dari tabel peserta).
class EventAttendance {
  final String eventId, userEmail;
  final String? checkIn, checkOut; // HH:mm
  final double? distanceM;
  final String status; // Hadir | Terlambat | Alpa

  const EventAttendance({
    required this.eventId,
    required this.userEmail,
    this.checkIn,
    this.checkOut,
    this.distanceM,
    this.status = 'Hadir',
  });

  bool get done => checkIn != null && checkOut != null;
}
