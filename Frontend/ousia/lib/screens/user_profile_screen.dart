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
  int _friendCount = 0;
  bool _friendRequestSent = false;
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _isBlockedByMe = false;
  bool _isBlockedMe = false;
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
      _service.fetchFriends(userId: widget.userId),
    ]);
    if (!mounted) return;

    final postsResult = results[0];
    final friendResult = results[1];
    final friendshipResult = results[2];
    final friendsListResult = results[3];

    setState(() {
      _profile = profile;
      if (postsResult['success'] == true) {
        _posts = postsResult['posts'] as List<Post>;
        _nextUrl = postsResult['next'];
      }
      _friendRequestSent = friendResult['sent'] == true;
      _isFriend = friendshipResult['is_friend'] == true;
      _isBlocked = friendshipResult['is_blocked'] == true;
      _isBlockedByMe = friendshipResult['is_blocked_by_me'] == true;
      _isBlockedMe = friendshipResult['is_blocked_me'] == true;
      _friendRequestSent = friendResult['sent'] == true;
      _sentRequestId = friendResult['sent_request_id'];
      _hasReceivedRequest = friendResult['received'] == true;
      _receivedRequestId = friendResult['received_request_id'];
      _friendCount = friendsListResult['total_friends'] ?? 0;
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

  Future<void> _showFriendsListSheet() async {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Friends',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _service.fetchAllFriends(userId: widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final friends =
                        (snapshot.data?['friends'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        <Map<String, dynamic>>[];

                    if (friends.isEmpty) {
                      return Center(
                        child: Text(
                          'No friends yet',
                          style: GoogleFonts.inter(
                            color: cs.onSurface.withOpacity(0.65),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: friends.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = friends[index];
                        final friend = item['friend'] as Map<String, dynamic>?;
                        final profile = item['friend_profile'] as Map<String, dynamic>?;
                        final friendId = friend?['id'] as int?;
                        final username = (friend?['username'] ?? '').toString();
                        final pfpUrl = profile?['pfp_url'] as String?;

                        void openProfile() {
                          if (friendId == null) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          Navigator.pushNamed(
                            context,
                            '/others-profile',
                            arguments: friendId,
                          );
                        }

                        return ListTile(
                          onTap: openProfile,
                          leading: GestureDetector(
                            onTap: openProfile,
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: cs.surfaceContainerHighest,
                              backgroundImage:
                                  pfpUrl != null && pfpUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(pfpUrl)
                                      : null,
                              child: (pfpUrl == null || pfpUrl.isEmpty)
                                  ? Icon(Icons.person, color: cs.onSurfaceVariant)
                                  : null,
                            ),
                          ),
                          title: GestureDetector(
                            onTap: openProfile,
                            child: Text(
                              username,
                              style: GoogleFonts.inter(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  final GlobalKey _friendsButtonKey = GlobalKey();

  Future<void> _showFriendActionsMenu() async {
    final buttonContext = _friendsButtonKey.currentContext;
    if (buttonContext == null) return;

    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final buttonOffset = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final buttonSize = buttonBox.size;
    final theme = Theme.of(context);

    final selected = await showMenu<String>(
      context: context,
      color: theme.colorScheme.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: BoxConstraints(
        minWidth: buttonSize.width,
        maxWidth: buttonSize.width,
      ),
      position: RelativeRect.fromLTRB(
        buttonOffset.dx,
        buttonOffset.dy + buttonSize.height + 4,
        overlayBox.size.width - (buttonOffset.dx + buttonSize.width),
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'unfriend',
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.person_remove, size: 18),
                const SizedBox(width: 12),
                Text(
                  'Unfriend',
                  style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'block',
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  'Block',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;
    if (selected == 'unfriend') {
      await _unfriendUser();
    } else if (selected == 'block') {
      await _blockUser();
    }
  }

  Future<void> _unfriendUser() async {
    if (_profile == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unfriend User',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to unfriend ${_profile?.username}?',
          style: GoogleFonts.inter(fontSize: 16, color: const Color.fromARGB(255, 154, 152, 152)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              backgroundColor: const Color.fromARGB(255, 236, 115, 133),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Unfriend',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final result = await _service.unfriendUser(_profile!.id);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _isFriend = false;
        _isBlocked = false;
        _isBlockedByMe = false;
        _isBlockedMe = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully unfriended user')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to unfriend user')),
      );
    }
  }

  Future<void> _blockUser() async {
    if (_profile == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Block User',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to block ${_profile?.username}? They won\'t be able to send you friend requests.',
          style: GoogleFonts.inter(fontSize: 16, color: const Color.fromARGB(255, 154, 152, 152)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Block',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final result = await _service.blockUser(_profile!.id);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _isBlocked = true;
        _isBlockedByMe = true;
        _isBlockedMe = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully blocked user')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to block user')),
      );
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatColumn('Posts', '${_posts.length}'),
              const SizedBox(width: 40),
              _buildStatColumn(
                'Friends',
                '$_friendCount',
                onTap: _showFriendsListSheet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _isBlockedByMe
                    ? ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          'Blocked',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      )
                    : _isBlockedMe
                    ? ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade500,
                          disabledBackgroundColor: Colors.grey.shade500,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          'Add Friend',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      )
                    : _hasReceivedRequest
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
                    : _isFriend
                    ? ElevatedButton(
                        key: _friendsButtonKey,
                        onPressed: _showFriendActionsMenu,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Friends',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                          ],
                        ),
                      )
                    : Opacity(
                        opacity: _friendRequestSent ? 0.8 : 1.0,
                        child: ElevatedButton(
                          onPressed: _friendRequestSent ? _cancelFriendRequest : _sendFriendRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor: _primary.withOpacity(0.6),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            _friendRequestSent ? 'Cancel Request' : 'Add Friend',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, color: Colors.white),
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

  Widget _buildStatColumn(String label, String count, {VoidCallback? onTap}) {
    final content = Column(
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

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: content,
      ),
    );
  }
}