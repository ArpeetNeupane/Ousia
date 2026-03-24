import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ousia/services/auth_service.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';
import '../models/post.dart';


class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final AuthService _service = AuthService();
  final ScrollController _scrollController = ScrollController();

  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _nextUrl;
  String? _errorMessage;

  //search bar variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;
  final FocusNode _searchFocusNode = FocusNode();

  static const Color _primary = Color(0xFF7B5CF0);

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  void _prewarmImageCache(List<Post> posts) {
    for (final post in posts) {
      for (final media in post.mediaFiles) {
        if (!media.isVideo) {
          CachedNetworkImageProvider(media.mediaUrl).resolve(const ImageConfiguration());
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _nextUrl != null) {
      _loadMore();
    }
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearchLoading = true);
    final result = await _service.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _searchResults = result['success'] == true
          ? List<Map<String, dynamic>>.from(result['users'])
          : [];
      _isSearchLoading = false;
    });
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _service.fetchPosts();
    if (!mounted) return;
    if (result['success'] == true) {
      final newPosts = result['posts'] as List<Post>;
      setState(() {
        _posts = newPosts;
        _nextUrl = result['next'];
        _isLoading = false;
      });
      _prewarmImageCache(newPosts);
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final result = await _service.fetchPosts(nextUrl: _nextUrl);
    if (!mounted) return;
    if (result['success'] == true) {
      final newPosts = result['posts'] as List<Post>;
      setState(() {
        _posts.addAll(newPosts);
        _nextUrl = result['next'];
        _isLoadingMore = false;
      });
      _prewarmImageCache(newPosts);
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleLike(Post post) async {
    setState(() {
      post.isLiked = !post.isLiked;
      post.postLikeCount += post.isLiked ? 1 : -1;
    });

    if (post.isLiked) {
      final result = await _service.likePost(post.id);
      if (result['success'] == true) {
        setState(() => post.likeId = result['like_id']);
        await _service.updateCachedPost(post); // ← after likeId is set
      } else {
        setState(() {
          post.isLiked = false;
          post.postLikeCount--;
        });
        if (mounted) _showSnack(result['message'] ?? 'Failed to like post');
      }
    } else {
      if (post.likeId == null) return;
      final result = await _service.unlikePost(post.likeId!);
      if (result['success'] != true) {
        setState(() {
          post.isLiked = true;
          post.postLikeCount++;
        });
        if (mounted) _showSnack(result['message'] ?? 'Failed to unlike post');
      } else {
        setState(() => post.likeId = null);
        await _service.updateCachedPost(post); // ← after likeId is cleared
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSearching ? null : AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Your Feed',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(Icons.search_outlined, color: Theme.of(context).colorScheme.onSurface,),
            onPressed: _startSearch,
          ),
          IconButton(
            icon: Icon(Icons.person_2_outlined, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pushNamed(context, '/friend-requests'),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          AnimatedSlide(
            offset: _isSearching ? Offset.zero : const Offset(1, 0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: _isSearching ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildSearchOverlay(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Search bar row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: cs.onSurface),
                    onPressed: _stopSearch,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearch,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Results
            Expanded(
              child: _isSearchLoading
                  ? Center(child: CircularProgressIndicator(color: _primary))
                  : _searchController.text.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search, size: 64,
                                  color: cs.onSurfaceVariant.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              Text('Search for users',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant, fontSize: 16)),
                            ],
                          ),
                        )
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text('No users found',
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: cs.primaryContainer,
                                    backgroundImage: user['pfp_url'] != null
                                        ? CachedNetworkImageProvider(user['pfp_url'])
                                        : null,
                                    child: user['pfp_url'] == null
                                        ? Icon(Icons.person, color: cs.primary)
                                        : null,
                                  ),
                                  title: Text(user['username'],
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface)),
                                  onTap: () {
                                    _stopSearch();
                                    Navigator.pushNamed(
                                      context,
                                      '/others-profile',
                                      arguments: user['id'],
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7B5CF0)));
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPosts,
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Text(
          'No posts have been made by any other user yet!\nWhy don\'t you be the first one?\nAdd friends to see their posts too.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadPosts,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF7B5CF0))),
            );
          }
          return _PostCard(
            post: _posts[index],
            onLikeTap: () => _toggleLike(_posts[index]),
            primaryColor: _primary,
            currentUserId: AuthService.currentUser?.id,
            onDeleteTap: () async {
              final result = await _service.deletePost(_posts[index].id);
              if (result['success'] == true) {
                setState(() => _posts.removeWhere((p) => p.id == _posts[index].id));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'])),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// Post card
class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLikeTap;
  final VoidCallback? onDeleteTap;
  final Color primaryColor;
  final int? currentUserId;

  const _PostCard({
    required this.post,
    required this.onLikeTap,
    required this.primaryColor,
    this.onDeleteTap,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUserId != null && post.postedBy == currentUserId;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: (post.postedByProfile?.pfpUrl != null &&
                          post.postedByProfile!.pfpUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(post.postedByProfile!.pfpUrl!)
                      : null,
                  child: (post.postedByProfile?.pfpUrl == null ||
                          post.postedByProfile!.pfpUrl!.isEmpty)
                      ? Icon(Icons.person, color: colorScheme.onSurfaceVariant, size: 22)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.postedByUsername,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: onSurface,
                    ),
                  ),
                ),

                // View Profile button — hidden on own posts
                if (!isOwner)
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/others-profile',
                      arguments: post.postedBy,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'View Profile',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),

                // Delete button — only on own posts
                if (isOwner)
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Post', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text(
                              'Are you sure you want to delete this post?',
                            ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color.fromARGB(255, 161, 159, 159),
                              ),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) onDeleteTap?.call();
                    },
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 129, 26, 19),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),

          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _ExpandableCaption(caption: post.caption!),
            ),
          
          SizedBox(height: 4),

          // Media
          if (post.mediaFiles.isNotEmpty)
            _MediaCarousel(mediaFiles: post.mediaFiles),

          // Like row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onLikeTap,
                  child: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.postLikeCount} ${post.postLikeCount == 1 ? 'Like' : 'Likes'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Hashtag
          if (post.typeOfPost.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
              child: Text(
                post.typeOfPost,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              timeago.format(post.createdAt),
              style: TextStyle(
                color: onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.1,
            color: Theme.of(context).dividerColor,
          ),
        ],
      ),
    );
  }
}

// Expandable Caption
class _ExpandableCaption extends StatefulWidget {
  final String caption;

  const _ExpandableCaption({required this.caption});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;
  static const int _limit = 100;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isLong = widget.caption.length > _limit;
    final displayText = (!_expanded && isLong)
        ? widget.caption.substring(0, _limit)
        : widget.caption;

    return RichText(
      text: TextSpan(
        style: TextStyle(color: onSurface, fontSize: 13.5),
        children: [
          TextSpan(text: displayText),
          if (isLong && !_expanded)
            WidgetSpan(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: const Text('... more',
                    style: TextStyle(color: Colors.grey, fontSize: 13.5)),
              ),
            ),
          if (isLong && _expanded)
            WidgetSpan(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: const Text(' less',
                    style: TextStyle(color: Colors.grey, fontSize: 13.5)),
              ),
            ),
        ],
      ),
    );
  }
}

// Media Carousel
class _MediaCarousel extends StatefulWidget {
  final List<MediaFile> mediaFiles;

  const _MediaCarousel({required this.mediaFiles});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.mediaFiles.length;

    return Stack(
      children: [
        // Pages
        Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
              horizontal: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 500,
            ),
            child: PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) {
                final media = widget.mediaFiles[i];
                return media.isVideo
                    ? _VideoItem(media: media)
                    : _ImageItem(media: media);
              },
            ),
          ),
        ),

        // Left arrow
        if (total > 1 && _currentIndex > 0)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                ),
                child: _ArrowButton(icon: Icons.chevron_left),
              ),
            ),
          ),

        // Right arrow
        if (total > 1 && _currentIndex < total - 1)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                ),
                child: _ArrowButton(icon: Icons.chevron_right),
              ),
            ),
          ),

        // Counter badge
        if (total > 1)
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/$total',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  const _ArrowButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

// Image Item
class _ImageItem extends StatelessWidget {
  final MediaFile media;
  const _ImageItem({required this.media});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: media.mediaUrl,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 50),
      placeholder: (_, __) => const _ShimmerBox(),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFEEEEEE),
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}

// Shimmer before image loads
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        color: Color.lerp(const Color.fromARGB(255, 77, 161, 194), const Color(0xFFF5F5F5), _anim.value),
      ),
    );
  }
}

// Video Item
class _VideoItem extends StatefulWidget {
  final MediaFile media;
  const _VideoItem({required this.media});

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.media.mediaUrl))
      ..setVolume(0) // starts muted like Instagram
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-${widget.media.publicId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.5) {
          _controller.pause();
        } else {
          _controller.play();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail while loading
          if (!_initialized)
            CachedNetworkImage(
              imageUrl: widget.media.videoThumbnailUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
      
          // Video player
          if (_initialized)
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
      
          // Mute/unmute button
          Positioned(
            bottom: 10,
            right: 12,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}