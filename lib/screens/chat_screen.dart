import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';
import 'subscription_screen.dart';
import 'chat_history_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'voice_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  final String mode;

  const ChatScreen({
    super.key,
    required this.mode,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  static const String _backendUrl =
      'https://mafix-ai-backend.idrisatijjani9.workers.dev/chat';

  static const String _historyKey = 'mafix_ai_chat_history_v1';

  String _conversationId = '';
  DateTime _conversationCreated = DateTime.now();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _conversationId =
        DateTime.now().microsecondsSinceEpoch.toString();

    _controller.addListener(_onComposerChanged);
    _restoreLastConversation();
  }

  @override
  void dispose() {
    _controller.removeListener(_onComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    if (mounted) setState(() {});
  }

  void _openVoiceConversation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VoiceChatScreen()),
    );
  }

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  // FIX: Scroll to the latest message after the frame is rendered.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Map<String, dynamic> _conversationToJson() {
    final validMessages = _messages
        .where((message) => !message.isError)
        .map((message) => {
              'text': message.text,
              'isUser': message.isUser,
            })
        .toList();

    final firstUserMessage = _messages.firstWhere(
      (message) => message.isUser && !message.isError,
      orElse: () => _ChatMessage(
        text: 'New chat',
        isUser: true,
      ),
    );

    return {
      'id': _conversationId,
      'title': firstUserMessage.text.length > 60
          ? '${firstUserMessage.text.substring(0, 60)}...'
          : firstUserMessage.text,
      'createdAt': _conversationCreated.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'messages': validMessages,
    };
  }

  Future<void> _saveConversation() async {
    if (_messages.where((message) => !message.isError).isEmpty) {
      return;
    }

    // Wait for an earlier save to finish.
    while (_isSaving) {
      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      );
    }

    _isSaving = true;

    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_historyKey);

      List<dynamic> conversations = [];

      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            conversations = decoded;
          }
        } catch (_) {
          conversations = [];
        }
      }

      final current = _conversationToJson();

      final index = conversations.indexWhere(
        (item) =>
            item is Map &&
            item['id']?.toString() == _conversationId,
      );

      if (index >= 0) {
        conversations[index] = current;
      } else {
        conversations.insert(0, current);
      }

      conversations.sort((a, b) {
        final dateA = a is Map
            ? DateTime.tryParse(
                a['updatedAt']?.toString() ?? '',
              )
            : null;

        final dateB = b is Map
            ? DateTime.tryParse(
                b['updatedAt']?.toString() ?? '',
              )
            : null;

        return (dateB ?? DateTime(2000))
            .compareTo(dateA ?? DateTime(2000));
      });

      if (conversations.length > 100) {
        conversations = conversations.take(100).toList();
      }

      await prefs.setString(
        _historyKey,
        jsonEncode(conversations),
      );
    } catch (e) {
      debugPrint('Mafix AI save error: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _restoreLastConversation() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_historyKey);

      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;

      final conversation = decoded.first;
      if (conversation is! Map) return;

      await _loadConversationData(conversation);
    } catch (e) {
      debugPrint('Mafix AI restore error: $e');
    }
  }

  Future<void> _loadConversationData(
    Map<dynamic, dynamic> conversation,
  ) async {
    final storedMessages = conversation['messages'];

    if (storedMessages is! List) return;

    final restored = <_ChatMessage>[];

    for (final item in storedMessages) {
      if (item is! Map) continue;

      final text = item['text']?.toString() ?? '';

      if (text.trim().isEmpty) continue;

      restored.add(
        _ChatMessage(
          text: text,
          isUser: item['isUser'] == true,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(restored);

      _conversationId =
          conversation['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString();

      _conversationCreated = DateTime.tryParse(
            conversation['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now();
    });

    _scrollToBottom();
  }

  Future<void> _openConversation(
    ChatHistoryItem item,
  ) async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_historyKey);

      if (raw == null || raw.isEmpty) {
        _showSnack('No saved conversations were found.');
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        _showSnack('The saved history could not be read.');
        return;
      }

      Map<dynamic, dynamic>? selected;

      for (final entry in decoded) {
        if (entry is Map &&
            entry['id']?.toString() == item.id) {
          selected = entry;
          break;
        }
      }

      if (selected == null) {
        _showSnack('This conversation no longer exists.');
        return;
      }

      await _loadConversationData(selected);
    } catch (e) {
      _showSnack('Could not open this conversation.');
      debugPrint('Mafix AI open history error: $e');
    }
  }

  Future<void> _deleteConversation(ChatHistoryItem item) async {
    try {
      final prefs = await _prefs;
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

      if (_conversationId == item.id && mounted) {
        setState(() {
          _messages.clear();
          _conversationId =
              DateTime.now().microsecondsSinceEpoch.toString();
          _conversationCreated = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Mafix AI delete history error: $e');
      _showSnack('Could not delete this conversation.');
    }
  }

  Future<void> _startNewChat() async {
    if (_isLoading) return;

    await _saveConversation();

    if (!mounted) return;

    setState(() {
      _messages.clear();
      _controller.clear();

      _conversationId =
          DateTime.now().microsecondsSinceEpoch.toString();

      _conversationCreated = DateTime.now();
    });

    FocusScope.of(context).unfocus();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading) return;

    final previousMessages = List<_ChatMessage>.from(_messages);

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _controller.clear();
      _isLoading = true;
    });

    FocusScope.of(context).unfocus();
    _scrollToBottom();

    // Save the user's message before contacting the server.
    await _saveConversation();

    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': text,
              'mode': widget.mode,
              'history': previousMessages
                  .where((message) => !message.isError)
                  .map((message) => {
                        'role': message.isUser ? 'user' : 'model',
                        'text': message.text,
                      })
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 60));

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw Exception(
          'The server returned an invalid response '
          '(HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode != 200) {
        final errorMessage = data is Map
            ? (data['error'] ??
                    data['message'] ??
                    'Unknown server error')
                .toString()
            : 'Unknown server error';

        throw Exception(
          'HTTP ${response.statusCode}: $errorMessage',
        );
      }

      if (data is! Map || data['reply'] is! String) {
        throw Exception(
          'The server response does not contain a valid reply.',
        );
      }

      final reply = (data['reply'] as String).trim();

      if (reply.isEmpty) {
        throw Exception('The AI returned an empty response.');
      }

      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: reply,
            isUser: false,
          ),
        );
      });

      _scrollToBottom();
      await _saveConversation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: 'Mafix AI error:\n${e.toString()}',
              isUser: false,
              isError: true,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showNotice(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171D42),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.pop(context);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF10142F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFF6C63FF),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Mafix AI',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _startNewChat();
                },
                icon: const Icon(Icons.add),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('New chat'),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Text(
                'YOUR SPACE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Chat history'),
              onTap: () {
                Navigator.pop(context);

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatHistoryScreen(
                      onOpenConversation: (item) async {
                        Navigator.of(context).pop();
                        await _openConversation(item);
                      },
                      onDeleteConversation: _deleteConversation,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const Text('Voice conversation'),
              onTap: () => _openPage(const VoiceChatScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => _openPage(const ProfileScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => _openPage(const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Upgrade to Pro'),
              onTap: () => _openPage(const SubscriptionScreen()),
            ),
            const Spacer(),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.login_rounded),
              title: const Text('Login / Register'),
              onTap: () => _openPage(const AuthScreen()),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mafix AI • Your smart assistant',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintText =
        _messages.isEmpty ? 'Ask Mafix AI' : 'Reply to Mafix AI';

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFF39DDFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mafix AI',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Your Smart Assistant',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Upgrade plan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: 'Voice conversation',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VoiceChatScreen(),
                ),
              );
            },
            icon: const Icon(Icons.graphic_eq_rounded),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AuthScreen(),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _isLoading ? null : _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C63FF),
                                    Color(0xFF39DDFF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'What can I help you with?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ask questions, learn something new, '
                              'translate Hausa and English, or get help '
                              'with your assignments.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                height: 1.5,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _SuggestionChip(
                                  label: 'Study help',
                                  icon: Icons.school_outlined,
                                  onTap: () {
                                    _controller.text =
                                        'Help me with my studies';
                                  },
                                ),
                                _SuggestionChip(
                                  label: 'Translate',
                                  icon: Icons.translate,
                                  onTap: () {
                                    _controller.text =
                                        'Translate this into Hausa';
                                  },
                                ),
                                _SuggestionChip(
                                  label: 'Writing',
                                  icon: Icons.edit_note,
                                  onTap: () {
                                    _controller.text =
                                        'Help me write a message';
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isLoading && index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Mafix AI is thinking...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final message = _messages[index];

                        return Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.82,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? const Color(0xFF5148D8)
                                  : const Color(0xFF171D42),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: SelectableText(
                              message.text,
                              style: TextStyle(
                                height: 1.45,
                                color: message.isError
                                    ? Colors.orangeAccent
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D102B),
                border: Border(
                  top: BorderSide(color: Colors.white10),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Camera',
                    onPressed: () {
                      _showNotice(
                        'Live Camera',
                        'Camera is not connected to AI yet.',
                      );
                    },
                    icon: const Icon(
                      Icons.videocam_outlined,
                      color: Color(0xFF39DDFF),
                      size: 27,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: hintText,
                        filled: true,
                        fillColor: const Color(0xFF171D42),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton.filled(
                    tooltip: _controller.text.trim().isEmpty
                        ? 'Live voice conversation'
                        : 'Send message',
                    onPressed: _isLoading
                        ? null
                        : (_controller.text.trim().isEmpty
                            ? _openVoiceConversation
                            : _sendMessage),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      _controller.text.trim().isEmpty
                          ? Icons.graphic_eq_rounded
                          : Icons.arrow_upward,
                    ),
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

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        icon,
        size: 18,
        color: const Color(0xFF9B94FF),
      ),
      label: Text(label),
      backgroundColor: const Color(0xFF171D42),
      side: const BorderSide(color: Colors.white12),
    );
  }
}
