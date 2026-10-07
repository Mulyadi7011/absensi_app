import 'package:geolocator/geolocator.dart';

enum LocationIssue { serviceOff, denied, deniedForever }

class LocationException implements Exception {
  final LocationIssue issue;
  final String message;
  LocationException(this.issue, this.message);
  @override
  String toString() => message;
}

class LocationService {
  /// Batas akurasi di sisi aplikasi (hanya untuk UX; server tetap memvalidasi).
  static const maxAccuracyM = 50.0;

  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
          LocationIssue.serviceOff, 'GPS tidak aktif. Aktifkan layanan lokasi.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw LocationException(
          LocationIssue.denied, 'Izin lokasi ditolak. Izinkan agar bisa absen.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw LocationException(LocationIssue.deniedForever,
          'Izin lokasi diblokir. Aktifkan manual di pengaturan aplikasi.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  static double distance(Position p, double lat, double lng) =>
      Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng);

  static Future<void> openSettings(LocationIssue issue) =>
      issue == LocationIssue.serviceOff
          ? Geolocator.openLocationSettings()
          : Geolocator.openAppSettings();
}
