import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan pengingat absen (disimpan di HP).
/// Saat ini ditampilkan sebagai banner di Beranda. Penjadwalan notifikasi OS
/// (muncul saat aplikasi tertutup) dipasang sebagai langkah terpisah.
class ReminderSettings {
  final bool checkIn, checkOut;
  final int minutes; // berapa menit sebelum shift mulai/selesai

  const ReminderSettings({this.checkIn = true, this.checkOut = true, this.minutes = 15});

  static Future<ReminderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return ReminderSettings(
      checkIn: p.getBool('rem_in') ?? true,
      checkOut: p.getBool('rem_out') ?? true,
      minutes: p.getInt('rem_min') ?? 15,
    );
  }

  static Future<void> save({bool? checkIn, bool? checkOut, int? minutes}) async {
    final p = await SharedPreferences.getInstance();
    if (checkIn != null) await p.setBool('rem_in', checkIn);
    if (checkOut != null) await p.setBool('rem_out', checkOut);
    if (minutes != null) await p.setInt('rem_min', minutes);
  }
}
