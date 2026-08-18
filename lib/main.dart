import 'package:flutter/material.dart';

import 'screens/beranda.dart';
import 'store/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.load();
  runApp(const AplikasiLaundry());
}

class AplikasiLaundry extends StatelessWidget {
  const AplikasiLaundry({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = ColorScheme.fromSeed(seedColor: const Color(0xFF00695C));
    return MaterialApp(
      title: 'Kasir Laundry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: skema,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
      home: const BerandaScreen(),
    );
  }
}
