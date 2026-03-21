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
import '../screens/quiz_screen.dart';
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

      case RouteNames.home:
      case RouteNames.feed:
        return MaterialPageRoute(builder: (_) => const FeedPage());

      case RouteNames.createPost:
        return MaterialPageRoute(builder: (_) => const CreatePostPage());
      
      case RouteNames.quiz:
        return MaterialPageRoute(builder: (_) => const PlayPage());

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