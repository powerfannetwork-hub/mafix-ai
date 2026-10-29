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
static const String _storageKey = 'mafix_ai_chat_history_v1';

List<ChatHistoryItem> _conversations = [];
bool _loading = true;

@override
void initState() {
super.initState();
_loadConversations();
}

Future<void> _loadConversations() async {
try {
final prefs = await SharedPreferences.getInstance();
final raw = prefs.getString(_storageKey);

  final List<ChatHistoryItem> loaded = [];

  if (raw != null) {
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is! Map) continue;

        final messages = entry['messages'];
        if (messages is! List || messages.isEmpty) continue;

        final validMessages = messages.where((message) {
          return message is Map &&
              message['text'] is String &&
              message['isUser'] is bool;
        }).toList();

        if (validMessages.isEmpty) continue;

        final firstUserMessage = validMessages.firstWhere(
          (message) => message['isUser'] == true,
          orElse: () => validMessages.first,
        );

        final lastMessage = validMessages.last;

        final title = (entry['title'] as String?)?.trim();

        loaded.add(
          ChatHistoryItem(
            id: (entry['id'] ?? '').toString(),
            title: title == null || title.isEmpty
                ? (firstUserMessage['text'] as String)
                : title,
            preview: lastMessage['text'] as String,
            updatedAt: DateTime.tryParse(
              (entry['updatedAt'] ?? '').toString(),
            ),
          ),
        );
      }
    }
  }

  loaded.sort((a, b) {
    return (b.updatedAt ?? DateTime(2000))
        .compareTo(a.updatedAt ?? DateTime(2000));
  });

  if (!mounted) return;

  setState(() {
    _conversations = loaded;
    _loading = false;
  });
} catch (e) {
  if (!mounted) return;

  setState(() {
    _conversations = [];
    _loading = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not load chat history.'),
    ),
  );
}

}

Future<void> _deleteConversation(ChatHistoryItem item) async {
final confirmed = await showDialog<bool>(
context: context,
builder: (dialogContext) => AlertDialog(
title: const Text('Delete conversation?'),
content: Text('Delete "${item.title}" permanently from this device?'),
actions: [
TextButton(
onPressed: () => Navigator.pop(dialogContext, false),
child: const Text('Cancel'),
),
FilledButton(
onPressed: () => Navigator.pop(dialogContext, true),
child: const Text('Delete'),
),
],
),
);

if (confirmed != true) return;

try {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey);

  if (raw != null) {
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      decoded.removeWhere(
        (entry) =>
            entry is Map && (entry['id'] ?? '').toString() == item.id,
      );

      await prefs.setString(_storageKey, jsonEncode(decoded));
    }
  }

  if (!mounted) return;

  setState(() {
    _conversations.removeWhere((chat) => chat.id == item.id);
  });

  widget.onDeleteConversation?.call(item);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Conversation deleted.')),
  );
} catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not delete conversation.')),
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
  return '$hour:$minute';
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
onPressed: _loading ? null : _loadConversations,
icon: const Icon(Icons.refresh),
),
],
),
body: _loading
? const Center(child: CircularProgressIndicator())
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
'Your saved Mafix AI chats will appear here.',
textAlign: TextAlign.center,
style: TextStyle(color: Colors.grey.shade600),
),
],
),
),
)
: ListView.separated(
itemCount: conversations.length,
separatorBuilder: (, __) =>
const Divider(height: 1, indent: 72),
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
                  onTap: () => widget.onOpenConversation?.call(item),
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
