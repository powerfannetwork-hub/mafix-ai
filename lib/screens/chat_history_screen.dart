import 'package:flutter/material.dart';

class ChatHistoryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat history')),
      body: conversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  const Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Your saved chats will appear here after chat storage is connected.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                ]),
              ),
            )
          : ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final item = conversations[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: onOpenConversation == null ? null : () => onOpenConversation!(item),
                  trailing: IconButton(
                    tooltip: 'Delete conversation', icon: const Icon(Icons.delete_outline),
                    onPressed: onDeleteConversation == null ? null : () => onDeleteConversation!(item),
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
  const ChatHistoryItem({required this.id, required this.title, this.preview = '', this.updatedAt});
}
