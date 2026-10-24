import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      'https://mafix-ai-backend.idrisattijani9.workers.dev/chat';

  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    FocusScope.of(context).unfocus();
    _scrollToBottom();

    try {
      final history = _messages
          .where((message) => message.text.isNotEmpty)
          .toList();

      final previousMessages = history.length > 1
          ? history.sublist(0, history.length - 1)
          : <_ChatMessage>[];

      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': text,
              'history': previousMessages.map((message) {
                return {
                  'role': message.isUser ? 'user' : 'model',
                  'text': message.text,
                };
              }).toList(),
            }),
          )
          .timeout(const Duration(seconds: 60));

      final dynamic data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception('Request failed');
      }

      if (data is! Map || data['reply'] is! String) {
        throw Exception('Invalid response');
      }

      final reply = (data['reply'] as String).trim();

      if (reply.isEmpty) {
        throw Exception('Empty response');
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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Sorry, something went wrong while connecting to Mafix AI. Please try again later.',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
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

  void _showNotice(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
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
            tooltip: 'New chat',
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _messages.clear();
                    });
                  },
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
                        hintText: 'Message Mafix AI...',
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
                  IconButton(
                    tooltip: 'Voice',
                    onPressed: () {
                      _showNotice(
                        'Talk to Mafix AI',
                        'Voice chat is not connected to AI yet.',
                      );
                    },
                    icon: const Icon(
                      Icons.mic_none,
                      color: Color(0xFF39DDFF),
                      size: 27,
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _isLoading ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_upward),
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
