import 'package:flutter/material.dart';

/// Pasangan warna semantik: teks/ikon (fg) di atas latar pastel (bg).
class Tone {
  final Color fg;
  final Color bg;
  const Tone(this.fg, this.bg);
}

/// Semua warna aplikasi dikumpulkan di sini (design tokens).
/// Ganti palet = ganti satu objek AppColors.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary, onPrimary, accent, onAccent, bg, surface, border, text, muted;
  final Tone success, warning, danger, info, neutral;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, Color.lerp(primary, accent, 0.3)!],
      );

  /// Status absensi / pengajuan -> warna semantik
  Tone forStatus(String s) {
    switch (s) {
      case 'Hadir':
      case 'Disetujui':
        return success;
      case 'Terlambat':
      case 'Menunggu':
        return warning;
      case 'Alpa':
      case 'Ditolak':
        return danger;
      case 'Izin':
      case 'Sakit':
      case 'Cuti':
        return info;
      default:
        return neutral;
    }
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) =>
      (other != null && t >= 0.5) ? other : this;
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

class AppPalette {
  final String id, name, tagline;
  final AppColors colors;
  const AppPalette(this.id, this.name, this.tagline, this.colors);
}

const _success = Tone(Color(0xFF15803D), Color(0xFFDCFCE7));
const _warning = Tone(Color(0xFFB45309), Color(0xFFFEF3C7));
const _danger = Tone(Color(0xFFB91C1C), Color(0xFFFEE2E2));
const _info = Tone(Color(0xFF1D4ED8), Color(0xFFDBEAFE));
const _neutral = Tone(Color(0xFF6B7280), Color(0xFFF3F4F6));

class Palettes {
  static const navy = AppPalette(
    'navy',
    'Corporate Navy',
    'Terpercaya dan formal',
    AppColors(
      primary: Color(0xFF0B2A4A),
      onPrimary: Colors.white,
      accent: Color(0xFF2563EB),
      onAccent: Colors.white,
      bg: Color(0xFFF4F6F9),
      surface: Colors.white,
      border: Color(0xFFE5E7EB),
      text: Color(0xFF111827),
      muted: Color(0xFF6B7280),
      success: _success,
      warning: _warning,
      danger: _danger,
      info: _info,
      neutral: _neutral,
    ),
  );

  static const indigo = AppPalette(
    'indigo',
    'Modern Indigo',
    'Segar dan modern',
    AppColors(
      primary: Color(0xFF3730A3),
      onPrimary: Colors.white,
      accent: Color(0xFF14B8A6),
      onAccent: Color(0xFF04302B),
      bg: Color(0xFFF6F7FB),
      surface: Colors.white,
      border: Color(0xFFE5E7EB),
      text: Color(0xFF111827),
      muted: Color(0xFF6B7280),
      success: _success,
      warning: _warning,
      danger: _danger,
      info: _info,
      neutral: _neutral,
    ),
  );

  static const emerald = AppPalette(
    'emerald',
    'Minimal Emerald',
    'Bersih dan premium',
    AppColors(
      primary: Color(0xFF111827),
      onPrimary: Colors.white,
      accent: Color(0xFF10B981),
      onAccent: Color(0xFF04291D),
      bg: Color(0xFFF7F8F7),
      surface: Colors.white,
      border: Color(0xFFE5E7EB),
      text: Color(0xFF111827),
      muted: Color(0xFF6B7280),
      success: _success,
      warning: _warning,
      danger: _danger,
      info: _info,
      neutral: _neutral,
    ),
  );

  static const all = [navy, indigo, emerald];

  static AppPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => navy);
}

class AppTheme {
  static OutlineInputBorder _ob(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  static ThemeData build(AppColors c) {
    final scheme = ColorScheme.light(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.accent.withValues(alpha: 0.14),
      onPrimaryContainer: c.primary,
      secondary: c.accent,
      onSecondary: c.onAccent,
      surface: c.surface,
      onSurface: c.text,
      error: c.danger.fg,
      outline: c.border,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle:
            TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.muted,
        indicatorColor: c.primary,
        dividerColor: c.border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _ob(c.border),
        enabledBorder: _ob(c.border),
        focusedBorder: _ob(c.primary, 1.8),
        errorBorder: _ob(c.danger.fg),
        focusedErrorBorder: _ob(c.danger.fg, 1.8),
        labelStyle: TextStyle(color: c.muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x26000000),
        indicatorColor: c.accent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.primary : c.muted)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight:
                  s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? c.primary : c.muted,
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
