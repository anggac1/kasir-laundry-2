import 'package:flutter/material.dart';

import 'screens/beranda.dart';
import 'store/merek.dart';
import 'store/settings.dart';

// Warna latar aplikasi. Dipakai juga oleh layar peluncuran Android,
// supaya tidak ada kedipan putih sebelum beranda muncul.
const kWarnaLatar = Color(0xFFF7FAF9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dijalankan berbarengan, bukan berurutan. Keduanya tidak saling
  // bergantung, dan keduanya menahan bingkai pertama digambar.
  await Future.wait([
    Settings.instance.load(),
    Merek.instance.muat(),
  ]);
  runApp(const AplikasiLaundry());
}

class AplikasiLaundry extends StatelessWidget {
  const AplikasiLaundry({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = ColorScheme.fromSeed(seedColor: const Color(0xFF00695C));
    return MaterialApp(
      title: Merek.instance.nama,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: skema,
        useMaterial3: true,
        scaffoldBackgroundColor: kWarnaLatar,
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
