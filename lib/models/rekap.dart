class OvertimeItem {
  final String date, start, end;
  final double hours;
  const OvertimeItem(this.date, this.start, this.end, this.hours);
}

/// Rekap bulanan + estimasi payroll (dihitung di "server").
class Rekap {
  final int year, month;
  final int hadir, terlambat, izin, alpa;
  final int workMinutes, lateMinutes;
  final double overtimeHours;
  final List<OvertimeItem> overtime;
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
