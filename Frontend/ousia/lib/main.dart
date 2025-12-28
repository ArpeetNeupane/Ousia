import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/auth_wrapper.dart';
import 'utils/route_config.dart';
import 'services/auth_service.dart';

void main() async {
  // Ensures flutter’s widget system and engine are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  runApp(const OusiaApp());
}

class OusiaApp extends StatelessWidget {
  const OusiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ousia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed( // fromSeed generates palletes based on seed color
          seedColor: const Color(0xFFC3B7F5),
          brightness: Brightness.light,
          primary: const Color(0xFFC3B7F5),
          surface: const Color(0xFFffdfb1), // Card/bg surfaces
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 247, 247, 248),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        useMaterial3: true, // Enables Material Design 3 styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFFC3B7F5),
            foregroundColor: const Color.fromARGB(250, 250, 250, 250),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: const Color(0xFFC3B7F5),
            side: const BorderSide(color: Color(0xFFC3B7F5), width: 1.5),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30363d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30363d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFfb5607), width: 2),
          ),
          fillColor: const Color(0xFF21262d),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: const TextStyle(color: Color(0xFF7d8590)),
          prefixIconColor: const Color(0xFF7d8590),
          suffixIconColor: const Color(0xFF7d8590),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0d1117),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFC3B7F5)),
          titleTextStyle: TextStyle(color: Color.fromARGB(255, 136, 18, 105)),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return const Color.fromARGB(255, 142, 131, 184);
            }
            return null;
          }),
        ),
      ),
      home: const AuthWrapper(),
      onGenerateRoute: RouteConfig.generateRoute,
    );
  }
}
