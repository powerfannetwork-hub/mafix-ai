import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryScreen extends StatefulWidget {
  final List<ChatHistoryItem> conversations;
  final ValueChanged<ChatHistoryItem>? onOpenConversation;
  final ValueChanged<ChatHistoryItem>? onDeleteConversation;

  const ChatHistoryScreen({
    super.key,
    this.conversations = const [],
    this.onOpenConversation,
    this.onDeleteConversation,
  });

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  static const String _historyKey = 'mafix_ai_chat_history_v1';

  List<ChatHistoryItem> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);

      if (raw == null || raw.isEmpty) {
        if (!mounted) return;

        setState(() {
          _conversations = List<ChatHistoryItem>.from(
            widget.conversations,
          );
          _isLoading = false;
        });
        return;
      }

      final decoded = jsonDecode(raw);
      final loaded = <ChatHistoryItem>[];

      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map) continue;

          final messages = entry['messages'];
          String preview = '';

          if (messages is List && messages.isNotEmpty) {
            final lastMessage = messages.last;

            if (lastMessage is Map) {
              preview = lastMessage['text']?.toString() ?? '';
            }
          }

          final title = entry['title']?.toString().trim();

          loaded.add(
            ChatHistoryItem(
              id: entry['id']?.toString() ?? '',
              title: title == null || title.isEmpty
                  ? 'New chat'
                  : title,
              preview: preview,
              updatedAt: DateTime.tryParse(
                entry['updatedAt']?.toString() ?? '',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _conversations = loaded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load chat history: $e');

      if (!mounted) return;

      setState(() {
        _conversations = List<ChatHistoryItem>.from(
          widget.conversations,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConversation(ChatHistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          'Are you sure you want to delete "${item.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          decoded.removeWhere(
            (entry) =>
                entry is Map &&
                entry['id']?.toString() == item.id,
          );

          await prefs.setString(
            _historyKey,
            jsonEncode(decoded),
          );
        }
      }

      widget.onDeleteConversation?.call(item);

      if (!mounted) return;

      setState(() {
        _conversations.removeWhere(
          (conversation) => conversation.id == item.id,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete conversation: $e'),
        ),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);

    if (day == today) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute';
    }

    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat history'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your saved chats will appear here after '
                          'you start chatting with Mafix AI.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 72,
                  ),
                  itemBuilder: (context, index) {
                    final item = _conversations[index];

                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.chat_bubble_outline),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.preview.isNotEmpty)
                            Text(
                              item.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.updatedAt != null)
                            Text(
                              _formatDate(item.updatedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: item.preview.isNotEmpty,
                      onTap: () {
                        widget.onOpenConversation?.call(item);

                        if (widget.onOpenConversation == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Opening saved conversations will be '
                                'connected in the next chat-screen update.',
                              ),
                            ),
                          );
                        }
                      },
                      trailing: IconButton(
                        tooltip: 'Delete conversation',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteConversation(item),
                      ),
                    );
                  },
                ),
    );
  }
}

class ChatHistoryItem {
  final String id;
  final String title;
  final String preview;
  final DateTime? updatedAt;

  const ChatHistoryItem({
    required this.id,
    required this.title,
    this.preview = '',
    this.updatedAt,
  });
}
