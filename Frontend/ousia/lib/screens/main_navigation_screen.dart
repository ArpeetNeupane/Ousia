import 'package:flutter/material.dart';
import 'package:ousia/screens/quiz_screen.dart';
// import 'package:ousia/services/auth_service.dart';
import 'feed_screen.dart';
// import 'message_screen.dart';
import 'create_post_screen.dart';
// import 'play_screen.dart';
import 'profile_screen.dart';


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const Color _primary = Color(0xFF7B5CF0);

  final List<Widget> _screens = [
    const FeedPage(),
    const _PlaceholderScreen(label: 'Messages'),
    const CreatePostPage(),
    const PlayPage(),
    const ProfileScreen(),
  ];

  Key _feedKey = UniqueKey();

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.pushNamed(context, '/create-post').then((result) {
        if (result == true) {
          setState(() {
            _feedKey = UniqueKey();
            _currentIndex = 0;
          });
        }
      });
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        // Skipping index 2 (Post) since it navigates away — clamping to avoid out-of-range
        index: _currentIndex > 2 ? _currentIndex - 1 : _currentIndex,
        children: [
          FeedPage(key: _feedKey), // Home / Feed
          _screens[1], // Messages
          _screens[3], // Quiz
          _screens[4], // Profile
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        primaryColor: _primary,
      ),
    );
  }
}

// Bottom nav bar
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color primaryColor;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                onTap: onTap,
                primaryColor: primaryColor,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.send_outlined,
                activeIcon: Icons.send,
                label: 'Message',
                onTap: onTap,
                primaryColor: primaryColor,
              ),

              SizedBox(
                width: 56,
                height: 60,
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
              ),

              _NavItem(
                index: 3,
                currentIndex: currentIndex,
                icon: Icons.extension_outlined,
                activeIcon: Icons.extension,
                label: 'Play',
                onTap: onTap,
                primaryColor: primaryColor,
              ),
              _NavItem(
                index: 4,
                currentIndex: currentIndex,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                onTap: onTap,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;
  final Color primaryColor;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? primaryColor : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Temporary placeholder
class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(fontSize: 22, color: Colors.grey),
      ),
    );
  }
}