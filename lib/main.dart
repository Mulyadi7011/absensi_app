import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await ThemeController.I.load();
  final loggedIn = await ApiService.isLoggedIn();
  runApp(AbsensiApp(loggedIn: loggedIn));
}

class AbsensiApp extends StatelessWidget {
  final bool loggedIn;
  const AbsensiApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.I,
      builder: (context, _) => MaterialApp(
        title: 'Absensi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(ThemeController.I.palette.colors),
        home: loggedIn ? const HomeShell() : const LoginScreen(),
      ),
    );
  }
}
