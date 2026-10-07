class AppConfig {
  /// Ganti dengan URL backend Anda.
  static const baseUrl = 'https://api.example.com';

  /// true  = data dummy (tanpa backend, login dengan password min. 4 karakter)
  /// false = pakai API sungguhan di baseUrl
  static const useMock = true;
}
