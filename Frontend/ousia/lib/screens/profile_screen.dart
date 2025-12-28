import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../utils/route_names.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _profile = AuthService.currentUser;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await AuthService.logout();
              if (mounted) {
                // Navigate to welcome screen and clear entire navigation stack
                navigator.pushNamedAndRemoveUntil(
                  RouteNames.welcome, 
                  (Route<dynamic> route) => false,
                );
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _profile?.username ?? 'Profile',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              _showMenuBottomSheet();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Row(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade300,
                  child: _profile?.pfpPublicId != null
                      ? ClipOval(
                          child: Image.network(
                            'https://res.cloudinary.com/your-cloud-name/image/upload/${_profile!.pfpPublicId}',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey.shade600,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey.shade600,
                        ),
                ),
                const SizedBox(width: 20),
                
                // Stats
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Posts', '0'),
                      _buildStatColumn('Followers', '0'),
                      _buildStatColumn('Following', '0'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Profile Info
            if (_profile?.bio?.isNotEmpty == true) ...[
              Text(
                _profile!.bio!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            if (_profile?.address?.isNotEmpty == true) ...[
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _profile!.address!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 16),
            ],
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.editProfile);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Share profile functionality
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Share Profile',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Posts Grid (Empty for now)
            const Divider(),
            const SizedBox(height: 16),
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Posts Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'When you share photos and videos, they\'ll appear on your profile.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(
                'Settings',
                style: GoogleFonts.inter(),
              ),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(
                'Saved',
                style: GoogleFonts.inter(),
              ),
              onTap: () {
                Navigator.pop(context);
                // Navigate to saved posts
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout',
                style: GoogleFonts.inter(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}