import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/attendance.dart';
import '../models/rekap.dart';

/// Membuat laporan .xlsx (4 sheet) lalu membuka menu bagikan di HP.
class ExportService {
  static void _header(Sheet s, List<String> cols) {
    s.appendRow(cols.map((c) => TextCellValue(c)).toList());
    for (var i = 0; i < cols.length; i++) {
      s.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle =
          CellStyle(bold: true);
    }
  }

  static Future<void> exportMonth({
    required String name,
    required Rekap rekap,
    required List<Attendance> records, // urut tanggal naik
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Rekap');

    // --- Rekap ---
    final r = excel['Rekap'];
    _header(r, ['Komponen', 'Nilai']);
    void kv(String k, CellValue v) => r.appendRow([TextCellValue(k), v]);
    kv('Nama', TextCellValue(name));
    kv('Periode', TextCellValue('${rekap.month.toString().padLeft(2, '0')}/${rekap.year}'));
    kv('Hadir (hari)', IntCellValue(rekap.hadir));
    kv('Terlambat (hari)', IntCellValue(rekap.terlambat));
    kv('Izin/Cuti/Sakit (hari)', IntCellValue(rekap.izin));
    kv('Alpa (hari)', IntCellValue(rekap.alpa));
    kv('Total jam kerja', DoubleCellValue(rekap.workMinutes / 60));
    kv('Total menit terlambat', IntCellValue(rekap.lateMinutes));
    kv('Total jam lembur', DoubleCellValue(rekap.overtimeHours));

    // --- Detail harian ---
    final d = excel['Detail Harian'];
    _header(d, ['Tanggal', 'Shift', 'Mode', 'Masuk', 'Pulang', 'Jam kerja', 'Telat (menit)', 'Status', 'Lokasi', 'Jarak (m)']);
    for (final a in records) {
      d.appendRow([
        TextCellValue(a.date),
        TextCellValue(a.shift ?? '-'),
        TextCellValue(a.mode),
        TextCellValue(a.checkIn ?? '-'),
        TextCellValue(a.checkOut ?? '-'),
        DoubleCellValue((a.duration?.inMinutes ?? 0) / 60),
        IntCellValue(a.lateMin),
        TextCellValue(a.status),
        TextCellValue(a.office ?? '-'),
        a.distance == null ? TextCellValue('-') : IntCellValue(a.distance!.round()),
      ]);
    }

    // --- Lembur ---
    final l = excel['Lembur'];
    _header(l, ['Tanggal', 'Mulai', 'Selesai', 'Jam']);
    for (final o in rekap.overtime) {
      l.appendRow([TextCellValue(o.date), TextCellValue(o.start), TextCellValue(o.end), DoubleCellValue(o.hours)]);
    }

    // --- Payroll (estimasi) ---
    final p = excel['Payroll'];
    _header(p, ['Komponen', 'Jumlah (Rp)']);
    void line(String k, double v) => p.appendRow([TextCellValue(k), DoubleCellValue(v)]);
    line('Gaji pokok', rekap.baseSalary);
    line('Tunjangan makan', rekap.mealAllowance);
    line('Uang lembur', rekap.overtimePay);
    line('Potongan keterlambatan', -rekap.lateDeduction);
    line('Potongan alpa', -rekap.alpaDeduction);
    line('Total diterima (estimasi)', rekap.net);
    p.appendRow([TextCellValue('Catatan: estimasi, belum termasuk pajak dan BPJS.')]);

    final bytes = excel.save();
    if (bytes == null) throw Exception('Gagal membuat file Excel');
    final dir = await getTemporaryDirectory();
    final ym = '${rekap.year}${rekap.month.toString().padLeft(2, '0')}';
    final path = '${dir.path}/Laporan_Absensi_${name.replaceAll(' ', '_')}_$ym.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'Laporan absensi $name periode $ym',
    );
  }
}
