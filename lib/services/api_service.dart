import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/attendance.dart';
import '../models/notification.dart';
import '../models/office.dart';
import '../models/pengajuan.dart';
import '../models/rekap.dart';
import '../models/shift.dart';
import 'mock_server.dart';

/// Kontrak API lengkap ada di README.md.
/// Fitur inti (login, absen, riwayat) punya jalur API sungguhan.
/// Fitur lanjutan (shift, pengajuan, persetujuan, notifikasi, rekap/payroll)
/// saat ini hanya tersedia di mode mock sampai backend siap.
class ApiService {
  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<bool> isLoggedIn() async {
    final p = await _prefs;
    return p.getString('token') != null && (p.getString('office_id') ?? '').isNotEmpty;
  }

  static Future<String> userName() async => (await _prefs).getString('name') ?? 'Pengguna';
  static Future<String> userEmail() async => (await _prefs).getString('email') ?? '';
  static Future<String> role() async => (await _prefs).getString('role') ?? 'employee';
  static Future<String> _officeId() async => (await _prefs).getString('office_id') ?? '';

  static Future<void> logout() async {
    final p = await _prefs;
    for (final k in ['token', 'name', 'office_id', 'email', 'role']) {
      await p.remove(k);
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = (await _prefs).getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  static dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          body is Map ? (body['message'] ?? 'Terjadi kesalahan') : 'Terjadi kesalahan');
    }
    return body;
  }

  static Map<String, dynamic> _payload(Position p, [String? mode]) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'is_mocked': p.isMocked,
        if (mode != null) 'mode': mode,
      };

  /// Fitur yang baru tersedia di mock.
  static Future<T> _mock<T>(Future<T> Function(String email) f) async {
    if (!AppConfig.useMock) throw Exception('Fitur ini belum terhubung ke backend.');
    return f(await userEmail());
  }

  // ---------- Auth ----------
  static Future<void> login(String email, String password) async {
    final prefs = await _prefs;
    if (AppConfig.useMock) {
      final u = await MockServer.login(email, password);
      await prefs.setString('token', 'mock-token');
      await prefs.setString('name', u['name']);
      await prefs.setString('office_id', u['office_id']);
      await prefs.setString('role', u['role'] ?? 'employee');
      await prefs.setString('email', u['email']);
      return;
    }
    final res = await http.post(
      _uri('/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decode(res);
    await prefs.setString('token', body['token']);
    await prefs.setString('name', body['user']?['name'] ?? email);
    await prefs.setString('office_id', '${body['user']?['office_id'] ?? ''}');
    await prefs.setString('role', body['user']?['role'] ?? 'employee');
    await prefs.setString('email', email);
  }

  // ---------- Inti ----------
  static Future<Office> office() async {
    if (AppConfig.useMock) return MockServer.office(await _officeId());
    final body = _decode(await http.get(_uri('/me/office'), headers: await _headers()));
    return Office.fromJson(body['data']);
  }

  static Future<Attendance?> today() async {
    if (AppConfig.useMock) return _mock(MockServer.today);
    final body = _decode(await http.get(_uri('/attendance/today'), headers: await _headers()));
    return body['data'] == null ? null : Attendance.fromJson(body['data']);
  }

  static Future<Attendance> checkIn(Position pos, String mode) async {
    if (AppConfig.useMock) {
      return _mock((e) => MockServer.checkIn(e, mode, _payload(pos)));
    }
    final body = _decode(await http.post(_uri('/attendance/check-in'),
        headers: await _headers(), body: jsonEncode(_payload(pos, mode))));
    return Attendance.fromJson(body['data']);
  }

  static Future<Attendance> checkOut(Position pos) async {
    if (AppConfig.useMock) return _mock((e) => MockServer.checkOut(e, _payload(pos)));
    final body = _decode(await http.post(_uri('/attendance/check-out'),
        headers: await _headers(), body: jsonEncode(_payload(pos))));
    return Attendance.fromJson(body['data']);
  }

  static Future<List<Attendance>> history() async {
    if (AppConfig.useMock) return _mock(MockServer.history);
    final body = _decode(await http.get(_uri('/attendance/history'), headers: await _headers()));
    return (body['data'] as List).map((e) => Attendance.fromJson(e)).toList();
  }

  // ---------- Lanjutan (mock dulu) ----------
  static Future<ShiftInstance?> currentShift() => _mock(MockServer.currentShift);
  static Future<List<String>> allowedModes() => _mock(MockServer.allowedModes);
  static Future<List<DaySchedule>> schedule([int days = 7]) =>
      _mock((e) => MockServer.schedule(e, days));

  static Future<List<Pengajuan>> requests() => _mock(MockServer.requests);
  static Future<List<Pengajuan>> approvals() => _mock(MockServer.approvals);
  static Future<List<int>> leaveBalance() => _mock(MockServer.leaveBalance);

  static Future<void> submitRequest({
    required String type,
    required DateTime start,
    required DateTime end,
    String? startTime,
    String? endTime,
    required String reason,
    String? attachment,
  }) =>
      _mock((e) => MockServer.submitRequest(e,
          type: type,
          start: start,
          end: end,
          startTime: startTime,
          endTime: endTime,
          reason: reason,
          attachment: attachment));

  static Future<void> decide(String id, bool approve, String note) =>
      _mock((e) => MockServer.decide(e, id, approve, note));

  static Future<List<AppNotification>> notifications() => _mock(MockServer.notifications);
  static Future<int> unreadCount() => _mock(MockServer.unread);
  static Future<void> markAllRead() => _mock(MockServer.markAllRead);

  static Future<Rekap> recap(int year, int month) =>
      _mock((e) => MockServer.recap(e, year, month));
}
