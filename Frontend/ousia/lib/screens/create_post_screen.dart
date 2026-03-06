import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ousia/services/auth_service.dart';


// Post Visibility Enum/Choices
enum PostVisibility {
  public('public', 'Public', Icons.public),
  friendsOnly('friends_only', 'Friends Only', Icons.people),
  private('private', 'Private', Icons.lock);

  final String value;
  final String label;
  final IconData icon;
  const PostVisibility(this.value, this.label, this.icon);
}

//Selected media model
class _SelectedMedia {
  final XFile file;
  final bool isVideo;
  _SelectedMedia({required this.file, required this.isVideo});
}

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final AuthService _service = AuthService();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  static const Color _primary = Color(0xFF7B5CF0);

  // Profile
  String? _pfpUrl;
  String _username = '';
  bool _profileLoading = true;

  // Media
  final List<_SelectedMedia> _mediaFiles = [];

  // Visibility
  PostVisibility _visibility = PostVisibility.friendsOnly;

  // Submission
  bool _isPosting = false;

  // Limits
  static const int _maxTotal = 5;
  static const int _maxVideos = 2;
  static const int _maxImages = 3;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result = await _service.fetchProfile();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      setState(() {
        _pfpUrl = data['pfp_url'];
        _username = data['synced_username'] ?? '';
        _profileLoading = false;
      });
    } else {
      setState(() => _profileLoading = false);
    }
  }

  int get _videoCount => _mediaFiles.where((m) => m.isVideo).length;
  int get _imageCount => _mediaFiles.where((m) => !m.isVideo).length;

  Future<void> _pickMedia({required bool isVideo}) async {
    // Check limits
    if (_mediaFiles.length >= _maxTotal) {
      _showSnack('Maximum $_maxTotal files allowed');
      return;
    }
    if (isVideo && _videoCount >= _maxVideos) {
      _showSnack('Maximum $_maxVideos videos allowed');
      return;
    }
    if (!isVideo && _imageCount >= _maxImages) {
      _showSnack('Maximum $_maxImages images allowed');
      return;
    }

    try {
      if (isVideo) {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          setState(() => _mediaFiles.add(_SelectedMedia(file: file, isVideo: true)));
        }
      } else {
        final List<XFile> files = await _picker.pickMultiImage();
        for (final file in files) {
          if (_mediaFiles.length >= _maxTotal) break;
          if (_imageCount >= _maxImages) break;
          setState(() => _mediaFiles.add(_SelectedMedia(file: file, isVideo: false)));
        }
      }
    } catch (e) {
      _showSnack('Failed to pick media');
    }
  }

  void _removeMedia(int index) {
    setState(() => _mediaFiles.removeAt(index));
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    final typeOfPost = _typeController.text.trim();

    if (caption.isEmpty && _mediaFiles.isEmpty) {
      _showSnack('Add a caption or media to post');
      return;
    }

    setState(() => _isPosting = true);

    final result = await _service.createPost(
      caption: caption.isEmpty ? null : caption,
      visibility: _visibility.value,
      typeOfPost: typeOfPost.isEmpty ? null : typeOfPost,
      mediaFiles: _mediaFiles.map((m) => File(m.file.path)).toList()
    );

    if (!mounted) return;
    setState(() => _isPosting = false);

    if (result['success'] == true) {
      Navigator.pop(context, true); // true = feed should refresh
    } else {
      _showSnack(result['message'] ?? 'Failed to create post');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _showVisibilitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VisibilitySheet(
        current: _visibility,
        primaryColor: _primary,
        onSelected: (v) {
          setState(() => _visibility = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: _buildAppBar(),
      body: _profileLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B5CF0)))
          : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'New Post',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _isPosting
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF7B5CF0),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _submitPost,
                  child: const Text(
                    'Post',
                    style: TextStyle(
                      color: Color(0xFF7B5CF0),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row + visibility
          _buildUserRow(),
          const SizedBox(height: 16),

          // Caption field
          _buildCaptionField(),
          const SizedBox(height: 12),

          // Type of post / hashtag
          _buildTypeField(),
          const SizedBox(height: 20),

          // Media preview grid
          if (_mediaFiles.isNotEmpty) ...[
            _buildMediaGrid(),
            const SizedBox(height: 16),
          ],

          // Media add buttons
          _buildMediaButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserRow() {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE0E0E0),
          backgroundImage: (_pfpUrl != null && _pfpUrl!.isNotEmpty)
              ? CachedNetworkImageProvider(_pfpUrl!)
              : null,
          child: (_pfpUrl == null || _pfpUrl!.isEmpty)
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : null,
        ),
        const SizedBox(width: 12),

        // Username
        Expanded(
          child: Text(
            _username,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),

        // Visibility button
        GestureDetector(
          onTap: _showVisibilitySheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_visibility.icon, color: _primary, size: 14),
                const SizedBox(width: 5),
                Text(
                  _visibility.label,
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: _primary, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _captionController,
        maxLines: 5,
        minLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: "What's on your mind?",
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildTypeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _typeController,
        maxLines: 1,
        decoration: InputDecoration(
          hintText: 'Add a topic  e.g. #Anime',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(Icons.tag, color: _primary, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _mediaFiles.length,
      itemBuilder: (context, index) {
        final media = _mediaFiles[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: media.isVideo
                  ? Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(Icons.videocam, color: Colors.white, size: 32),
                      ),
                    )
                  : Image.file(
                      File(media.file.path),
                      fit: BoxFit.cover,
                    ),
            ),

            // Video badge
            if (media.isVideo)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'VID',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

            // Remove button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeMedia(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaButtons() {
    final bool canAddMore = _mediaFiles.length < _maxTotal;
    final bool canAddImage = _imageCount < _maxImages;
    final bool canAddVideo = _videoCount < _maxVideos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Counter hint
        Text(
          '${_mediaFiles.length}/$_maxTotal files  ·  ${_imageCount}/$_maxImages images  ·  ${_videoCount}/$_maxVideos videos',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Add image
            Expanded(
              child: _MediaButton(
                icon: Icons.image_outlined,
                label: 'Add Image',
                enabled: canAddMore && canAddImage,
                primaryColor: _primary,
                onTap: () => _pickMedia(isVideo: false),
              ),
            ),
            const SizedBox(width: 12),

            // Add video
            Expanded(
              child: _MediaButton(
                icon: Icons.videocam_outlined,
                label: 'Add Video',
                enabled: canAddMore && canAddVideo,
                primaryColor: _primary,
                onTap: () => _pickMedia(isVideo: true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Media button

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color primaryColor;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? primaryColor.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: enabled ? primaryColor : Colors.grey, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? primaryColor : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Visibility bottom sheet

class _VisibilitySheet extends StatelessWidget {
  final PostVisibility current;
  final Color primaryColor;
  final ValueChanged<PostVisibility> onSelected;

  const _VisibilitySheet({
    required this.current,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Who can see this?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 16),
          ...PostVisibility.values.map((v) => _VisibilityOption(
                visibility: v,
                isSelected: v == current,
                primaryColor: primaryColor,
                onTap: () => onSelected(v),
              )),
        ],
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final PostVisibility visibility;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.visibility,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.08) : const Color(0xFFF8F7FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(visibility.icon, color: isSelected ? primaryColor : Colors.grey, size: 22),
            const SizedBox(width: 14),
            Text(
              visibility.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.black87,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}