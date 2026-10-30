import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceChatScreen extends StatefulWidget {
const VoiceChatScreen({super.key});

@override
State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
static const String _backendUrl =
'https://mafix-ai-backend.idrisatijjani9.workers.dev/chat';

final stt.SpeechToText _speech = stt.SpeechToText();
final FlutterTts _tts = FlutterTts();
final TextEditingController _controller = TextEditingController();
final ScrollController _scrollController = ScrollController();

final List<_VoiceMessage> _messages = [];

bool _speechAvailable = false;
bool _isListening = false;
bool _isThinking = false;
bool _isSpeaking = false;
bool _continuousConversation = false;
bool _initializing = true;
bool _restartScheduled = false;

String _recognizedText = '';
String _status = 'Preparing voice conversation...';
String _language = 'en-US';

@override
void initState() {
super.initState();
_initializeVoice();
}

@override
void dispose() {
_controller.dispose();
_scrollController.dispose();
_speech.cancel();
_tts.stop();
super.dispose();
}

Future<void> _initializeVoice() async {
try {
_speechAvailable = await _speech.initialize(
onStatus: (status) {
if (!mounted) return;

      if (status == 'done' || status == 'notListening') {
        setState(() {
          _isListening = false;
        });
        // Android speech recognition commonly ends a listening session after
        // a timeout or a pause. In continuous mode, reopen it automatically.
        _scheduleListeningRestart();
      }
    },
    onError: (error) {
      if (!mounted) return;

      setState(() {
        _isListening = false;
        _status = 'Microphone error: ${error.errorMsg}';
      });
      _scheduleListeningRestart(delay: const Duration(seconds: 2));
    },
  );

  await _tts.setSpeechRate(0.48);
  await _tts.setVolume(1.0);
  await _tts.setPitch(1.0);

  _tts.setStartHandler(() {
    if (!mounted) return;

    setState(() {
      _isSpeaking = true;
      _status = 'Mafix AI is speaking...';
    });
  });

  _tts.setCompletionHandler(() {
    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _status = _continuousConversation
          ? 'Your turn — speak now'
          : 'Tap the microphone to speak';
    });

    if (_continuousConversation) {
      _startListening();
    }
  });

  _tts.setCancelHandler(() {
    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  });

  if (!mounted) return;

  setState(() {
    _initializing = false;
    _status = _speechAvailable
        ? 'Tap the microphone and start speaking'
        : 'Speech recognition is unavailable on this device';
  });
} catch (e) {
  if (!mounted) return;

  setState(() {
    _initializing = false;
    _status = 'Could not initialize voice: $e';
  });
}

}

Future<void> _startListening() async {
if (!_speechAvailable ||
_isThinking ||
_isSpeaking ||
_isListening) {
return;
}

try {
  await _tts.stop();

  if (!mounted) return;

  setState(() {
    _recognizedText = '';
    _isListening = true;
    _status = 'Listening... speak now';
  });

  await _speech.listen(
    onResult: (result) {
      if (!mounted) return;

      setState(() {
        _recognizedText = result.recognizedWords;
      });

      if (result.finalResult) {
        final text = result.recognizedWords.trim();

        setState(() {
          _isListening = false;
        });

        if (text.isNotEmpty) {
          _sendToAI(text);
        } else {
          setState(() {
            _status = 'I did not hear anything. Please try again.';
          });

          _scheduleListeningRestart();
        }
      }
    },
    localeId: _language,
    // A single Android recognition session is time-limited. The status
    // callback below automatically starts another session while Live mode
    // remains enabled, so the overall conversation does not time out.
    listenFor: const Duration(minutes: 1),
    pauseFor: const Duration(seconds: 8),
    listenOptions: stt.SpeechListenOptions(
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
    ),
  );
} catch (e) {
  if (!mounted) return;

  setState(() {
    _isListening = false;
    _status = 'Could not start microphone: $e';
  });
  _scheduleListeningRestart(delay: const Duration(seconds: 2));
}

}

void _scheduleListeningRestart({Duration delay = const Duration(milliseconds: 800)}) {
  if (!_continuousConversation || _restartScheduled) return;
  _restartScheduled = true;
  Future.delayed(delay, () {
    _restartScheduled = false;
    if (!mounted || !_continuousConversation || _isThinking || _isSpeaking || _isListening) {
      return;
    }
    _startListening();
  });
}

Future<void> _stopListening() async {
await _speech.stop();

if (!mounted) return;

setState(() {
  _isListening = false;
  _status = 'Microphone stopped';
});

}

Future<void> _sendToAI(String text) async {
final message = text.trim();

if (message.isEmpty || _isThinking) return;

setState(() {
  _messages.add(
    _VoiceMessage(text: message, isUser: true),
  );

  _recognizedText = '';
  _isThinking = true;
  _status = 'Mafix AI is thinking...';
});

_scrollToBottom();

try {
  final previousMessages = _messages
      .take(_messages.length - 1)
      .map((item) => {
            'role': item.isUser ? 'user' : 'assistant',
            'text': item.text,
          })
      .toList();

  final response = await http
      .post(
        Uri.parse(_backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'mode': 'instant',
          'history': previousMessages,
        }),
      )
      .timeout(const Duration(seconds: 60));

  dynamic data;

  try {
    data = jsonDecode(response.body);
  } on FormatException {
    throw Exception('The AI server returned an invalid response.');
  }

  if (response.statusCode != 200) {
    final error = data is Map
        ? (data['error'] ?? data['message'] ?? 'Unknown error')
            .toString()
        : 'Unknown server error';

    throw Exception('HTTP ${response.statusCode}: $error');
  }

  if (data is! Map || data['reply'] is! String) {
    throw Exception('The AI server did not return a valid reply.');
  }

  final reply = (data['reply'] as String).trim();

  if (reply.isEmpty) {
    throw Exception('Mafix AI returned an empty answer.');
  }

  if (!mounted) return;

  setState(() {
    _messages.add(
      _VoiceMessage(text: reply, isUser: false),
    );

    _isThinking = false;
    _status = 'Mafix AI is preparing to speak...';
  });

  _scrollToBottom();

  await _speakReply(reply);
} catch (e) {
  if (!mounted) return;

  setState(() {
    _isThinking = false;
    _messages.add(
      _VoiceMessage(
        text: 'Sorry, I could not get a response. $e',
        isUser: false,
        isError: true,
      ),
    );

    _status = 'There was a connection problem';
  });

  _scrollToBottom();

  if (_continuousConversation) {
    await Future.delayed(const Duration(seconds: 2));

    if (mounted && _continuousConversation) {
      _startListening();
    }
  }
}

}

Future<void> _speakReply(String text) async {
try {
await _tts.stop();

  // Try to use Hausa speech when the user selects Hausa.
  if (_language == 'ha-NG') {
    try {
      await _tts.setLanguage('ha-NG');
    } catch (_) {
      await _tts.setLanguage('en-US');
    }
  } else {
    await _tts.setLanguage(_language);
  }

  if (!mounted) return;

  setState(() {
    _isSpeaking = true;
    _status = 'Mafix AI is speaking...';
  });

  await _tts.speak(text);
} catch (e) {
  if (!mounted) return;

  setState(() {
    _isSpeaking = false;
    _status = 'Could not play the voice response';
  });
}

}

Future<void> _toggleConversation() async {
if (_initializing) return;

if (!_speechAvailable) {
  _showMessage(
    'Speech recognition is unavailable. Check your microphone '
    'permission and Android speech services.',
  );
  return;
}

if (_continuousConversation) {
  setState(() {
    _continuousConversation = false;
    _status = 'Voice conversation paused';
  });

  await _speech.stop();
  await _tts.stop();

  if (!mounted) return;

  setState(() {
    _isListening = false;
    _isSpeaking = false;
  });

  return;
}

setState(() {
  _continuousConversation = true;
  _status = 'Voice conversation started';
});

await _startListening();

}

void _showMessage(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(message)),
);

}

void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((Duration _) {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  });
}

Future<void> _sendTypedMessage() async {
final text = _controller.text.trim();

if (text.isEmpty || _isThinking) return;

_controller.clear();
await _sendToAI(text);

}

void _clearConversation() {
if (_isThinking) {
  _showMessage('Please wait until Mafix AI finishes responding.');
  return;
}
_speech.stop();
_tts.stop();

setState(() {
  _messages.clear();
  _recognizedText = '';
  _isListening = false;
  _isSpeaking = false;
  _isThinking = false;
  _continuousConversation = false;
  _status = 'Tap the microphone and start speaking';
});

}

@override
Widget build(BuildContext context) {
final Color accent = const Color(0xFF6C63FF);

return Scaffold(
  appBar: AppBar(
    title: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice Conversation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Talk naturally with Mafix AI',
          style: TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ],
    ),
    actions: [
      PopupMenuButton<String>(
        tooltip: 'Voice language',
        icon: const Icon(Icons.language),
        onSelected: (value) {
          setState(() {
            _language = value;
          });

          _showMessage(
            value == 'ha-NG'
                ? 'Language set to Hausa'
                : 'Language set to English',
          );
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'en-US',
            child: Text('English'),
          ),
          PopupMenuItem(
            value: 'ha-NG',
            child: Text('Hausa'),
          ),
        ],
      ),
      IconButton(
        tooltip: 'Clear conversation',
        onPressed: _clearConversation,
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  ),
  body: SafeArea(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF121735),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFF39DDFF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.graphic_eq,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mafix AI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isThinking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          size: 76,
                          color: accent,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Let’s talk!',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tap the microphone and speak. '
                          'Mafix AI will listen, answer your question, '
                          'and speak the answer aloud.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _language == 'ha-NG'
                              ? 'Language: Hausa'
                              : 'Language: English',
                          style: const TextStyle(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _messages.length + (_isThinking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isThinking && index == _messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Mafix AI is thinking...'),
                          ],
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? const Color(0xFF5148D8)
                              : const Color(0xFF171D42),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (!message.isUser && !message.isError)
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: 'Read answer aloud',
                                  onPressed: () =>
                                      _speakReply(message.text),
                                  icon: const Icon(
                                    Icons.volume_up_outlined,
                                    size: 20,
                                    color: Color(0xFF39DDFF),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_recognizedText.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF171D42),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'I heard: $_recognizedText',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _continuousConversation
                        ? Icons.autorenew
                        : Icons.touch_app_outlined,
                    color: _continuousConversation
                        ? Colors.greenAccent
                        : Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _continuousConversation
                          ? 'Continuous conversation is ON'
                          : 'Tap the microphone to speak',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendTypedMessage(),
                      decoration: InputDecoration(
                        hintText: 'Or type a message...',
                        filled: true,
                        fillColor: const Color(0xFF171D42),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        _isThinking ? null : _sendTypedMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    tooltip: _isListening
                        ? 'Stop listening'
                        : 'Start listening',
                    onPressed: _initializing
                        ? null
                        : _isListening
                            ? _stopListening
                            : _startListening,
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening
                          ? Colors.redAccent
                          : accent,
                      minimumSize: const Size(60, 60),
                    ),
                    icon: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 22),
                  IconButton.filledTonal(
                    tooltip: _continuousConversation
                        ? 'Stop continuous conversation'
                        : 'Start continuous conversation',
                    onPressed: _toggleConversation,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(60, 60),
                    ),
                    icon: Icon(
                      _continuousConversation
                          ? Icons.pause
                          : Icons.autorenew,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Microphone: speak • Repeat arrows: hands-free mode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
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

class _VoiceMessage {
final String text;
final bool isUser;
final bool isError;

const _VoiceMessage({
required this.text,
required this.isUser,
this.isError = false,
});
}
