import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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

  static const String _streamUrl =
      'https://mafix-ai-backend.idrisatijjani9.workers.dev/chat/stream';

  static const String _historyKey = 'mafix_ai_chat_history_v1';

  String _conversationId = '';
  DateTime _conversationCreated = DateTime.now();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isListening = false;
  String _generationStatus = 'thinking';
  late String _selectedMode;
  String _activeRequestId = '';
  http.Client? _streamClient;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  final ImagePicker _imagePicker = ImagePicker();
  String? _attachmentName;
  String? _attachmentMime;
  String? _attachmentBase64;
  String? _attachmentText;

  @override
  void initState() {
    super.initState();

    _conversationId =
        DateTime.now().microsecondsSinceEpoch.toString();
    _selectedMode = _normalizeMode(widget.mode);

    _controller.addListener(_onComposerChanged);
    _initializeSpeech();
    _restoreLastConversation();
  }

  @override
  void dispose() {
    _controller.removeListener(_onComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _streamClient?.close();
    _speech.cancel();
    _tts.stop();
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
    final prefs = await _prefs;
    final saveHistory = prefs.getBool('mafix_save_chat_history') ?? true;
    if (!saveHistory) return;

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
      final saveHistory = prefs.getBool('mafix_save_chat_history') ?? true;
      if (!saveHistory) return;
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

  Future<void> _initializeSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _showSnack('Microphone: ${error.errorMsg}');
        },
      );
    } catch (e) {
      debugPrint('Speech initialization error: $e');
    }
  }

  Future<void> _toggleSpeechToText() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_speechReady) await _initializeSpeech();
    if (!_speechReady) {
      _showSnack('Speech recognition is unavailable. Check microphone permission.');
      return;
    }
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
    );
    if (mounted) setState(() => _isListening = true);
  }

  Future<void> _stopGeneration() async {
    final id = _activeRequestId;
    _streamClient?.close();
    _streamClient = null;
    if (id.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('https://mafix-ai-backend.idrisatijjani9.workers.dev/stop'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'request_id': id}),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generationStatus = 'stopped';
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        _showSnack('Please choose an image smaller than 8 MB.');
        return;
      }
      final ext = image.name.toLowerCase().split('.').last;
      final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
      setState(() {
        _attachmentName = image.name;
        _attachmentMime = mime;
        _attachmentBase64 = base64Encode(bytes);
        _attachmentText = null;
      });
    } catch (e) {
      _showSnack('Could not open image: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnack('Could not read the selected file. Please try again.');
        return;
      }
      if (bytes.length > 8 * 1024 * 1024) {
        _showSnack('Please choose a file smaller than 8 MB.');
        return;
      }
      final ext = (file.extension ?? '').toLowerCase();
      if (ext == 'pdf') {
        setState(() {
          _attachmentName = file.name;
          _attachmentMime = 'application/pdf';
          _attachmentBase64 = base64Encode(bytes);
          _attachmentText = null;
        });
      } else {
        final content = utf8.decode(bytes, allowMalformed: true);
        setState(() {
          _attachmentName = file.name;
          _attachmentMime = 'text/plain';
          _attachmentBase64 = null;
          _attachmentText = content;
        });
      }
    } catch (e) {
      _showSnack('Could not open file: $e');
    }
  }

  void _clearAttachment() {
    setState(() {
      _attachmentName = null;
      _attachmentMime = null;
      _attachmentBase64 = null;
      _attachmentText = null;
    });
  }

  Future<void> _sendAttachmentMessage(String prompt, int assistantIndex, String fileName, String? mimeType, String? fileBase64, String? fileText) async {
    final uri = Uri.parse('https://mafix-ai-backend.idrisatijjani9.workers.dev/chat/attachment');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': prompt,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_base64': fileBase64,
        'file_text': fileText,
        'mode': _selectedMode,
      }),
    ).timeout(const Duration(seconds: 90));
    dynamic data;
    try { data = jsonDecode(response.body); } catch (_) {}
    if (response.statusCode != 200 || data is! Map || data['reply'] == null) {
      throw Exception(data is Map ? data['error'] ?? 'Attachment analysis failed' : 'HTTP ${response.statusCode}');
    }
    if (!mounted) return;
    setState(() {
      _messages[assistantIndex] = _ChatMessage(text: data['reply'].toString(), isUser: false);
    });
    await _saveConversation();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachmentName == null) || _isLoading) return;
    final attachmentName = _attachmentName;
    final attachmentMime = _attachmentMime;
    final attachmentBase64 = _attachmentBase64;
    final attachmentText = _attachmentText;
    final prompt = text.isEmpty ? 'Please analyze the attached file.' : text;

    final previousMessages = List<_ChatMessage>.from(_messages);
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final assistantIndex = _messages.length + 1;

    setState(() {
      _messages.add(_ChatMessage(text: attachmentName == null ? prompt : '$prompt\n\n📎 $attachmentName', isUser: true));
      _messages.add(const _ChatMessage(text: '', isUser: false));
      _controller.clear();
      _attachmentName = null;
      _attachmentMime = null;
      _attachmentBase64 = null;
      _attachmentText = null;
      _isLoading = true;
      _generationStatus = 'thinking';
      _activeRequestId = requestId;
    });
    FocusScope.of(context).unfocus();
    _scrollToBottom();
    await _saveConversation();

    final client = http.Client();
    _streamClient = client;
    var receivedToken = false;
    var streamCompleted = false;

    void updateAssistant(String chunk) {
      if (!mounted || assistantIndex >= _messages.length) return;
      final old = _messages[assistantIndex];
      _messages[assistantIndex] = _ChatMessage(
        text: old.text + chunk,
        isUser: false,
      );
      setState(() {});
      _scrollToBottom();
    }

    try {
      if (attachmentName != null) {
        // Keep the selected attachment immutable while the request is in flight.
        await _sendAttachmentMessage(prompt, assistantIndex, attachmentName, attachmentMime, attachmentBase64, attachmentText);
        return;
      }
      final request = http.Request('POST', Uri.parse(_streamUrl))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        })
        ..body = jsonEncode({
          'message': text,
          'mode': _selectedMode,
          'request_id': requestId,
          'history': previousMessages
              .where((m) => !m.isError)
              .map((m) => {
                    'role': m.isUser ? 'user' : 'assistant',
                    'text': m.text,
                  })
              .toList(),
        });

      final response = await client.send(request).timeout(
        const Duration(seconds: 75),
      );
      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        dynamic decoded;
        try { decoded = jsonDecode(errorBody); } catch (_) {}
        throw Exception(decoded is Map
            ? decoded['error'] ?? 'HTTP ${response.statusCode}'
            : 'HTTP ${response.statusCode}');
      }

      var buffer = '';

      void processSseEvent(String event) {
        for (final line in event.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final raw = line.substring(5).trim();
          if (raw.isEmpty || raw == '[DONE]') continue;

          dynamic payload;
          try {
            payload = jsonDecode(raw);
          } catch (_) {
            continue;
          }
          if (payload is! Map) continue;

          switch (payload['type']) {
            case 'status':
              if (mounted) {
                setState(() => _generationStatus =
                    payload['status']?.toString() ?? 'thinking');
              }
              break;
            case 'token':
              final token = payload['text']?.toString() ?? '';
              if (token.isNotEmpty) {
                receivedToken = true;
                updateAssistant(token);
              }
              break;
            case 'error':
              throw Exception(payload['error'] ?? 'AI stream failed');
            case 'done':
            case 'stopped':
              streamCompleted = true;
              break;
            case 'search_error':
              debugPrint('Mafix search warning: ${payload['error']}');
              break;
          }
        }
      }

      await for (final bytes in response.stream.transform(utf8.decoder)) {
        buffer += bytes.replaceAll('\r\n', '\n');
        while (buffer.contains('\n\n')) {
          final boundary = buffer.indexOf('\n\n');
          final event = buffer.substring(0, boundary);
          buffer = buffer.substring(boundary + 2);
          processSseEvent(event);
        }
      }
      // Some servers close the stream without a final blank-line delimiter.
      if (buffer.trim().isNotEmpty) processSseEvent(buffer);

      if (!receivedToken) {
        throw Exception(streamCompleted
            ? 'AI returned an empty response.'
            : 'The connection ended before Mafix AI replied.');
      }
      await _saveConversation();
    } catch (e) {
      if (mounted && !receivedToken) {
        setState(() {
          if (assistantIndex < _messages.length) {
            _messages[assistantIndex] = _ChatMessage(
              text: 'Mafix AI error:\n${e.toString()}',
              isUser: false,
              isError: true,
            );
          }
        });
      } else if (mounted && receivedToken) {
        _showSnack('Connection ended. The received answer was kept.');
      }
    } finally {
      client.close();
      if (identical(_streamClient, client)) _streamClient = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeRequestId = '';
        });
        _scrollToBottom();
        await _saveConversation();
      }
    }
  }

  String _normalizeMode(String value) {
    final mode = value.toLowerCase().trim();
    if (mode == 'deep research' || mode == 'deep_research') return 'deep research';
    if (mode == 'web search') return 'research';
    if (['thinking', 'analyze', 'research', 'study', 'coding'].contains(mode)) return mode;
    return 'instant';
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard');
  }

  Future<void> _readMessageAloud(String text) async {
    try {
      await _tts.stop();
      await _tts.setSpeechRate(0.48);
      await _tts.speak(text);
    } catch (e) {
      _showSnack('Could not read this answer aloud.');
      debugPrint('TTS error: $e');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'searching': return 'Searching the web...';
      case 'analyzing': return 'Analyzing information...';
      case 'preparing_answer': return 'Preparing answer...';
      case 'stopped': return 'Generation stopped';
      default: return 'Mafix AI is thinking...';
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
          PopupMenuButton<String>(
            tooltip: 'Choose response mode',
            initialValue: _selectedMode,
            onSelected: (value) => setState(() => _selectedMode = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'instant', child: Text('Instant')),
              PopupMenuItem(value: 'thinking', child: Text('Thinking')),
              PopupMenuItem(value: 'analyze', child: Text('Analyze')),
              PopupMenuItem(value: 'research', child: Text('Web research')),
              PopupMenuItem(value: 'deep research', child: Text('Deep research')),
              PopupMenuItem(value: 'study', child: Text('Study mode')),
              PopupMenuItem(value: 'coding', child: Text('Coding mode')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.tune_rounded),
            ),
          ),
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
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
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
                                    _statusLabel(_generationStatus),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _stopGeneration,
                                    child: const Text('Stop'),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(
                                  message.text,
                                  style: TextStyle(
                                    height: 1.45,
                                    color: message.isError
                                        ? Colors.orangeAccent
                                        : Colors.white,
                                  ),
                                ),
                                if (!message.isUser && !message.isError && message.text.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Copy answer',
                                          onPressed: () => _copyMessage(message.text),
                                          icon: const Icon(Icons.copy_rounded, size: 17, color: Colors.white60),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Read aloud',
                                          onPressed: () => _readMessageAloud(message.text),
                                          icon: const Icon(Icons.volume_up_outlined, size: 19, color: Colors.white60),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_attachmentName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Row(children: [
                  const Icon(Icons.attach_file, color: Color(0xFF39DDFF), size: 18),
                  Expanded(child: Text(_attachmentName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))),
                  IconButton(onPressed: _clearAttachment, icon: const Icon(Icons.close, color: Colors.white70, size: 18)),
                ]),
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
                    tooltip: 'More actions / camera',
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: const Color(0xFF171D42),
                      builder: (sheetContext) => SafeArea(
                        child: Wrap(children: [
                          ListTile(
                            leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF39DDFF)),
                            title: const Text('Take a photo'),
                            onTap: () { Navigator.pop(sheetContext); _pickImage(ImageSource.camera); },
                          ),
                          ListTile(
                            leading: const Icon(Icons.image_outlined, color: Color(0xFF39DDFF)),
                            title: const Text('Choose image'),
                            onTap: () { Navigator.pop(sheetContext); _pickImage(ImageSource.gallery); },
                          ),
                          ListTile(
                            leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF39DDFF)),
                            title: const Text('Choose PDF or text file'),
                            subtitle: const Text('PDF, TXT, MD, CSV'),
                            onTap: () { Navigator.pop(sheetContext); _pickDocument(); },
                          ),
                        ]),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF39DDFF), size: 27),
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
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: _isListening ? 'Stop speech-to-text' : 'Speech-to-text',
                    onPressed: _isLoading ? null : _toggleSpeechToText,
                    icon: Icon(
                      _isListening ? Icons.stop_circle : Icons.mic_none_rounded,
                      color: _isListening ? Colors.redAccent : const Color(0xFF39DDFF),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Live voice conversation',
                    onPressed: _isLoading ? null : _openVoiceConversation,
                    icon: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF39DDFF)),
                  ),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _isLoading || (_controller.text.trim().isEmpty && _attachmentName == null)
                        ? null
                        : _sendMessage,
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
