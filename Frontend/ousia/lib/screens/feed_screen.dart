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

  static const Color _primary = Color(0xFF7B5CF0);

  @override
  void initState() {
    super.initState();
    _loadPosts();
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
        !_isLoadingMore &&
        _nextUrl != null) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _service.fetchPosts();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _posts = result['posts'];
        _nextUrl = result['next'];
        _isLoading = false;
      });
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
      setState(() {
        _posts.addAll(result['posts']);
        _nextUrl = result['next'];
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleLike(Post post) async {
    // Optimistic update
    setState(() {
      post.isLiked = !post.isLiked;
      post.postLikeCount += post.isLiked ? 1 : -1;
    });

    if (post.isLiked) {
      final result = await _service.likePost(post.id);
      if (result['success'] == true) {
        setState(() => post.likeId = result['like_id']);
      } else {
        // Revert on failure
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
        // Revert on failure
        setState(() {
          post.isLiked = true;
          post.postLikeCount++;
        });
        if (mounted) _showSnack(result['message'] ?? 'Failed to unlike post');
      } else {
        setState(() => post.likeId = null);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Your Feed',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
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
          'No posts have been made by any other user yet!\nWhy don\'t you be the first one?.',
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
  final Color primaryColor;

  const _PostCard({
    required this.post,
    required this.onLikeTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      // Gap between posts
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
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: (post.postedByProfile?.pfpUrl != null &&
                          post.postedByProfile!.pfpUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(post.postedByProfile!.pfpUrl!)
                      : null,
                  child: (post.postedByProfile?.pfpUrl == null ||
                          post.postedByProfile!.pfpUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 22)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.postedByUsername,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
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
              ],
            ),
          ),

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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),

          // Caption
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ExpandableCaption(
                username: post.postedByUsername,
                caption: post.caption!,
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
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}

// Expandable Caption
class _ExpandableCaption extends StatefulWidget {
  final String username;
  final String caption;

  const _ExpandableCaption({required this.username, required this.caption});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;
  static const int _limit = 100;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.caption.length > _limit;
    final displayText =
        (!_expanded && isLong) ? widget.caption.substring(0, _limit) : widget.caption;

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 13.5),
        children: [
          TextSpan(
            text: '${widget.username} ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: displayText),
          if (isLong && !_expanded)
            WidgetSpan(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: const Text(
                  '... more',
                  style: TextStyle(color: Colors.grey, fontSize: 13.5),
                ),
              ),
            ),
          if (isLong && _expanded)
            WidgetSpan(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: const Text(
                  ' less',
                  style: TextStyle(color: Colors.grey, fontSize: 13.5),
                ),
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
        AspectRatio(
          aspectRatio: 1,
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
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFEEEEEE),
        child: const Icon(Icons.broken_image, color: Colors.grey),
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
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
      
          // Video player
          if (_initialized)
            FittedBox(
              fit: BoxFit.cover,
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