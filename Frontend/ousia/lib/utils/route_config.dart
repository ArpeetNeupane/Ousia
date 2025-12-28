import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
// import '../screens/forgot_password_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/signup_continue_screen.dart';
// import '../screens/edit_profile_screen.dart';
import 'route_names.dart';

class RouteConfig {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case RouteNames.signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      
      // case RouteNames.forgotPassword:
      //   return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      
      case RouteNames.home:
      case RouteNames.feed:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());

      case RouteNames.signupContinue:
        return MaterialPageRoute(builder: (_) => const SignupContinueScreen());
      
      // case RouteNames.profile:
      //   return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      // case RouteNames.editProfile:
      //   return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  // Helper method to navigate and clear stack (for login/logout scenarios)
  static void navigateAndClearStack(BuildContext context, String routeName) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
    );
  }

  // Helper method to check if route is auth-related(authentication not required)
  static bool isAuthRoute(String? routeName) {
    return routeName == RouteNames.welcome ||
            routeName == RouteNames.login ||
            routeName == RouteNames.signup ||
            routeName == RouteNames.forgotPassword;
  }
}