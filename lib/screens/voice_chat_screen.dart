import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../config/live_config.dart';
import '../services/live_voice_service.dart';
import '../widgets/mafix_live_orb.dart';

/// Mafix AI continuous Gemini Live voice screen.
/// Existing navigation can continue using VoiceChatScreen().
class VoiceChatScreen extends StatefulWidget {
const VoiceChatScreen({super.key});

@override
State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
late final LiveVoiceService _live;
final AudioRecorder _recorder = AudioRecorder();
final FlutterSoundPlayer _player = FlutterSoundPlayer();
final TextEditingController _textController = TextEditingController();

StreamSubscription<Uint8List>? _micSubscription;

bool _playerReady = false;
bool _micMuted = false;
bool _starting = false;
bool _showText = false;

String _language = 'auto';
String _voice = 'Aoede';
String _userText = '';
String _aiText = '';
String? _error;

static const Color _background = Color(0xFF090A16);
static const Color _panel = Color(0xFF17192D);
static const Color _blue = Color(0xFF4B9BFF);
static const Color _purple = Color(0xFF9A62FF);

@override
void initState() {
super.initState();

_live = LiveVoiceService();
_live.addListener(_onLiveChanged);

_live.onAudioChunk = _playChunk;
_live.onInterrupted = _stopPlaybackForBargeIn;

_live.onTranscriptChanged = () {
  if (!mounted) return;

  setState(() {
    _userText = _live.inputTranscript;
    _aiText = _live.outputTranscript;
  });
};

_initPlayer();

}

void _onLiveChanged() {
if (!mounted) return;
setState(() => _error = _live.lastError);
}

Future<void> _initPlayer() async {
try {
await _player.openPlayer();

  await _player.startPlayerFromStream(
    codec: Codec.pcm16,
    sampleRate: LiveConfig.outputSampleRate,
    numChannels: 1,
    bufferSize: 8192,
  );

  _playerReady = true;
} catch (e) {
  if (mounted) {
    setState(() => _error = 'Audio playback setup failed: $e');
  }
}

}

Future<void> _startLive() async {
if (_starting || _live.status == LiveStatus.connecting) return;

setState(() {
  _starting = true;
  _error = null;
});

try {
  final permission = await Permission.microphone.request();

  if (!permission.isGranted) {
    throw Exception('Microphone permission is required.');
  }

  if (!_playerReady) {
    await _initPlayer();
  }

  if (!_playerReady) {
    throw Exception('Audio player could not be initialized.');
  }

  await _live.connect(
    language: _language,
    voice: _voice,
  );

  // Wait for Gemini setupComplete before sending microphone audio.
  for (var i = 0; i < 150; i++) {
    if (_live.status == LiveStatus.listening ||
        _live.status == LiveStatus.speaking) {
      break;
    }

    if (_live.status == LiveStatus.error ||
        _live.status == LiveStatus.disconnected) {
      break;
    }

    await Future.delayed(const Duration(milliseconds: 100));
  }

  if (_live.status != LiveStatus.listening &&
      _live.status != LiveStatus.speaking) {
    throw Exception(
      _live.lastError ?? 'Gemini Live setup did not complete.',
    );
  }

  await _startMicrophone();
} catch (e) {
  if (mounted) {
    setState(() => _error = e.toString());
  }

  await _live.disconnect();
} finally {
  if (mounted) {
    setState(() => _starting = false);
  }
}

}

Future<void> _startMicrophone() async {
if (_micMuted || _micSubscription != null) return;

final stream = await _recorder.startStream(
  const RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: LiveConfig.inputSampleRate,
    numChannels: 1,
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  ),
);

_micSubscription = stream.listen(
  (chunk) {
    if (!_micMuted && mounted) {
      _live.sendAudio(chunk);
    }
  },
  onError: (Object e) {
    if (mounted) {
      setState(() => _error = 'Microphone stream error: $e');
    }
  },
);

}

void _playChunk(Uint8List chunk) {
if (!_playerReady) return;

try {
  _player.feedFromStream(chunk);
} catch (e) {
  if (mounted) {
    setState(() => _error = 'Audio playback error: $e');
  }
}

}

Future<void> _stopPlaybackForBargeIn() async {
// Discard queued output when Gemini sends an interrupted event.
try {
if (_playerReady) {
await _player.stopPlayer();

    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: LiveConfig.outputSampleRate,
      numChannels: 1,
      bufferSize: 8192,
    );
  }
} catch (_) {}

}

Future<void> _toggleMute() async {
if (_micMuted) {
setState(() => _micMuted = false);
await _startMicrophone();
} else {
setState(() => _micMuted = true);

  await _micSubscription?.cancel();
  _micSubscription = null;

  await _recorder.stop();
  _live.sendAudioStreamEnd();
}

}

Future<void> _endSession({bool pop = false}) async {
await _micSubscription?.cancel();
_micSubscription = null;

try {
  await _recorder.stop();
} catch (_) {}

await _live.disconnect();

try {
  if (_playerReady) {
    await _player.stopPlayer();
  }
} catch (_) {}

if (pop && mounted) {
  Navigator.of(context).pop();
}

}

void _sendText() {
final text = _textController.text.trim();

if (text.isEmpty) return;

_live.sendText(text);
_textController.clear();
FocusScope.of(context).unfocus();

}

String get _statusLabel {
switch (_live.status) {
case LiveStatus.connecting:
return 'Connecting to Mafix AI...';
case LiveStatus.listening:
return 'Mafix AI is listening';
case LiveStatus.thinking:
return 'Mafix AI is thinking...';
case LiveStatus.speaking:
return 'Mafix AI is speaking';
case LiveStatus.error:
return 'Connection error';
case LiveStatus.disconnected:
return 'Tap the microphone to start';
}
}

Color get _statusColor {
return _live.status == LiveStatus.speaking
? _purple
: _live.status == LiveStatus.error
? Colors.redAccent
: _blue;
}

@override
void dispose() {
_live.removeListener(_onLiveChanged);
_live.dispose();

_micSubscription?.cancel();
_recorder.dispose();

_textController.dispose();

if (_playerReady) {
  _player.closePlayer();
}

super.dispose();

}

@override
Widget build(BuildContext context) {
final active = _live.status == LiveStatus.listening ||
_live.status == LiveStatus.speaking ||
_live.status == LiveStatus.thinking;

return Scaffold(
  backgroundColor: _background,
  body: SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _endSession(pop: true),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white70,
                ),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text(
                      'Mafix AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'LIVE VOICE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showSettings,
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 14),
                  MafixLiveOrb(
                    active: active,
                    color: _statusColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    active
                        ? 'Speak naturally. You can interrupt Mafix AI.'
                        : 'Real-time voice conversation',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (_userText.isNotEmpty || _aiText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _blue.withOpacity(.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_userText.isNotEmpty) ...[
                            const Text(
                              'YOU',
                              style: TextStyle(
                                color: _blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _userText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          if (_aiText.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'MAFIX AI',
                              style: TextStyle(
                                color: Color(0xFFB38AFF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _aiText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_showText) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _sendText(),
                      decoration: InputDecoration(
                        hintText: 'Message Mafix AI...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: _panel,
                        suffixIcon: IconButton(
                          onPressed: _sendText,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: _blue,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundButton(
                icon: _micMuted ? Icons.mic_off : Icons.mic,
                color: _micMuted ? Colors.redAccent : _blue,
                label: _micMuted ? 'Unmute' : 'Mute',
                onTap: active ? _toggleMute : _startLive,
              ),
              const SizedBox(width: 28),
              _roundButton(
                icon: Icons.call_end_rounded,
                color: Colors.redAccent,
                label: 'End',
                onTap: () => _endSession(pop: true),
                large: true,
              ),
              const SizedBox(width: 28),
              _roundButton(
                icon: Icons.keyboard_alt_outlined,
                color: Colors.white70,
                label: 'Text',
                onTap: () {
                  setState(() => _showText = !_showText);
                },
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

}

Widget _roundButton({
required IconData icon,
required Color color,
required String label,
required VoidCallback onTap,
bool large = false,
}) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
Material(
color: color.withOpacity(.16),
shape: const CircleBorder(),
child: InkWell(
customBorder: const CircleBorder(),
onTap: onTap,
child: Container(
width: large ? 68 : 54,
height: large ? 68 : 54,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: color.withOpacity(.18),
border: Border.all(
color: color.withOpacity(.65),
),
),
child: Icon(
icon,
color: color,
size: large ? 29 : 23,
),
),
),
),
const SizedBox(height: 6),
Text(
label,
style: const TextStyle(
color: Colors.white54,
fontSize: 11,
),
),
],
);
}

void _showSettings() {
showModalBottomSheet<void>(
context: context,
backgroundColor: _panel,
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(
top: Radius.circular(22),
),
),
builder: (sheetContext) => StatefulBuilder(
builder: (context, updateSheet) => Padding(
padding: EdgeInsets.fromLTRB(
22,
24,
22,
24 + MediaQuery.of(context).viewInsets.bottom,
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Live Voice Settings',
style: TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 18),
const Text(
'Language preference',
style: TextStyle(color: Colors.white60),
),
DropdownButton<String>(
value: _language,
isExpanded: true,
dropdownColor: _panel,
style: const TextStyle(color: Colors.white),
items: LiveConfig.languages.map((item) {
return DropdownMenuItem<String>(
value: item['code'],
child: Text(item['name']!),
);
}).toList(),
onChanged: (value) {
updateSheet(() {
_language = value ?? 'auto';
});
},
),
const SizedBox(height: 12),
const Text(
'AI voice',
style: TextStyle(color: Colors.white60),
),
DropdownButton<String>(
value: _voice,
isExpanded: true,
dropdownColor: _panel,
style: const TextStyle(color: Colors.white),
items: LiveConfig.voices.map((voice) {
return DropdownMenuItem<String>(
value: voice,
child: Text(voice),
);
}).toList(),
onChanged: (value) {
updateSheet(() {
_voice = value ?? 'Aoede';
});
},
),
const SizedBox(height: 18),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: () => Navigator.pop(sheetContext),
child: const Text('Save settings'),
),
),
const SizedBox(height: 8),
const Text(
'Voice/language changes apply to the next Live session.',
style: TextStyle(
color: Colors.white38,
fontSize: 11,
),
),
],
),
),
),
);
}
}
