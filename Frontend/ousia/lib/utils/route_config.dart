import 'package:flutter/material.dart';
import 'package:ousia/screens/main_navigation_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/user_interest_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/signup_continue_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/friend_request_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/forgot_password_screen.dart';
import 'route_names.dart';
import '../services/auth_service.dart';

int? _toNullableInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class RouteConfig {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    if (settings.name == RouteNames.adminDash) {
      if (!AuthService.isAdmin() && !AuthService.isSuperUser()) {
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
      }
    }

    switch (settings.name) {
      case RouteNames.adminDash:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
      
      case RouteNames.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case RouteNames.signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      
      case RouteNames.userInterest:
        return MaterialPageRoute(builder: (_) => const UserInterestScreen());
      
      case RouteNames.mainNav:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());

      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case RouteNames.othersProfile:
        final userId = settings.arguments as int;
        return MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId));
      
      case RouteNames.friendRequests:
        return MaterialPageRoute(builder: (_) => const FriendRequestsPage());

      case RouteNames.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case RouteNames.home:
      case RouteNames.feed:
        return MaterialPageRoute(builder: (_) => const FeedPage());

      case RouteNames.createPost:
        return MaterialPageRoute(builder: (_) => const CreatePostPage());
      
      case RouteNames.quiz:
        return MaterialPageRoute(builder: (_) => const PlayPage());
      
      case RouteNames.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case RouteNames.signupContinue:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => SignupContinueScreen(
            username: args['username'],
            email: args['email'],
            password: args['password'],
            confirmPassword: args['confirmPassword'],
          ),
        );
      
      case RouteNames.chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: args['conversation_id'],
            name: args['name'],
            pfpUrl: args['pfp_url'],
            isGroup: args['is_group'] ?? false,
            otherUserId: _toNullableInt(args['other_user_id']),
          ),
        );
      
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