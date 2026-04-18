import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'widgets/auth_wrapper.dart';
import 'utils/route_config.dart';
import 'services/auth_service.dart';
import 'utils/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await AuthService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const OusiaApp(),
    ),
  );
}

class OusiaApp extends StatefulWidget {
  const OusiaApp({super.key});

  @override
  State<OusiaApp> createState() => _OusiaAppState();
}

class _OusiaAppState extends State<OusiaApp> with WidgetsBindingObserver {
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startOrResumeSessionTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    AuthService().endSessionIfNeeded();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startOrResumeSessionTracking();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAndEndSessionTracking();
    }
  }

  Future<void> _startOrResumeSessionTracking() async {
    if (!AuthService.isLoggedIn) return;

    await AuthService().fetchSessionLimitStatus();
    if (AuthService.dailyUsageLocked.value) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }

    final started = await AuthService().startSessionIfNeeded();
    await AuthService.setupPushNotifications();

    if (!started || AuthService.dailyUsageLocked.value) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final ok = await AuthService().updateSessionHeartbeat();
      if (!ok) {
        await AuthService().fetchSessionLimitStatus();
      }

      if (AuthService.dailyUsageLocked.value) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
      }
    });
  }

  Future<void> _stopAndEndSessionTracking() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await AuthService().endSessionIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: AuthService.navigatorKey,
      title: 'Ousia',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const AuthWrapper(),
      onGenerateRoute: RouteConfig.generateRoute,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            ValueListenableBuilder<bool>(
              valueListenable: AuthService.dailyUsageLocked,
              builder: (context, isLocked, _) {
                if (!isLocked ||
                    !AuthService.isLoggedIn ||
                    AuthService.isAdmin() ||
                    AuthService.isSuperUser()) {
                  return const SizedBox.shrink();
                }
                return const _DailyUsageLockOverlay();
              },
            ),
          ],
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC3B7F5),
        brightness: Brightness.light,
        primary: const Color(0xFFC3B7F5),
        surface: const Color.fromARGB(255, 248, 248, 246),
      ),
      scaffoldBackgroundColor: const Color.fromARGB(255, 247, 247, 248),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      useMaterial3: true,
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
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 114, 43, 113),
            width: 2,
          ),
        ),
        fillColor: const Color(0xFFF5F5F5),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF7d8590)),
        prefixIconColor: const Color(0xFF7d8590),
        suffixIconColor: const Color(0xFF7d8590),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFC3B7F5)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A2E),
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color.fromARGB(255, 142, 131, 184);
          }
          return null;
        }),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC3B7F5),
        brightness: Brightness.dark,
        primary: const Color(0xFFC3B7F5),
        surface: const Color(0xFF1E1E2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF12121A),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFFC3B7F5),
          foregroundColor: const Color(0xFF12121A),
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
          borderSide: const BorderSide(color: Color(0xFF444C56)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 124, 136, 149),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 160, 159, 165),
            width: 2,
          ),
        ),
        fillColor: const Color(0xFF1E1E2E),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF7d8590)),
        prefixIconColor: const Color(0xFF7d8590),
        suffixIconColor: const Color(0xFF7d8590),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 26, 18, 18),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFC3B7F5)),
        titleTextStyle: TextStyle(
          color: Color(0xFFC3B7F5),
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFC3B7F5);
          }
          return null;
        }),
      ),
    );
  }
}

class _DailyUsageLockOverlay extends StatelessWidget {
  const _DailyUsageLockOverlay();

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Material(
          color: Colors.black.withAlpha(170),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: AuthService.dailyUsageLimitSeconds,
                builder: (context, limit, __) {
                  return ValueListenableBuilder<int>(
                    valueListenable: AuthService.remainingDailyUsageSeconds,
                    builder: (context, remaining, ___) {
                      final used = (limit - remaining).clamp(0, limit);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_off_outlined,
                            size: 40,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Daily time limit reached',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Today\'s limit: ${_formatDuration(limit)}\nUsed: ${_formatDuration(used)}',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Come back tomorrow after reset.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
