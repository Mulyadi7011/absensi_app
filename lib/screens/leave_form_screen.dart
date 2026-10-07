import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class LeaveFormScreen extends StatefulWidget {
  final int remaining;
  const LeaveFormScreen({super.key, required this.remaining});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _type = 'Izin';
  DateTimeRange? _range;
  bool _rangeError = false;
  bool _busy = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (r != null) {
      setState(() {
        _range = r;
        _rangeError = false;
      });
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    if (_range == null) setState(() => _rangeError = true);
    if (!valid || _range == null) return;

    setState(() => _busy = true);
    try {
      await ApiService.submitLeave(_type, _range!.start, _range!.end, _reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pengajuan terkirim')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('d MMM yyyy', 'id_ID');
    final days = _range == null ? 0 : _range!.duration.inDays + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Izin / Cuti')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                    labelText: 'Jenis pengajuan'),
                items: const ['Izin', 'Sakit', 'Cuti']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'Izin'),
              ),
              if (_type == 'Cuti')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sisa cuti: ${widget.remaining} hari',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickRange,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: const Icon(Icons.date_range),
                    errorText: _rangeError ? 'Pilih tanggal terlebih dahulu' : null,
                  ),
                  child: Text(_range == null
                      ? 'Pilih tanggal'
                      : '${f.format(_range!.start)} – ${f.format(_range!.end)}  ($days hari)'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                maxLines: 4,
                maxLength: 200,
                decoration: const InputDecoration(
                    labelText: 'Alasan', alignLabelWithHint: true),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'Alasan minimal 5 karakter' : null,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
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
