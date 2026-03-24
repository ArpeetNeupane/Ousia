import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthService _service = AuthService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isLoadingNext = false;
  String? _nextUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingNext &&
        _nextUrl != null) {
      _loadNextPage();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final result = await _service.fetchNotifications();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _items = List<Map<String, dynamic>>.from(result['items'] ?? []);
        _nextUrl = result['next'] as String?;
      }
    });

    final ok = await _service.markAllNotificationsRead();
    if (!mounted || !ok) return;

    setState(() {
      _items = _items.map((e) => {...e, 'is_read': true}).toList();
    });
  }

  Future<void> _loadNextPage() async {
    if (_nextUrl == null || _isLoadingNext) return;

    setState(() => _isLoadingNext = true);
    final result = await _service.fetchNextNotifications(_nextUrl!);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _items.addAll(List<Map<String, dynamic>>.from(result['items'] ?? []));
        _nextUrl = result['next'] as String?;
        _isLoadingNext = false;
      });

      final ok = await _service.markAllNotificationsRead();
      if (!mounted || !ok) return;

      setState(() {
        _items = _items.map((e) => {...e, 'is_read': true}).toList();
      });
      return;
    }

    setState(() => _isLoadingNext = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No notifications yet.')),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _items.length + (_isLoadingNext ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _items.length && _isLoadingNext) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final item = _items[index];
                      final isRead = item['is_read'] == true;
                      final title = (item['title'] ?? '').toString();
                      final body = (item['body'] ?? '').toString();
                      final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());

                      return Column(
                        children: [
                          ListTile(
                            tileColor: isRead ? null : cs.primaryContainer.withValues(alpha: 0.18),
                            leading: Icon(
                              _iconForType((item['notification_type'] ?? '').toString()),
                              color: cs.primary,
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (body.isNotEmpty) Text(body),
                                const SizedBox(height: 4),
                                Text(
                                  createdAt != null
                                      ? _formatRelative(createdAt)
                                      : '',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            onTap: null,
                          ),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant,
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'friend_request':
        return Icons.person_add_alt_1;
      case 'message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatRelative(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
