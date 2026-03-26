import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ousia/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import '../models/profile.dart';
import '../models/post.dart';

enum UserProfilePostCategory {
  media,
  captionOnly,
}

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _service = AuthService();
  Profile? _profile;
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _nextUrl;
  bool _isLoadingMore = false;
  bool _friendRequestSent = false;
  bool _isFriend = false;
  bool _hasReceivedRequest = false;
  int? _receivedRequestId;
  int? _sentRequestId;
  final ScrollController _scrollController = ScrollController();
  UserProfilePostCategory _selectedPostCategory = UserProfilePostCategory.media;
  final Map<int, Map<String, dynamic>> _captionOnlyPostDetails = {};
  bool _isLoadingCaptionPostDetails = false;

  static const Color _primary = Color(0xFF7B5CF0);

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent == 0) return; // not scrollable yet
    if (position.pixels >= position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _nextUrl != null) {
      _loadMorePosts();
    }
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _hasError = false; });
    final authService = AuthService();
    final profileResult = await authService.fetchUserProfile(widget.userId);
    if (!mounted) return;
    if (profileResult['success'] != true) {
      setState(() { _hasError = true; _isLoading = false; });
      return;
    }
    final profile = profileResult['profile'] as Profile;

    final results = await Future.wait([
      _service.fetchPosts(username: profile.username),
      _service.checkFriendRequestStatus(profile.username),
      _service.checkFriendship(widget.userId),
    ]);
    if (!mounted) return;

    final postsResult = results[0];
    final friendResult = results[1];
    final friendshipResult = results[2];

    setState(() {
      _profile = profile;
      if (postsResult['success'] == true) {
        _posts = postsResult['posts'] as List<Post>;
        _nextUrl = postsResult['next'];
      }
      _friendRequestSent = friendResult['sent'] == true;
      _isFriend = friendshipResult['is_friend'] == true;
      _friendRequestSent = friendResult['sent'] == true;
      _sentRequestId = friendResult['sent_request_id'];
      _hasReceivedRequest = friendResult['received'] == true;
      _receivedRequestId = friendResult['received_request_id'];
      _isLoading = false;
    });

    if (_selectedPostCategory == UserProfilePostCategory.captionOnly) {
      await _loadCaptionOnlyPostDetails();
    } else {
      _scheduleEnsureScrollableMediaPosts();
    }

  }

  Future<void> _loadMorePosts() async {
    setState(() => _isLoadingMore = true);
    final result = await _service.fetchPosts(nextUrl: _nextUrl);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _posts.addAll(result['posts'] as List<Post>);
        _nextUrl = result['next'];
      });
      if (_selectedPostCategory == UserProfilePostCategory.captionOnly) {
        await _loadCaptionOnlyPostDetails();
      } else {
        _scheduleEnsureScrollableMediaPosts();
      }
    }
    setState(() => _isLoadingMore = false);
  }

  void _scheduleEnsureScrollableMediaPosts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureScrollableMediaPosts();
    });
  }

  Future<void> _ensureScrollableMediaPosts() async {
    if (!mounted) return;
    if (_selectedPostCategory != UserProfilePostCategory.media) return;
    if (_isLoadingMore || _nextUrl == null) return;
    if (!_scrollController.hasClients) return;

    final isScrollable = _scrollController.position.maxScrollExtent > 0;
    if (isScrollable && _mediaPosts.isNotEmpty) return;

    await _loadMorePosts();
  }

  List<Post> get _mediaPosts => _posts.where((p) => p.mediaFiles.isNotEmpty).toList();
  List<Post> get _captionOnlyPosts => _posts.where((p) => p.mediaFiles.isEmpty).toList();

  Future<void> _loadCaptionOnlyPostDetails() async {
    if (_isLoadingCaptionPostDetails) return;

    final targets = _captionOnlyPosts
        .where((post) => !_captionOnlyPostDetails.containsKey(post.id))
        .toList();
    if (targets.isEmpty) return;

    setState(() => _isLoadingCaptionPostDetails = true);
    final futures = targets.map((post) async {
      final result = await _service.fetchPostById(post.id);
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        _captionOnlyPostDetails[post.id] = result['data'] as Map<String, dynamic>;
      }
    });

    await Future.wait(futures);
    if (!mounted) return;
    setState(() => _isLoadingCaptionPostDetails = false);
  }

  Future<void> _sendFriendRequest() async {
    if (_profile == null) return;
    final result = await _service.sendFriendRequest(_profile!.username);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _friendRequestSent = true;
        _sentRequestId = result['data']?['id'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to send request')),
      );
    }
  }

  Future<void> _cancelFriendRequest() async {
    if (_sentRequestId == null) return;
    final result = await _service.deleteFriendRequest(_sentRequestId!);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _friendRequestSent = false;
        _sentRequestId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _profile?.username ?? '',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('Could not load profile', style: GoogleFonts.inter(color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _loadAll, child: Text('Retry', style: GoogleFonts.inter())),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      (_selectedPostCategory == UserProfilePostCategory.media ? _mediaPosts : _captionOnlyPosts).isEmpty
                          ? const SliverFillRemaining(
                              child: Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_camera_outlined, size: 60, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No Posts Yet', style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ],
                              )),
                            )
                          : _selectedPostCategory == UserProfilePostCategory.media
                              ? SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverGrid(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _buildPostTile(_mediaPosts[index]),
                                      childCount: _mediaPosts.length,
                                    ),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      if (_isLoadingCaptionPostDetails)
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: LinearProgressIndicator(minHeight: 2),
                                        ),
                                      ..._captionOnlyPosts.map(_buildCaptionOnlyPostCard),
                                    ]),
                                  ),
                                ),
                      if (_isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: _profile?.pfpUrl != null
                ? CachedNetworkImageProvider(_profile!.pfpUrl!)
                : null,
            child: _profile?.pfpUrl == null
                ? Icon(Icons.person, size: 48, color: Colors.grey.shade600)
                : null,
          ),
          const SizedBox(height: 10),
          Text(_profile?.username ?? '',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          if (_profile?.bio?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_profile!.bio!,
                  style: GoogleFonts.inter(fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 20),
          Column(children: [
            Text('${_posts.length}',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            Text('Posts', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _hasReceivedRequest
                    ? ElevatedButton(
                        onPressed: () async {
                          if (_receivedRequestId == null) return;
                          final result = await showDialog<String>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('Friend Request',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              content: Text(
                                '${_profile?.username} sent you a friend request.',
                                style: GoogleFonts.inter(fontSize: 14, color: const Color.fromARGB(255, 154, 152, 152)),
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, 'rejected'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 236, 115, 133),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text('Decline',
                                      style: GoogleFonts.inter(
                                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, 'accepted'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text('Confirm',
                                      style: GoogleFonts.inter(
                                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                ),
                              ],
                            ),
                          );
                          if (result != null) {
                            final response = await _service.respondFriendRequest(_receivedRequestId!, result);
                            if (!mounted) return;
                            if (response['success'] == true) {
                              setState(() {
                                _hasReceivedRequest = false;
                                if (result == 'accepted') _isFriend = true;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 170, 214, 24),
                          disabledBackgroundColor: _primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text('Respond',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, color: Colors.black)),
                      )
                    : Opacity(
                        opacity: (_friendRequestSent || _isFriend) ? 0.8 : 1.0,
                        child: ElevatedButton(
                          onPressed: _isFriend ? null : _friendRequestSent ? _cancelFriendRequest : _sendFriendRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFriend ? Colors.green : _primary,
                            disabledBackgroundColor: _isFriend ? Colors.green : _primary.withOpacity(0.6),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isFriend) ...[
                                const Icon(Icons.check, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _isFriend ? 'Friends' : _friendRequestSent ? 'Cancel Request' : 'Add Friend',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Share.share('Check out ${_profile?.username}\'s profile on Ousia!'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color.fromARGB(255, 174, 170, 170)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text('Share Profile',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<UserProfilePostCategory>(
              value: _selectedPostCategory,
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _selectedPostCategory = value);
                if (value == UserProfilePostCategory.captionOnly) {
                  await _loadCaptionOnlyPostDetails();
                } else {
                  _scheduleEnsureScrollableMediaPosts();
                }
              },
              items: const [
                DropdownMenuItem(
                  value: UserProfilePostCategory.media,
                  child: Text('Media Posts'),
                ),
                DropdownMenuItem(
                  value: UserProfilePostCategory.captionOnly,
                  child: Text('Caption Only'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTile(Post post) {
    final media = post.mediaFiles.isNotEmpty ? post.mediaFiles.first : null;
    return GestureDetector(
      onTap: () {},
      child: media == null
          ? Container(
              color: _primary.withOpacity(0.1),
              child: const Icon(Icons.article_outlined, color: Colors.grey),
            )
          : media.isVideo
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: media.videoThumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 28),
                    ),
                  ],
                )
              : CachedNetworkImage(imageUrl: media.mediaUrl, fit: BoxFit.cover),
    );
  }

  Widget _buildCaptionOnlyPostCard(Post post) {
    final detail = _captionOnlyPostDetails[post.id];
    final caption = (detail?['caption'] ?? post.caption ?? '').toString();
    final createdAtStr = (detail?['created_at'] ?? post.createdAt.toIso8601String()).toString();

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(createdAtStr);
    } catch (_) {
      createdAt = null;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption.isEmpty ? '(No caption)' : caption,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            createdAt == null
                ? ''
                : '${createdAt.toLocal().year}-${createdAt.toLocal().month.toString().padLeft(2, '0')}-${createdAt.toLocal().day.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}