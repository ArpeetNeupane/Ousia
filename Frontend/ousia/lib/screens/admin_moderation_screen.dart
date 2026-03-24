import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final Set<int> _processingPostIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await AuthService().fetchModerationQueue();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _items = List<Map<String, dynamic>>.from(result['items'] ?? []);
        _error = null;
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    setState(() {
      _error = result['message']?.toString() ?? 'Failed to load moderation queue.';
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _takeAction({required int postId, required String action}) async {
    setState(() => _processingPostIds.add(postId));

    final result = await AuthService().moderationAction(postId: postId, action: action);
    if (!mounted) return;

    setState(() => _processingPostIds.remove(postId));

    if (result['success'] == true) {
      setState(() {
        _items.removeWhere((item) => (item['id'] as int?) == postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post ${action}d successfully.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'Failed to update post.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Queue'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : () => _loadQueue(refresh: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadQueue(refresh: true),
        child: _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _error!,
                    style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadQueue(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              )
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.verified_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No posts are waiting for review.',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final postId = item['id'] as int;
                      final score = (item['ai_score'] as num?)?.toDouble();
                      final reason = item['reason']?.toString() ?? '';
                      final caption = item['caption']?.toString() ?? '';
                      final mediaUrl = item['media_url']?.toString();
                      final isBusy = _processingPostIds.contains(postId);

                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Post #$postId', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                Text(
                                  score == null ? 'Score: -' : 'Score: ${score.toStringAsFixed(3)}',
                                  style: GoogleFonts.inter(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  mediaUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 90,
                                    alignment: Alignment.center,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Text('Unable to load media preview'),
                                  ),
                                ),
                              ),
                            ],
                            if (caption.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(caption, style: GoogleFonts.inter(fontSize: 14)),
                            ],
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Reason: $reason',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade700),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _takeAction(postId: postId, action: 'approve'),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _takeAction(postId: postId, action: 'block'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    icon: isBusy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.block),
                                    label: const Text('Block'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
