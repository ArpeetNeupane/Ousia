import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../models/post.dart';
import 'feed_screen.dart';
import 'conversation_screen.dart';
import 'quiz_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_moderation_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  static const Color _primary = Color(0xFF7B5CF0);
  Key _feedKey = UniqueKey();
  Post? _newlyCreatedPost;
  bool get _isAdmin => AuthService.isAdmin() || AuthService.isSuperUser();
  Timer? _notificationRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.startNotificationsStream(onNotification: (notification) {
      if (!mounted) return;
      final body = (notification['body'] ?? '').toString();
      if (body.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body),
          duration: const Duration(seconds: 2),
        ),
      );
    });
    _refreshNotificationCount();
    _notificationRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshNotificationCount();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationCount();
    }
  }

  void _refreshNotificationCount() {
    AuthService().refreshUnreadNotificationCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRefreshTimer?.cancel();
    AuthService.stopNotificationsStream();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (!_isAdmin && index == 2) {
      Navigator.pushNamed(context, '/create-post').then((result) {
        Post? createdPost;
        bool created = false;

        if (result == true) {
          created = true;
        } else if (result is Map) {
          created = result['created'] == true;
          final postData = result['postData'];
          if (postData is Map<String, dynamic>) {
            try {
              createdPost = Post.fromJson(postData);
            } catch (_) {}
          }
        }

        if (created) {
          setState(() {
            _newlyCreatedPost = createdPost;
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
    List<Widget> stackChildren;
    int stackIndex;

    if (_isAdmin) {
      stackChildren = [
        const AdminDashboardScreen(),
        const AdminModerationScreen(),
        const AdminProfileScreen(),
      ];
      stackIndex = _currentIndex;
    } else {
      stackChildren = [
        FeedPage(key: _feedKey, createdPost: _newlyCreatedPost),
        const MessagesPage(),
        const PlayPage(),
        const ProfileScreen(),
      ];
      stackIndex = _currentIndex > 2 ? _currentIndex - 1 : _currentIndex;
    }

    return Scaffold(
      body: IndexedStack(
        index: stackIndex,
        children: stackChildren,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        primaryColor: _primary,
        isAdmin: _isAdmin,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color primaryColor;
  final bool isAdmin;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.primaryColor,
    required this.isAdmin,
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
            children: isAdmin ? _buildAdminItems() : _buildUserItems(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAdminItems() {
    return [
      _NavItem(
        index: 0,
        currentIndex: currentIndex,
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        onTap: onTap,
        primaryColor: primaryColor,
      ),
      _NavItem(
        index: 1,
        currentIndex: currentIndex,
        icon: Icons.gavel_outlined,
        activeIcon: Icons.gavel,
        label: 'Review',
        onTap: onTap,
        primaryColor: primaryColor,
      ),
      _NavItem(
        index: 2,
        currentIndex: currentIndex,
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        onTap: onTap,
        primaryColor: primaryColor,
      ),
    ];
  }

  List<Widget> _buildUserItems() {
    return [
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
    ];
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