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
    AuthService.startNotificationsStream();
    AuthService.messageNotificationTick.addListener(_onIncomingMessageNotification);
    AuthService.conversationReadTick.addListener(_onConversationReadTick);
    _loadConversations();
  }

  @override
  void dispose() {
    AuthService.messageNotificationTick.removeListener(_onIncomingMessageNotification);
    AuthService.conversationReadTick.removeListener(_onConversationReadTick);
    _searchController.dispose();
    super.dispose();
  }

  void _onIncomingMessageNotification() {
    if (!mounted) return;
    _loadConversations();
  }

  void _onConversationReadTick() {
    if (!mounted) return;
    _loadConversations();
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
          'other_user_id': userId,
        },
      );
      // Refresh conversations when returning
      _loadConversations();
    }
  }

  void _showConversationOptions(Map<String, dynamic> convo) {
    final isGroup = convo['is_group'] == true;
    final currentUserId = AuthService.currentUser?.id;
    final isAdmin = convo['group_admin'] == currentUserId;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // View Members (group only)
            if (isGroup)
              ListTile(
                leading: Icon(Icons.people_outline, color: cs.onSurface),
                title: Text('View Members', style: GoogleFonts.inter(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupMembers(convo);
                },
              ),

            // Add Participant (group admin only)
            if (isGroup && isAdmin)
              ListTile(
                leading: Icon(Icons.person_add_outlined, color: cs.onSurface),
                title: Text('Add Participant', style: GoogleFonts.inter(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddParticipant(convo);
                },
              ),

            // Edit Group Name (group admin only)
            if (isGroup && isAdmin)
              ListTile(
                leading: Icon(Icons.edit_outlined, color: cs.onSurface),
                title: Text('Edit Group Name', style: GoogleFonts.inter(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditGroupName(convo);
                },
              ),

            // Remove Participant (group admin only)
            if (isGroup && isAdmin)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: cs.onSurface),
                title: Text('Remove Participant', style: GoogleFonts.inter(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveParticipant(convo);
                },
              ),

            // Leave Group (group only, not admin or admin can still leave)
            if (isGroup)
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                title: Text('Leave Group', style: GoogleFonts.inter(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeaveGroup(convo);
                },
              ),

            // Delete Chat
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete Chat', style: GoogleFonts.inter(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteChat(convo);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupMembers(Map<String, dynamic> convo) {
    final cs = Theme.of(context).colorScheme;
    final participants = convo['participants'] as List? ?? [];
    final pfpInfo = convo['pfp_info'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            ...participants.map((p) {
              final pfp = pfpInfo.firstWhere(
                (pi) => pi['username'] == p['username'],
                orElse: () => <String, dynamic>{},
              );
              final isAdmin = convo['group_admin'] == p['id'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: pfp['pfp_url'] != null
                      ? CachedNetworkImageProvider(pfp['pfp_url'])
                      : null,
                  child: pfp['pfp_url'] == null
                      ? Icon(Icons.person, color: cs.primary)
                      : null,
                ),
                title: Text(p['username'], style: GoogleFonts.inter(color: cs.onSurface)),
                trailing: isAdmin
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Admin', style: GoogleFonts.inter(color: _primary, fontSize: 11)),
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChat(Map<String, dynamic> convo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Chat', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('This will delete the chat for you only.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await _service.deleteConversationForUser(convo['id']);
      if (!mounted) return;
      if (result['success'] == true) {
        _loadConversations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to delete chat')),
        );
      }
    }
  }

  Future<void> _confirmLeaveGroup(Map<String, dynamic> convo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave Group', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to leave this group?',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Leave', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await _service.leaveGroup(convo['id']);
      if (!mounted) return;
      if (result['success'] == true) {
        _loadConversations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to leave group')),
        );
      }
    }
  }

  void _showAddParticipant(Map<String, dynamic> convo) {
    final cs = Theme.of(context).colorScheme;
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AnimatedPadding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Add Participant', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: GoogleFonts.inter(color: cs.onSurface),
                      onChanged: (q) async {
                        if (q.trim().isEmpty) { setSheet(() => results = []); return; }
                        setSheet(() => isLoading = true);
                        final r = await _service.searchUsers(q);
                        setSheet(() { results = r['success'] == true ? List<Map<String, dynamic>>.from(r['users']) : []; isLoading = false; });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                        prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator(color: _primary))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                backgroundImage: results[i]['pfp_url'] != null ? CachedNetworkImageProvider(results[i]['pfp_url']) : null,
                                child: results[i]['pfp_url'] == null ? Icon(Icons.person, color: cs.primary) : null,
                              ),
                              title: Text(results[i]['username'], style: GoogleFonts.inter(color: cs.onSurface)),
                              onTap: () async {
                                final nav = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
                                final r = await _service.addParticipant(convo['id'], results[i]['id']);
                                if (!mounted) return;
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(content: Text(r['success'] == true ? 'Participant added!' : r['message'] ?? 'Failed')),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGroupName(Map<String, dynamic> convo) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: convo['group_name'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Group Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: cs.onSurface),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelText: 'Group Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              final result = await _service.updateConversation(convo['id'], name);
              if (!mounted) return;
              if (result['success'] == true) {
                _loadConversations();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Failed to update')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showRemoveParticipant(Map<String, dynamic> convo) {
    final cs = Theme.of(context).colorScheme;
    final participants = (convo['participants'] as List? ?? [])
        .where((p) => p['id'] != AuthService.currentUser?.id)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove Participant', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            ...participants.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.person, color: cs.primary),
              ),
              title: Text(p['username'], style: GoogleFonts.inter(color: cs.onSurface)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await _service.removeParticipant(convo['id'], p['id']);
                  if (!mounted) return;
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Participant removed!')),
                    );
                    _loadConversations();
                    return;
                  }

                  if (result['requires_confirmation'] == true) {
                    final deleteConfirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Confirm Conversation Deletion', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        content: Text(
                          result['message']?.toString() ?? 'Removing this participant will delete the conversation. Continue?',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ],
                      ),
                    );

                    if (deleteConfirm == true) {
                      final confirmedResult = await _service.removeParticipant(
                        convo['id'],
                        p['id'],
                        confirmation: true,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(confirmedResult['success'] == true ? 'Participant removed!' : confirmedResult['message'] ?? 'Failed')),
                      );
                      if (confirmedResult['success'] == true) _loadConversations();
                    }
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Failed')),
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
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
                    SizedBox(height: 17),
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
                                    onTap: () async {
                                      final currentUserId = AuthService.currentUser?.id;
                                      int? otherUserId;
                                      if (convo['is_group'] != true) {
                                        final participants = convo['participants'] as List? ?? [];
                                        final other = participants.firstWhere(
                                          (p) => p['id'] != currentUserId,
                                          orElse: () => <String, dynamic>{},
                                        );
                                        otherUserId = other['id'] as int?;
                                      }

                                      final convoId = convo['id'].toString();
                                      setState(() {
                                        _conversations = _conversations.map((c) {
                                          if (c['id'].toString() == convoId) {
                                            final updated = Map<String, dynamic>.from(c);
                                            updated['unread_count'] = 0;
                                            return updated;
                                          }
                                          return c;
                                        }).toList();
                                        _filtered = _filtered.map((c) {
                                          if (c['id'].toString() == convoId) {
                                            final updated = Map<String, dynamic>.from(c);
                                            updated['unread_count'] = 0;
                                            return updated;
                                          }
                                          return c;
                                        }).toList();
                                      });

                                      await Navigator.pushNamed(
                                        context,
                                        '/chat',
                                        arguments: {
                                          'conversation_id': convo['id'],
                                          'name': _getConversationName(convo),
                                          'pfp_url': _getConversationPfp(convo),
                                          'is_group': convo['is_group'],
                                          'group_name': convo['group_name'],
                                          'other_user_id': otherUserId,
                                        },
                                      );
                                    _loadConversations();
                                    },
                                    onLongPress: () => _showConversationOptions(convo),
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
        onConversationCreated: (conversationId, name, pfpUrl, isGroup, otherUserId) {
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
              'other_user_id': otherUserId,
            },
          );
          _loadConversations();
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
  final VoidCallback? onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.name,
    required this.pfpUrl,
    required this.primaryColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;
    final Color unreadHighlight = isLightMode ? const Color(0xFF121212) : Colors.white;
    final Color unreadHighlightSoft = unreadHighlight.withOpacity(isLightMode ? 0.85 : 0.92);
    final isGroup = conversation['is_group'] == true;
    final updatedAt = DateTime.tryParse(conversation['updated_at'] ?? '');

    final int unreadCount = conversation['unread_count'] ?? 0;
    final bool hasUnread = unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasUnread ? unreadHighlight : Colors.transparent,
            width: 2,
          ),
          boxShadow: hasUnread ? [
            BoxShadow(
              color: unreadHighlight.withOpacity(0.12),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: pfpUrl != null ? CachedNetworkImageProvider(pfpUrl!) : null,
                      child: pfpUrl == null ? Icon(isGroup ? Icons.group : Icons.person, color: cs.primary, size: 28) : null,
                    ),
                    if (hasUnread) // Show a small notification dot on the avatar
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: unreadHighlight,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
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
                                // Make text bold if unread
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w600,
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
                                fontSize: 11, 
                                color: hasUnread ? unreadHighlight : cs.onSurfaceVariant,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // Show the unread count in the preview text
                        hasUnread ? "New messages ($unreadCount)" : (isGroup ? '${(conversation['participants'] as List).length} members' : 'Tap to open chat'),
                        style: GoogleFonts.inter(
                          fontSize: 13, 
                          color: hasUnread ? unreadHighlightSoft : cs.onSurfaceVariant,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewConversationSheet extends StatefulWidget {
  final AuthService service;
  final Color primaryColor;
  final Function(String conversationId, String name, String? pfpUrl, bool isGroup, int? otherUserId)
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
  final TextEditingController _groupNameController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  final List<Map<String, dynamic>> _selectedUsers = [];
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isGroupMode = false;

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

  void _toggleUserSelection(Map<String, dynamic> user) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u['id'] == user['id']);
      if (index != -1) {
        _selectedUsers.removeAt(index);
      } else {
        _selectedUsers.add(user);
      }
      if (_selectedUsers.isEmpty) _isGroupMode = false;
    });
  }

  Future<void> _handleCreate() async {
    setState(() => _isCreating = true);

    bool shouldBeGroup = _selectedUsers.length > 1 || _groupNameController.text.trim().isNotEmpty;
    
    if (shouldBeGroup) {
      final result = await widget.service.createGroup(
        participantIds: _selectedUsers.map((u) => u['id'] as int).toList(),
        groupName: _groupNameController.text.trim().isEmpty 
          ? "New Group"
          : _groupNameController.text.trim(),
      );
      if (result['success']) {
        widget.onConversationCreated(result['conversation_id'], result['name'], null, true, null);
      }
    } else {
      // Create 1-on-1
      final user = _selectedUsers.first;
      final result = await widget.service.createOrGetConversation(user['id']);
      if (result['success']) {
        widget.onConversationCreated(result['conversation_id'], user['username'], user['pfp_url'], false, user['id'] as int?);
      }
    }
    if (mounted) setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.585,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_isGroupMode ? 'New Group' : 'New Message',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  if (_selectedUsers.isNotEmpty)
                    TextButton(
                      onPressed: _isCreating ? null : _handleCreate,
                      child: Text('Create', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
            ),
            // Group Name Input (Only in group mode)
            if (_selectedUsers.length > 1 || _isGroupMode)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _selectedUsers.length > 1
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: TextField(
                          controller: _groupNameController,
                          style: GoogleFonts.inter(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Enter group name...',
                            hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                            prefixIcon: Icon(Icons.group_add_outlined, color: widget.primaryColor),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            // Search Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search people...',
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            // Selected Users Horizontal List
            if (_selectedUsers.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedUsers.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(_selectedUsers[i]['username']),
                      onDeleted: () => _toggleUserSelection(_selectedUsers[i]),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                : ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['pfp_url'] != null ? CachedNetworkImageProvider(user['pfp_url']) : null,
                          child: user['pfp_url'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(user['username'], style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: widget.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) => _toggleUserSelection(user),
                        ),
                        onTap: () => _toggleUserSelection(user),
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