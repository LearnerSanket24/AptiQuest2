import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_constants.dart';
import 'firebase_options.dart';
import 'services/audio_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Keep local/offline flows available even if Firebase is unavailable.
    debugPrint('Firebase initialization skipped: $e');
  }

  runApp(const AptiQuestApp());
}

class AptiQuestApp extends StatelessWidget {
  const AptiQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AptiQuestAppRoot();
  }
}

class _AptiQuestAppRoot extends StatefulWidget {
  const _AptiQuestAppRoot();

  @override
  State<_AptiQuestAppRoot> createState() => _AptiQuestAppRootState();
}

class _AptiQuestAppRootState extends State<_AptiQuestAppRoot>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioService.instance.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AudioService.instance.handleLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aptiquest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF006D77),
          secondary: Color(0xFFFFE082),
          surface: AppColors.card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF12314A),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Color(0xFFFFE082),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006D77),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFE082),
            side: const BorderSide(color: Color(0xFFFFE082)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
          hintStyle: const TextStyle(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white70,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}