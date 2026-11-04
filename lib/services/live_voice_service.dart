import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../config/live_config.dart';

enum LiveStatus {
  disconnected,
  connecting,
  listening,
  thinking,
  speaking,
  error,
}

class LiveVoiceService extends ChangeNotifier {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  bool _disposed = false;
  bool _setupComplete = false;
  bool _isDisconnecting = false;

  LiveStatus status = LiveStatus.disconnected;

  String? lastError;
  String inputTranscript = '';
  String outputTranscript = '';

  void _setStatus(LiveStatus value) {
    status = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> connect({
    required String language,
    required String voice,
  }) async {
    if (status == LiveStatus.connecting || _setupComplete) return;

    if (LiveConfig.authToken.isEmpty) {
      lastError = 'Missing MAFIX_LIVE_TOKEN build setting.';
      _setStatus(LiveStatus.error);
      return;
    }

    _isDisconnecting = false;
    _setupComplete = false;
    lastError = null;
    inputTranscript = '';
    outputTranscript = '';

    _setStatus(LiveStatus.connecting);

    try {
      _channel = IOWebSocketChannel.connect(
        LiveConfig.websocketUri,
        headers: {
          'Authorization': 'Bearer ${LiveConfig.authToken}',
        },
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 20),
      );

      _subscription = _channel!.stream.listen(
        _onMessage,

        onError: (Object error) {
          lastError = 'Live WebSocket error: $error';
          _setupComplete = false;
          _setStatus(LiveStatus.error);
        },

        onDone: () {
          _setupComplete = false;

          if (_isDisconnecting || _disposed) return;

          final code = _channel?.closeCode;
          final reason = _channel?.closeReason;

          final details = <String>[];

          if (code != null) {
            details.add('code $code');
          }

          if (reason != null && reason.trim().isNotEmpty) {
            details.add('reason: ${reason.trim()}');
          }

          lastError = details.isEmpty
              ? 'Live server closed the WebSocket connection without sending a close code or reason.'
              : 'Live server closed the WebSocket connection (${details.join(', ')}).';

          _setStatus(LiveStatus.error);
        },

        cancelOnError: false,
      );

      await _channel!.ready;

      _channel!.sink.add(
        jsonEncode({
          'setup': {
            'model': LiveConfig.model,
            'generationConfig': {
              'responseModalities': ['AUDIO'],
              'speechConfig': {
                'voiceConfig': {
                  'prebuiltVoiceConfig': {
                    'voiceName': voice,
                  }
                }
              }
            },
            'systemInstruction': {
              'parts': [
                {
                  'text':
                      'You are Mafix AI, a friendly, accurate multilingual voice assistant. '
                      'Understand the user and reply naturally in the language they are speaking. '
                      'If they speak Hausa, reply in Hausa; if English, reply in English. '
                      'Be conversational, concise when appropriate, and do not claim to support a language '
                      'if you cannot understand it. Preferred language: $language.'
                }
              ]
            },
            'inputAudioTranscription': {},
            'outputAudioTranscription': {},
          }
        }),
      );
    } catch (e) {
      lastError = 'Could not connect to Mafix Live: $e';
      _setupComplete = false;
      _setStatus(LiveStatus.error);
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed || raw is! String) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;

      if (data['setupComplete'] != null) {
        _setupComplete = true;
        _setStatus(LiveStatus.listening);
        return;
      }

      if (data['error'] != null) {
        lastError = 'Live server error: ${data['error']}';
        _setupComplete = false;
        _setStatus(LiveStatus.error);
        return;
      }

      final content = data['serverContent'];

      if (content is! Map<String, dynamic>) return;

      if (content['interrupted'] == true) {
        onInterrupted?.call();
        _setStatus(LiveStatus.listening);
      }

      final input = content['inputTranscription'];

      if (input is Map && input['text'] is String) {
        inputTranscript += input['text'] as String;
        onTranscriptChanged?.call();
      }

      final output = content['outputTranscription'];

      if (output is Map && output['text'] is String) {
        outputTranscript += output['text'] as String;
        onTranscriptChanged?.call();
      }

      final modelTurn = content['modelTurn'];

      if (modelTurn is Map && modelTurn['parts'] is List) {
        for (final part in modelTurn['parts'] as List) {
          if (part is! Map) continue;

          final inline = part['inlineData'] ?? part['inline_data'];

          if (inline is Map && inline['data'] is String) {
            final bytes = base64Decode(
              inline['data'] as String,
            );

            _setStatus(LiveStatus.speaking);

            onAudioChunk?.call(
              Uint8List.fromList(bytes),
            );
          }
        }

        if ((modelTurn['parts'] as List).isEmpty) {
          _setStatus(LiveStatus.thinking);
        }
      }

      if (content['turnComplete'] == true) {
        _setStatus(LiveStatus.listening);
      }
    } catch (e) {
      lastError = 'Could not read Live server message: $e';

      debugPrint('Mafix Live message parse error: $e');

      _setStatus(LiveStatus.error);
    }
  }

  void Function(Uint8List)? onAudioChunk;
  VoidCallback? onInterrupted;
  VoidCallback? onTranscriptChanged;

  void sendAudio(Uint8List pcm) {
    if (!_setupComplete || status == LiveStatus.error) return;

    _send({
      'realtimeInput': {
        'audio': {
          'mimeType':
              'audio/pcm;rate=${LiveConfig.inputSampleRate}',
          'data': base64Encode(pcm),
        }
      }
    });
  }

  void sendAudioStreamEnd() {
    if (_setupComplete) {
      _send({
        'realtimeInput': {
          'audioStreamEnd': true,
        }
      });
    }
  }

  void sendText(String text) {
    if (!_setupComplete || text.trim().isEmpty) return;

    _send({
      'realtimeInput': {
        'text': text.trim(),
      }
    });

    _setStatus(LiveStatus.thinking);
  }

  void _send(Map<String, dynamic> value) {
    try {
      _channel?.sink.add(jsonEncode(value));
    } catch (e) {
      lastError = 'Unable to send Live data: $e';
      _setStatus(LiveStatus.error);
    }
  }

  Future<void> disconnect() async {
    _isDisconnecting = true;
    _setupComplete = false;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close(
        ws_status.normalClosure,
      );
    } catch (_) {}

    _channel = null;

    _setStatus(LiveStatus.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _isDisconnecting = true;

    _subscription?.cancel();

    _channel?.sink.close(
      ws_status.normalClosure,
    );

    super.dispose();
  }
}
