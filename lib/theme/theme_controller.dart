import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Menyimpan pilihan tema dan memberi tahu MaterialApp saat berubah.
class ThemeController extends ChangeNotifier {
  static final ThemeController I = ThemeController._();
  ThemeController._();

  AppPalette _palette = Palettes.navy;
  AppPalette get palette => _palette;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _palette = Palettes.byId(p.getString('theme_id'));
  }

  Future<void> set(AppPalette p) async {
    if (p.id == _palette.id) return;
    _palette = p;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_id', p.id);
  }
}
