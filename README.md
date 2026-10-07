# Absensi App (Flutter)

Aplikasi absensi dengan GPS geofencing, shift, pengajuan + persetujuan, rekap/payroll, dan export Excel.
Data dummy dari `assets/data/*.json` (mode `useMock = true` di `lib/config.dart`).

## Setup
1. Izin di `android/app/src/main/AndroidManifest.xml` (di atas tag `<application`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
2. `flutter pub get` lalu `flutter run`

## Akun demo (password 123456)
| Email | Peran | Shift |
|---|---|---|
| budi@contoh.com | Karyawan (kantor HQ) | Pagi Senin-Jumat |
| sari@contoh.com | Karyawan (kantor BDG) | Senin-Selasa Siang, Rabu-Kamis **Malam (lewat tengah malam)**, Jumat Pagi |
| dewi@contoh.com | Atasan (menyetujui pengajuan Budi & Sari) | Pagi Senin-Jumat |

## Yang perlu disesuaikan untuk uji di lokasi Anda
- `assets/data/offices.json`: koordinat kantor (HQ untuk Budi/Dewi, BDG untuk Sari)
- `assets/data/users.json`: `home` (lokasi rumah untuk uji WFH)
- `offices.json -> rules.enforce_shift_window`: `false` (dev) = absen boleh di luar jendela shift;
  `true` = hanya 3 jam sebelum s/d 3 jam setelah shift (perilaku produksi)

## Skenario uji
1. Budi: Beranda -> pilih "Absen dari" Kantor / WFH / Dinas Luar (WFH & Dinas sudah disetujui hari ini) -> Check In.
2. Budi: Pengajuan -> Ajukan (Cuti, Lembur, Koreksi Absen, Sakit + lampiran) -> status Menunggu.
3. Keluar, login Dewi: Pengajuan -> tab Persetujuan -> Setujui/Tolak (tolak wajib alasan).
4. Login Budi lagi: notifikasi (lonceng di Beranda) + status pengajuan berubah. Koreksi yang disetujui mengubah riwayat.
   (Data dummy tersimpan di memori: jangan tutup aplikasi total di antara langkah 2-4.)
5. Riwayat -> tab Rekap & Gaji -> lihat estimasi gaji -> ikon unduh = Export Excel (4 sheet).
6. Sari: Jadwal -> lihat shift malam bertanda (+1 hari). Shift malam yang dimulai kemarin tetap dikenali setelah lewat tengah malam.

## Aturan bisnis (lib/services/mock_server.dart)
- Absen: Fake GPS ditolak -> akurasi > `max_accuracy_m` ditolak -> validasi per mode:
  WFO radius kantor | WFH pengajuan disetujui + radius rumah | Dinas Luar pengajuan disetujui (lokasi dicatat)
- Terlambat = lewat `start + tolerance_min` shift; menit terlambat dihitung dari jam mulai shift
- Jam kerja bersih = (pulang - masuk) - istirahat, aman untuk shift lewat tengah malam
- Pengajuan: Sakit > 1 hari wajib lampiran; Cuti memotong kuota; Lembur maks 4 jam/hari;
  Koreksi maks 7 hari ke belakang; tanggal izin/cuti tidak boleh bertabrakan
- Persetujuan: atasan menyetujui/menolak; tanpa atasan = disetujui otomatis; hasilnya masuk notifikasi pemohon
- Payroll (payroll.json): gaji pokok + tunjangan makan/hari hadir + lembur (jam 1 = 1,5x, berikutnya 2x, upah/jam = gaji/173)
  - potongan terlambat per menit - potongan alpa (gaji / hari kerja). Estimasi, belum termasuk pajak & BPJS.

## Kontrak API (untuk backend sungguhan)
Sudah punya jalur API di `api_service.dart`:
| Method | Endpoint | Keterangan |
|---|---|---|
| POST | /login | `{email,password}` -> `{token,user:{name,office_id,role}}` |
| GET | /me/office | kantor user |
| GET | /attendance/today, /attendance/history | data absensi |
| POST | /attendance/check-in | `{latitude,longitude,accuracy,is_mocked,mode}` |
| POST | /attendance/check-out | `{latitude,longitude,accuracy,is_mocked}` |

Baru di mock (backend perlu menyediakan, bentuk data = model di `lib/models`):
`GET /me/shift`, `GET /me/schedule?days=`, `GET /me/modes`,
`GET|POST /requests`, `GET /approvals`, `POST /requests/{id}/decision {approve,note}`,
`GET /leave-balance`, `GET /notifications`, `POST /notifications/read`, `GET /recap?year=&month=`.
Error validasi: HTTP 422 `{message}`.

## Pengingat
Pengingat check in/out saat ini tampil sebagai banner di Beranda (pengaturan di Profil).
Notifikasi OS yang muncul saat aplikasi tertutup belum dipasang (butuh plugin + konfigurasi Android).

## Tema
3 palet (Navy, Indigo, Emerald), pilih di Profil -> Tampilan atau ikon palet di login. Token warna: `lib/theme/app_theme.dart`.
