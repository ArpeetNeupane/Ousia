import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/welcome_screen.dart';
// import '../screens/feed_screen.dart';
import '../screens/main_navigation_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      await AuthService.initialize();
      if (!mounted) return;
      setState(() {
        _isAuthenticated = AuthService.isLoggedIn;
      });
    } catch (e) {
      debugPrint("Auth check failed: $e");
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAuthenticated 
        // ? const FeedPage()
        ? const MainNavigationScreen()
        : const WelcomeScreen();
  }
}