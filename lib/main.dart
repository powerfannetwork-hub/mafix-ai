import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadMafixThemeMode();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCTnwYKpvtzy8qDHrItBbVt4J3ZvvBDRlk',
      appId: '1:872559757006:android:493c8ae6e2847041f2329f',
      messagingSenderId: '872559757006',
      projectId: 'mafix-ai',
      storageBucket: 'mafix-ai.firebasestorage.app',
    ),
  );

  runApp(const MafixAIApp());
}

class MafixAIApp extends StatelessWidget {
  const MafixAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0C102A);
    const panel = Color(0xFF171D42);
    const purple = Color(0xFF6C63FF);
    const cyan = Color(0xFF39DDFF);

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: cyan,
        surface: panel,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7FC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        brightness: Brightness.light,
        primary: purple,
        secondary: const Color(0xFF087F9B),
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F7FC),
        foregroundColor: Color(0xFF17172B),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: mafixThemeMode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Mafix AI',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const HomeScreen(),
      ),
    );
  }
}
