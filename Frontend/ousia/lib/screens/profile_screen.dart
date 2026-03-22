import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../utils/theme_provider.dart';
import '../utils/route_names.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  bool _isLoading = true;
  List<Post> _userPosts = [];
  final _username = AuthService.currentUser?.username ?? 'User';
  String? _userPostsNextUrl;
  bool _isLoadingMorePosts = false;
  final ScrollController _scrollController = ScrollController();

  static const Color _primary = Color(0xFF7B5CF0);

  final authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMorePosts &&
        _userPostsNextUrl != null) {
      _loadMoreUserPosts();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final authService = AuthService();
    final result = await authService.fetchProfile();
    if (mounted) {
      setState(() {
        _profile = result['success'] == true
            ? Profile.fromJson(result['data'] as Map<String, dynamic>)
            : AuthService.currentUser;
        _isLoading = false;
      });
    }
    // Fetch this user's posts after profile loads
    if (_profile != null) {
      await _loadUserPosts(_profile!.username);
    }
  }

  Future<void> _loadUserPosts(String username) async {
    final result = await authService.fetchPosts(username: username);
    if (mounted && result['success'] == true) {
      setState(() {
        _userPosts = result['posts'] as List<Post>;
        _userPostsNextUrl = result['next'];
      });
    }
  }

  Future<void> _loadMoreUserPosts() async {
    if (_userPostsNextUrl == null) return;
    setState(() => _isLoadingMorePosts = true);
    final result = await authService.fetchPosts(nextUrl: _userPostsNextUrl);
    if (mounted && result['success'] == true) {
      setState(() {
        _userPosts.addAll(result['posts'] as List<Post>);
        _userPostsNextUrl = result['next'];
        _isLoadingMorePosts = false;
      });
    } else {
      setState(() => _isLoadingMorePosts = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to logout?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.welcome,
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showUpdatePasswordSheet(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;
    String? errorMessage;
    String? successMessage;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AnimatedPadding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 16),
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Update Password',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPasswordController,
                  obscureText: !showCurrent,
                  style: GoogleFonts.inter(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(showCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setSheetState(() => showCurrent = !showCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNew,
                  style: GoogleFonts.inter(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setSheetState(() => showNew = !showNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirm,
                  style: GoogleFonts.inter(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setSheetState(() => showConfirm = !showConfirm),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                  ),
                ],
                if (successMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(successMessage!,
                      style: GoogleFonts.inter(color: Colors.green, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final current = currentPasswordController.text.trim();
                            final newPass = newPasswordController.text.trim();
                            final confirm = confirmPasswordController.text.trim();

                            if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                              setSheetState(() => errorMessage = 'Please fill in all fields');
                              return;
                            }

                            setSheetState(() => isLoading = true);
                            final authService = AuthService();
                            final result = await authService.updatePassword(
                              currentPassword: current,
                              newPassword: newPass,
                              confirmNewPassword: confirm,
                            );
                            setSheetState(() => isLoading = false);

                            if (result['success'] == true) {
                              setSheetState(() => successMessage = 'Password updated successfully!');
                              await Future.delayed(const Duration(seconds: 1));
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                            } else {
                              setSheetState(() => errorMessage = result['message'] ?? 'Failed to update password');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Update Password',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final usernameController = TextEditingController(text: _profile?.username ?? '');
    final bioController = TextEditingController(text: _profile?.bio ?? '');
    String? newPfpBase64;
    String? newPfpMimeType;
    String? localPfpPath;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Profile picture picker
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 90,
                      );
                      if (picked == null) return;

                      final cropped = await ImageCropper().cropImage(
                        sourcePath: picked.path,
                        maxWidth: 1500,
                        maxHeight: 1500,
                        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                        uiSettings: [
                          AndroidUiSettings(
                            toolbarTitle: 'Crop Profile Picture',
                            toolbarColor: Theme.of(context).colorScheme.primary,
                            toolbarWidgetColor: Colors.white,
                            lockAspectRatio: true,
                          ),
                          IOSUiSettings(
                            title: 'Crop Profile Picture',
                            aspectRatioLockEnabled: true,
                          ),
                        ],
                      );

                      if (cropped != null) {
                        final bytes = await cropped.readAsBytes();
                        final ext = cropped.path.split('.').last.toLowerCase();
                        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                        setDialogState(() {
                          newPfpBase64 = base64Encode(bytes);
                          newPfpMimeType = mime;
                          localPfpPath = cropped.path;
                        });
                      }
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: localPfpPath != null
                              ? FileImage(File(localPfpPath!))
                              : null,
                          child: localPfpPath == null
                              ? (_profile?.pfpUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        _profile!.pfpUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey.shade600,
                                    ))
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Username
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: GoogleFonts.inter(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 12),

                // Bio
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    labelStyle: GoogleFonts.inter(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                  setDialogState(() => isSaving = true);

                                  final profileResult = await authService.updateProfile(
                                    username: usernameController.text.trim(),
                                    bio: bioController.text.trim(),
                                    imagePath: localPfpPath,
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  if (profileResult['success'] == true) {
                                    _loadProfile();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Profile updated!')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(profileResult['message'] ?? 'Update failed.')),
                                    );
                                  }
                                },
                        child: isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Save', style: GoogleFonts.inter()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetHandle(),
              Text(
                'Settings',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode_outlined,
                ),
                title: Text('Dark Mode', style: GoogleFonts.inter()),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text('Update Password', style: GoogleFonts.inter()),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Update Password',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      content: Text(
                        'You can only update your password once every 2 days.',
                        style: GoogleFonts.inter(fontSize: 16, color: const Color.fromARGB(255, 166, 61, 61), fontWeight: FontWeight.w600),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel',
                              style: GoogleFonts.inter(
                                  color: const Color.fromARGB(255, 167, 162, 162))),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)
                              ),
                          ),
                          child: Text('Continue',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    _showUpdatePasswordSheet(context);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text('Delete Account',
                    style: GoogleFonts.inter(color: Colors.red)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete Account',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      content: Text(
                        'Are you sure you want to delete your account? This action cannot be undone.',
                        style: GoogleFonts.inter(fontSize: 16, color: const Color.fromARGB(255, 166, 61, 61), fontWeight: FontWeight.w600),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel',
                              style: GoogleFonts.inter(color: const Color.fromARGB(255, 167, 162, 162))),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Delete',
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final authService = AuthService();
                    final result = await authService.deleteAccount();
                    if (!mounted) return;
                    if (result['success'] == true) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Failed to delete account')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: Text('Settings', style: GoogleFonts.inter()),
              onTap: () {
                Navigator.pop(context);
                _showSettingsSheet();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
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

  Widget _buildSheetHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          _profile?.username ?? 'Profile',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showMenuBottomSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey.shade300,
                child: _profile?.pfpUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _profile!.pfpUrl!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : Icon(Icons.person, size: 48, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),

              // Username
              Text(
                _profile?.username ?? '',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              // Bio
              if (_profile?.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _profile!.bio!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Post count
              _buildStatColumn('Posts', '${_userPosts.length}'),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showEditProfileDialog,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color.fromARGB(255, 174, 170, 170)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'Edit Profile',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Share.share('Check out $_username\'s profile on Ousia!');
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color.fromARGB(255, 174, 170, 170)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'Share Profile',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Posts grid or empty state
              _userPosts.isEmpty
                  ? Column(
                      children: [
                        const Icon(Icons.photo_camera_outlined, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No Posts Yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'When you share photos and videos, they\'ll appear here.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: _userPosts.length,
                      itemBuilder: (context, index) {
                        final post = _userPosts[index];
                        final media = post.mediaFiles.isNotEmpty ? post.mediaFiles.first : null;
                        return media == null
                            ? Container(
                                color: _primary.withOpacity(0.1),
                                child: const Icon(Icons.text_snippet_outlined, color: Colors.grey),
                              )
                            : media.isVideo
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                          imageUrl: media.videoThumbnailUrl,
                                          fit: BoxFit.cover),
                                      const Align(
                                        alignment: Alignment.center,
                                        child: Icon(Icons.play_circle_outline,
                                            color: Colors.white, size: 28),
                                      ),
                                    ],
                                  )
                                : CachedNetworkImage(
                                    imageUrl: media.mediaUrl, fit: BoxFit.cover);
                      },
                    ),
            ],
          ),
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}