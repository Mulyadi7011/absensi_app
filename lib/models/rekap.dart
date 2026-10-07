class OvertimeItem {
  final String date, start, end;
  final double hours;
  final String kind; // 'Terjadwal' | 'On-Call'
  final String title;
  final bool attended; // sudah diabsen (check-in) pada sesi lembur terjadwal/on-call
  const OvertimeItem(this.date, this.start, this.end, this.hours,
      {this.kind = 'Terjadwal', this.title = '', this.attended = true});
}

/// Rekap bulanan + estimasi payroll (dihitung di "server").
class Rekap {
  final int year, month;
  final int hadir, terlambat, izin, alpa;
  final int workMinutes, lateMinutes;
  final double overtimeHours;
  final List<OvertimeItem> overtime;
  final int eventAttended; // meeting/pelatihan yang dihadiri bulan ini
  final int eventInvited; // undangan meeting/pelatihan bulan ini
  final double baseSalary, mealAllowance, overtimePay, lateDeduction, alpaDeduction;

  const Rekap({
    required this.year,
    required this.month,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.alpa,
    required this.workMinutes,
    required this.lateMinutes,
    required this.overtimeHours,
    required this.overtime,
    this.eventAttended = 0,
    this.eventInvited = 0,
    required this.baseSalary,
    required this.mealAllowance,
    required this.overtimePay,
    required this.lateDeduction,
    required this.alpaDeduction,
  });

  double get gross => baseSalary + mealAllowance + overtimePay;
  double get deductions => lateDeduction + alpaDeduction;
  double get net => gross - deductions;
}
