import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Daftar pilihan tema (3 palet). Perubahan langsung diterapkan & disimpan.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  Widget _dot(Color color, Color border) => Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.I,
      builder: (context, _) {
        final cur = context.c;
        final selected = ThemeController.I.palette.id;
        return Column(
          children: Palettes.all.map((p) {
            final sel = p.id == selected;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => ThemeController.I.set(p),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cur.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel ? cur.primary : cur.border, width: sel ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Row(children: [
                        _dot(p.colors.primary, cur.border),
                        _dot(p.colors.accent, cur.border),
                        _dot(p.colors.bg, cur.border),
                      ]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, color: cur.text)),
                            Text(p.tagline,
                                style: TextStyle(fontSize: 12, color: cur.muted)),
                          ],
                        ),
                      ),
                      if (sel) Icon(Icons.check_circle, color: cur.primary),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

void showThemeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih Tema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          ThemePicker(),
        ],
      ),
    ),
  );
}
