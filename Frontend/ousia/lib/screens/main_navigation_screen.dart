import 'package:flutter/material.dart';
import '../services/auth_service.dart';
// import 'feed_screen.dart';
// import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    // const FeedScreen(),
    // const SearchScreen(),
    // const ReelsScreen(),
    // const ActivityScreen(),
    // const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Navigation'),
        backgroundColor: Colors.purple[300],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Call your logout function
              await AuthService.logout();

              // Navigate back to login or signup screen
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login', // adjust according to your route
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Color.fromARGB(255, 180, 166, 220),
        unselectedItemColor: const Color.fromARGB(255, 255, 255, 255),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Placeholder screens for now
// class SearchScreen extends StatelessWidget {
//   const SearchScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Text(
//           'Search Screen',
//           style: TextStyle(fontSize: 24),
//         ),
//       ),
//     );
//   }
// }

// class ReelsScreen extends StatelessWidget {
//   const ReelsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Text(
//           'Reels Screen',
//           style: TextStyle(fontSize: 24),
//         ),
//       ),
//     );
//   }
// }

// class ActivityScreen extends StatelessWidget {
//   const ActivityScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Text(
//           'Activity Screen',
//           style: TextStyle(fontSize: 24),
//         ),
//       ),
//     );
//   }
// }