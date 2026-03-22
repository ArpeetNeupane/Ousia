import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ousia/services/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String name;
  final String? pfpUrl;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.name,
    required this.isGroup,
    this.pfpUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  WebSocketChannel? _channel;
  List<Map<String, dynamic>> _messages = [];
  bool _isConnected = false;
  bool _isConnecting = true;
  bool _isTyping = false;
  String? _typingUsername;
  Timer? _typingTimer;
  Timer? _typingDebounce;

  static const Color _primary = Color(0xFF7B5CF0);
  static const String _wsBaseUrl = 'ws://192.168.1.2:8000';

  String get _currentUsername => AuthService.currentUsername;
  String get _currentUserId => AuthService.currentUser?.id.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() async {
    final token = AuthService.accessToken;
    final uri = Uri.parse(
      '$_wsBaseUrl/ws/chat/${widget.conversationId}/?token=$token',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );
    } catch (e) {
      setState(() => _isConnecting = false);
    }
  }

  void _onMessage(dynamic data) {
    final json = jsonDecode(data as String) as Map<String, dynamic>;
    final type = json['type'] as String?;

    switch (type) {
      case 'connection_established':
        setState(() { _isConnected = true; _isConnecting = false; });
        break;

      case 'message_history':
        final history = json['messages'] as List;
        setState(() {
          _messages = history.map((m) => Map<String, dynamic>.from(m)).toList();
        });
        _scrollToBottom();
        break;

      case 'new_message':
        final msg = Map<String, dynamic>.from(json['message']);
        setState(() => _messages.add(msg));
        _scrollToBottom();
        break;

      case 'message_edited':
        final edited = Map<String, dynamic>.from(json['message']);
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == edited['id']);
          if (idx != -1) _messages[idx] = edited;
        });
        break;

      case 'message_deleted':
        final deletedId = json['message_id'] as String;
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'].toString() == deletedId);
          if (idx != -1) {
            _messages[idx] = {..._messages[idx], 'is_deleted': true, 'content': 'This message was deleted'};
          }
        });
        break;

      case 'typing_indicator':
        setState(() {
          _isTyping = json['is_typing'] == true;
          _typingUsername = json['username'] as String?;
        });
        if (_isTyping) {
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            setState(() { _isTyping = false; _typingUsername = null; });
          });
        }
        break;
    }
  }

  void _onDisconnected() {
    setState(() { _isConnected = false; _isConnecting = false; });
  }

  void _onError(dynamic error) {
    setState(() { _isConnected = false; _isConnecting = false; });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || !_isConnected) return;

    _channel!.sink.add(jsonEncode({
      'action': 'send_message',
      'content': content,
      'message_type': 'text',
    }));

    _messageController.clear();
    _sendTypingIndicator(false);
  }

  void _sendTypingIndicator(bool isTyping) {
    if (!_isConnected) return;
    _channel!.sink.add(jsonEncode({
      'action': 'typing_indicator',
      'is_typing': isTyping,
    }));
  }

  void _onTextChanged(String text) {
    _typingDebounce?.cancel();
    if (text.isNotEmpty) {
      _sendTypingIndicator(true);
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _sendTypingIndicator(false);
      });
    } else {
      _sendTypingIndicator(false);
    }
  }

  void _deleteMessage(String messageId) {
    if (!_isConnected) return;
    _channel!.sink.add(jsonEncode({
      'action': 'delete_message',
      'message_id': messageId,
    }));
  }

  void _editMessage(String messageId, String currentContent) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Message', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          style: GoogleFonts.inter(color: cs.onSurface),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && _isConnected) {
                _channel!.sink.add(jsonEncode({
                  'action': 'edit_message',
                  'message_id': messageId,
                  'content': newContent,
                }));
              }
              Navigator.pop(context);
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

  bool _isMine(Map<String, dynamic> msg) {
    return msg['sender'].toString() == _currentUserId ||
        (msg['sender_username'] ?? '') == _currentUsername;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              backgroundImage: widget.pfpUrl != null
                  ? CachedNetworkImageProvider(widget.pfpUrl!)
                  : null,
              child: widget.pfpUrl == null
                  ? Icon(
                      widget.isGroup ? Icons.group : Icons.person,
                      color: cs.primary, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: cs.onSurface)),
                  if (_isTyping && _typingUsername != null)
                    Text('$_typingUsername is typing...',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _primary,
                            fontStyle: FontStyle.italic))
                  else
                    Text(
                      _isConnecting ? 'Connecting...' : _isConnected ? 'Online' : 'Offline',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _isConnected ? Colors.green : cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isConnecting
                ? Center(child: CircularProgressIndicator(color: _primary))
                : !_isConnected
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, size: 48, color: cs.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text('Could not connect',
                                style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _connectWebSocket,
                              style: ElevatedButton.styleFrom(backgroundColor: _primary),
                              child: Text('Retry',
                                  style: GoogleFonts.inter(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text('No messages yet. Say hi!',
                                style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final mine = _isMine(msg);
                              final showDate = index == 0 ||
                                  _shouldShowDateDivider(
                                      _messages[index - 1], msg);
                              return Column(
                                children: [
                                  if (showDate) _buildDateDivider(msg['created_at'], cs),
                                  _MessageBubble(
                                    message: msg,
                                    isMine: mine,
                                    primaryColor: _primary,
                                    onLongPress: mine && msg['is_deleted'] != true
                                        ? () => _showMessageOptions(msg)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
          ),

          // Input bar
          _buildInputBar(cs),
        ],
      ),
    );
  }

  bool _shouldShowDateDivider(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    final prevDate = DateTime.tryParse(prev['created_at'] ?? '');
    final currDate = DateTime.tryParse(curr['created_at'] ?? '');
    if (prevDate == null || currDate == null) return false;
    return prevDate.day != currDate.day ||
        prevDate.month != currDate.month ||
        prevDate.year != currDate.year;
  }

  Widget _buildDateDivider(String? dateStr, ColorScheme cs) {
    final date = DateTime.tryParse(dateStr ?? '');
    if (date == null) return const SizedBox.shrink();
    final now = DateTime.now();
    String label;
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      label = 'Today';
    } else if (date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: cs.onSurfaceVariant)),
          ),
          Expanded(child: Divider(color: cs.outlineVariant)),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: cs.onSurface),
              title: Text('Edit', style: GoogleFonts.inter(color: cs.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _editMessage(msg['id'].toString(), msg['content']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete',
                  style: GoogleFonts.inter(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(msg['id'].toString());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  onChanged: _onTextChanged,
                  maxLines: 4,
                  minLines: 1,
                  style: GoogleFonts.inter(color: cs.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final Color primaryColor;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.primaryColor,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDeleted = message['is_deleted'] == true;
    final isEdited = message['is_edited'] == true;
    final createdAt = DateTime.tryParse(message['created_at'] ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text(
                (message['sender_username'] ?? '?')[0].toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.primary),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? cs.surfaceContainerHighest
                      : isMine
                          ? primaryColor
                          : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          message['sender_username'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor),
                        ),
                      ),
                    Text(
                      message['content'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDeleted
                            ? cs.onSurfaceVariant
                            : isMine
                                ? Colors.white
                                : cs.onSurface,
                        fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (createdAt != null)
                          Text(
                            _formatTime(createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isMine
                                  ? Colors.white.withOpacity(0.7)
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        if (isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· edited',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isMine
                                  ? Colors.white.withOpacity(0.7)
                                  : cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}