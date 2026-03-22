import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ousia/services/auth_service.dart';
import 'messages_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final AuthService _service = AuthService();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  bool _hasError = false;
  final TextEditingController _searchController = TextEditingController();

  static const Color _primary = Color(0xFF7B5CF0);

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() { _isLoading = true; _hasError = false; });
    final result = await _service.fetchConversations();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _conversations = List<Map<String, dynamic>>.from(result['conversations']);
        _filtered = _conversations;
        _isLoading = false;
      });
    } else {
      setState(() { _hasError = true; _isLoading = false; });
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _conversations;
      } else {
        _filtered = _conversations.where((c) {
          final name = _getConversationName(c).toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _getConversationName(Map<String, dynamic> convo) {
    if (convo['is_group'] == true) {
      return convo['group_name'] ?? 'Group';
    }
    final currentUsername = AuthService.currentUsername;
    final pfpInfo = convo['pfp_info'] as List? ?? [];
    final other = pfpInfo.firstWhere(
      (p) => p['username'] != currentUsername,
      orElse: () => pfpInfo.isNotEmpty ? pfpInfo.first : {'username': 'Unknown'},
    );
    return other['username'] ?? 'Unknown';
  }

  String? _getConversationPfp(Map<String, dynamic> convo) {
    if (convo['is_group'] == true) return null;
    final currentUsername = AuthService.currentUsername;
    final pfpInfo = convo['pfp_info'] as List? ?? [];
    final other = pfpInfo.firstWhere(
      (p) => p['username'] != currentUsername,
      orElse: () => <String, dynamic>{},
    );
    return other['pfp_url'];
  }

  Future<void> _openOrCreateConversation(int userId, String username) async {
    final result = await _service.createOrGetConversation(userId);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'conversation_id': result['conversation_id'],
          'name': username,
          'pfp_url': result['pfp_url'],
          'is_group': false,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Messages',
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: cs.onSurface),
            onPressed: _showNewConversationSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('Could not load messages',
                          style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadConversations,
                        child: Text('Retry', style: GoogleFonts.inter(color: _primary)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearch,
                          style: GoogleFonts.inter(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search conversations...',
                            hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                            prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Conversation list
                    Expanded(
                      child: RefreshIndicator(
                        color: _primary,
                        onRefresh: _loadConversations,
                        child: _filtered.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.chat_bubble_outline,
                                            size: 72, color: cs.onSurfaceVariant.withOpacity(0.4)),
                                        const SizedBox(height: 16),
                                        Text('No conversations yet',
                                            style: GoogleFonts.inter(
                                                fontSize: 16,
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 8),
                                        Text('Tap the pencil icon to start one',
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: cs.onSurfaceVariant.withOpacity(0.7))),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final convo = _filtered[index];
                                  return _ConversationTile(
                                    conversation: convo,
                                    name: _getConversationName(convo),
                                    pfpUrl: _getConversationPfp(convo),
                                    primaryColor: _primary,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/chat',
                                      arguments: {
                                        'conversation_id': convo['id'],
                                        'name': _getConversationName(convo),
                                        'pfp_url': _getConversationPfp(convo),
                                        'is_group': convo['is_group'],
                                        'group_name': convo['group_name'],
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showNewConversationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewConversationSheet(
        service: _service,
        primaryColor: _primary,
        onConversationCreated: (conversationId, name, pfpUrl, isGroup) {
          Navigator.pop(context);
          _loadConversations();
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: {
              'conversation_id': conversationId,
              'name': name,
              'pfp_url': pfpUrl,
              'is_group': isGroup,
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String name;
  final String? pfpUrl;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.name,
    required this.pfpUrl,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGroup = conversation['is_group'] == true;
    final updatedAt = DateTime.tryParse(conversation['updated_at'] ?? '');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: pfpUrl != null
                      ? CachedNetworkImageProvider(pfpUrl!)
                      : null,
                  child: pfpUrl == null
                      ? Icon(
                          isGroup ? Icons.group : Icons.person,
                          color: cs.primary,
                          size: 28,
                        )
                      : null,
                ),
                if (isGroup)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5),
                      ),
                      child: const Icon(Icons.group, color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (updatedAt != null)
                        Text(
                          timeago.format(updatedAt, locale: 'en_short'),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isGroup
                        ? '${(conversation['participants'] as List).length} members'
                        : 'Tap to open chat',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewConversationSheet extends StatefulWidget {
  final AuthService service;
  final Color primaryColor;
  final Function(String conversationId, String name, String? pfpUrl, bool isGroup)
      onConversationCreated;

  const _NewConversationSheet({
    required this.service,
    required this.primaryColor,
    required this.onConversationCreated,
  });

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _isCreating = false;

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    final result = await widget.service.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _results = result['success'] == true
          ? List<Map<String, dynamic>>.from(result['users'])
          : [];
      _isLoading = false;
    });
  }

  Future<void> _startConversation(Map<String, dynamic> user) async {
    setState(() => _isCreating = true);
    final result = await widget.service.createOrGetConversation(user['id']);
    if (!mounted) return;
    setState(() => _isCreating = false);
    if (result['success'] == true) {
      widget.onConversationCreated(
        result['conversation_id'],
        user['username'],
        user['pfp_url'],
        false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('New Message',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  autofocus: true,
                  style: GoogleFonts.inter(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search people...',
                    hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isCreating
                  ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                  : _isLoading
                      ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? 'Search for someone to message'
                                    : 'No users found',
                                style: GoogleFonts.inter(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final user = _results[index];
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
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface)),
                                  onTap: () => _startConversation(user),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}