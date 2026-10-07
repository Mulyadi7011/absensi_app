import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/pengajuan.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RequestFormScreen extends StatefulWidget {
  final int remaining;
  const RequestFormScreen({super.key, required this.remaining});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _type = 'Izin';
  DateTimeRange? _range;
  DateTime? _date; // untuk Lembur & Koreksi
  TimeOfDay? _t1, _t2;
  String? _attachment;
  String? _error;
  bool _busy = false;

  bool get _single => _type == 'Lembur' || _type == 'Koreksi Absen';

  static const _info = {
    'Izin': 'Perlu persetujuan atasan. Tidak memotong kuota cuti.',
    'Sakit': 'Lebih dari 1 hari wajib melampirkan surat dokter.',
    'Cuti': 'Memotong kuota cuti tahunan.',
    'Lembur': 'Maksimal 4 jam per hari. Jam pertama dihitung 1,5x, berikutnya 2x.',
    'WFH': 'Setelah disetujui, absen WFH hanya bisa di radius rumah terdaftar.',
    'Dinas Luar': 'Setelah disetujui, absen tanpa batas radius (lokasi tetap dicatat).',
    'Koreksi Absen': 'Untuk lupa absen, maksimal 7 hari ke belakang. Isi jam yang benar.',
  };

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final isKoreksi = _type == 'Koreksi Absen';
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? (isKoreksi ? now.subtract(const Duration(days: 1)) : now),
      firstDate: isKoreksi ? now.subtract(const Duration(days: 7)) : now.subtract(const Duration(days: 30)),
      lastDate: isKoreksi ? now.subtract(const Duration(days: 1)) : now.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool first) async {
    final t = await showTimePicker(
        context: context, initialTime: (first ? _t1 : _t2) ?? const TimeOfDay(hour: 8, minute: 0));
    if (t != null) setState(() => first ? _t1 = t : _t2 = t);
  }

  Future<void> _pickAttachment() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ]),
      ),
    );
    if (src == null) return;
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
      if (x != null) setState(() => _attachment = x.name);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal membuka galeri/kamera.');
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final valid = _formKey.currentState!.validate();
    DateTime start, end;
    if (_single) {
      if (_date == null) return setState(() => _error = 'Pilih tanggal terlebih dahulu.');
      if (_t1 == null || _t2 == null) return setState(() => _error = 'Pilih jam mulai dan selesai.');
      start = end = _date!;
    } else {
      if (_range == null) return setState(() => _error = 'Pilih tanggal terlebih dahulu.');
      start = _range!.start;
      end = _range!.end;
    }
    if (!valid) return;

    setState(() => _busy = true);
    try {
      await ApiService.submitRequest(
        type: _type,
        start: start,
        end: end,
        startTime: _single ? _fmt(_t1!) : null,
        endTime: _single ? _fmt(_t2!) : null,
        reason: _reason.text.trim(),
        attachment: _type == 'Sakit' ? _attachment : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan terkirim')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, String value, IconData icon, VoidCallback onTap, {bool empty = false}) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
        child: Text(value, style: TextStyle(color: empty ? c.muted : c.text)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = DateFormat('d MMM yyyy', 'id_ID');
    final isKoreksi = _type == 'Koreksi Absen';
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pengajuan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Jenis pengajuan'),
                items: Pengajuan.types
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _type = v ?? 'Izin';
                  _error = null;
                  _date = null;
                  _range = null;
                  _t1 = _t2 = null;
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                    _type == 'Cuti'
                        ? '${_info[_type]} Sisa cuti: ${widget.remaining} hari.'
                        : _info[_type]!,
                    style: TextStyle(fontSize: 12, color: c.muted)),
              ),
              const SizedBox(height: 16),
              if (_single) ...[
                _field('Tanggal', _date == null ? 'Pilih tanggal' : f.format(_date!),
                    Icons.event, _pickDate, empty: _date == null),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _field(isKoreksi ? 'Jam masuk' : 'Mulai',
                          _t1 == null ? '--:--' : _fmt(_t1!), Icons.schedule, () => _pickTime(true),
                          empty: _t1 == null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(isKoreksi ? 'Jam pulang' : 'Selesai',
                          _t2 == null ? '--:--' : _fmt(_t2!), Icons.schedule, () => _pickTime(false),
                          empty: _t2 == null),
                    ),
                  ],
                ),
              ] else
                _field(
                    'Tanggal',
                    _range == null
                        ? 'Pilih tanggal'
                        : '${f.format(_range!.start)} - ${f.format(_range!.end)}  (${_range!.duration.inDays + 1} hari)',
                    Icons.date_range,
                    _pickRange,
                    empty: _range == null),
              if (_type == 'Sakit') ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_attachment == null ? 'Lampirkan surat dokter' : _attachment!),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                    labelText: _type == 'Dinas Luar' ? 'Tujuan dinas' : 'Alasan',
                    alignLabelWithHint: true),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'Minimal 5 karakter' : null,
              ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: c.danger.bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!,
                      style: TextStyle(color: c.danger.fg, fontWeight: FontWeight.w600)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Kirim Pengajuan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
