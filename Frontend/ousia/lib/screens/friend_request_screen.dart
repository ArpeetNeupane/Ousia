import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ousia/services/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final AuthService _service = AuthService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _hasError = false;

  static const Color _primary = Color(0xFF7B5CF0);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _isLoading = true; _hasError = false; });
    final result = await _service.fetchFriendRequests();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        // only show requests sent TO current user that are pending
        _requests = (result['requests'] as List<Map<String, dynamic>>)
            .where((r) => r['status'] == 'pending' && r['is_received'] == true)
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() { _hasError = true; _isLoading = false; });
    }
  }

  Future<void> _respond(int id, String status, int index) async {
    final result = status == 'deleted'
        ? await _service.deleteFriendRequest(id)
        : await _service.respondFriendRequest(id, status);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _requests.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'accepted'
            ? 'Friend request accepted!'
            : status == 'rejected'
                ? 'Friend request declined.'
                : 'Request deleted.'),
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Something went wrong')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Friend Requests',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Could not load requests',
                          style: GoogleFonts.inter(color: Colors.grey)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadRequests,
                        child: Text('Retry', style: GoogleFonts.inter(color: _primary)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadRequests,
                  child: _requests.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No pending friend requests',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
                            return _FriendRequestCard(
                              request: req,
                              primaryColor: _primary,
                              onAccept: () => _respond(req['id'], 'accepted', index),
                              onDecline: () => _respond(req['id'], 'rejected', index),
                              onDelete: () => _respond(req['id'], 'deleted', index),
                              onProfileTap: () => Navigator.pushNamed(
                                context,
                                '/others-profile',
                                arguments: req['from_user_id'],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _FriendRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final Color primaryColor;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onProfileTap;
  final VoidCallback onDelete;

  const _FriendRequestCard({
    required this.request,
    required this.primaryColor,
    required this.onAccept,
    required this.onDecline,
    required this.onProfileTap,
    required this.onDelete,
  });

  @override
  State<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<_FriendRequestCard> {
  bool _isResponding = false;
  bool _isDeleting = false;

  void _showRespondDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Respond to Request',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'What would you like to do with this friend request?',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isResponding = true);
              await Future.microtask(widget.onDecline);
              if (mounted) setState(() => _isResponding = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Decline',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isResponding = true);
              await Future.microtask(widget.onAccept);
              if (mounted) setState(() => _isResponding = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.request['posted_by_profile'] as Map<String, dynamic>?;
    final pfpUrl = profile?['pfp_url'] as String?;
    final username = profile?['username'] as String? ?? widget.request['from_user'];
    final createdAt = DateTime.tryParse(widget.request['created_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          GestureDetector(
            onTap: widget.onProfileTap,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (pfpUrl != null && pfpUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(pfpUrl)
                  : null,
              child: (pfpUrl == null || pfpUrl.isEmpty)
                  ? Icon(Icons.person, size: 30, color: Colors.grey.shade600)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Info + buttons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onProfileTap,
                  child: Text(
                    username,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeago.format(createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Respond button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isResponding || _isDeleting
                            ? null
                            : () => _showRespondDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isResponding
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Respond',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isResponding || _isDeleting
                            ? null
                            : () async {
                                setState(() => _isDeleting = true);
                                await Future.microtask(widget.onDelete);
                                if (mounted) setState(() => _isDeleting = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 236, 115, 133),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isDeleting
                            ? SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red.shade400))
                            : Text('Delete',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color.fromARGB(255, 234, 230, 230))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}