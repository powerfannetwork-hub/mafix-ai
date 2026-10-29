import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// Voice conversation screen: speech recognition -> Mafix AI -> spoken reply.
class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  static const String _backendUrl = 'https://mafix-ai-backend.idrisatijjani9.workers.dev/chat';
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  bool _listening = false;
  bool _thinking = false;
  bool _speaking = false;
  String? _speechLocaleId;
  String _recognizedText = '';
  String _reply = 'Taɓa makirufo ka yi magana da Mafix AI.';
  String _status = 'A shirye nake in saurare ka';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) { if (mounted && status == 'notListening' && _listening) setState(() => _listening = false); },
        onError: (error) { if (mounted) setState(() { _listening = false; _status = 'Ba a iya amfani da makirufo ba: ${error.errorMsg}'; }); },
      );
      final locales = await _speech.locales();
      final preferred = locales.where((locale) => ['ha_NG', 'ha-NG', 'en_NG', 'en-US', 'en_US'].contains(locale.localeId)).toList();
      _speechLocaleId = preferred.isNotEmpty ? preferred.first.localeId : null;
      await _tts.setLanguage('ha-NG');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() { if (mounted) setState(() => _speaking = true); });
      _tts.setCompletionHandler(() { if (mounted) setState(() { _speaking = false; _status = 'Na gama amsawa. Za ka iya sake magana.'; }); });
      _tts.setErrorHandler((_) { if (mounted) setState(() => _speaking = false); });
      if (mounted) setState(() { _status = _speechReady ? 'A shirye nake in saurare ka' : 'Ba a kunna speech recognition a wannan na’urar ba'; });
    } catch (e) {
      if (mounted) setState(() => _status = 'Voice setup error: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (_thinking) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      if (_recognizedText.trim().isNotEmpty) await _askAI(_recognizedText.trim());
      return;
    }
    if (!_speechReady) {
      await _initVoice();
      if (!_speechReady) {
        _showMessage('Ba a kunna gane magana ba. Ka duba izinin microphone da harshen speech recognition na wayarka.');
        return;
      }
    }
    await _tts.stop();
    setState(() { _recognizedText = ''; _listening = true; _speaking = false; _status = 'Ina sauraronka…'; });
    await _speech.listen(
      localeId: _speechLocaleId,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _recognizedText = result.recognizedWords);
        if (result.finalResult) {
          setState(() { _listening = false; _status = 'Ina shirya amsa…'; });
          if (_recognizedText.trim().isNotEmpty) _askAI(_recognizedText.trim());
        }
      },
    );
  }

  Future<void> _askAI(String prompt) async {
    if (prompt.trim().isEmpty || _thinking) return;
    setState(() { _thinking = true; _status = 'Mafix AI yana tunani…'; _recognizedText = prompt; });
    try {
      final response = await http.post(Uri.parse(_backendUrl), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode({'message': prompt, 'history': []})).timeout(const Duration(seconds: 60));
      final dynamic data = jsonDecode(response.body);
      if (response.statusCode != 200) throw Exception(data is Map ? (data['error'] ?? data['message'] ?? 'HTTP ${response.statusCode}') : 'HTTP ${response.statusCode}');
      if (data is! Map || data['reply'] is! String || (data['reply'] as String).trim().isEmpty) throw Exception('AI bai dawo da amsa mai kyau ba.');
      final answer = (data['reply'] as String).trim();
      if (!mounted) return;
      setState(() { _reply = answer; _status = 'Ina amsa maka…'; });
      await _tts.speak(answer);
    } catch (e) {
      if (mounted) setState(() { _reply = 'An samu matsala: $e'; _status = 'Amsa ta gaza'; });
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() { _speaking = false; _status = 'Na dakatar da karatu.'; });
  }

  void _showMessage(String message) {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Mafix AI Voice'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _listening || _speaking || _thinking;
    return Scaffold(
      appBar: AppBar(title: const Text('Mafix AI Voice'), centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 28), child: Column(children: [
        const Spacer(),
        AnimatedContainer(duration: const Duration(milliseconds: 350), width: active ? 210 : 180, height: active ? 210 : 180, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFF7770FF), Color(0xFF25245F), Color(0xFF11152F)]), boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(active ? 0.38 : 0.15), blurRadius: active ? 45 : 22, spreadRadius: active ? 8 : 2)]), child: Icon(_listening ? Icons.graphic_eq_rounded : _speaking ? Icons.volume_up_rounded : _thinking ? Icons.more_horiz_rounded : Icons.auto_awesome_rounded, size: 76, color: Colors.white)),
        const SizedBox(height: 34),
        Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        if (_recognizedText.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF171D42), borderRadius: BorderRadius.circular(16)), child: Text('Kai: $_recognizedText', style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: Center(child: Text(_reply, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.55))))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_speaking) IconButton.filledTonal(onPressed: _stopSpeaking, icon: const Icon(Icons.stop_rounded), tooltip: 'Dakatar da amsa'),
          const SizedBox(width: 12),
          GestureDetector(onTap: _toggleListening, child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 76, height: 76, decoration: BoxDecoration(color: _listening ? Colors.redAccent : const Color(0xFF6C63FF), shape: BoxShape.circle), child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 34))),
          const SizedBox(width: 12),
          IconButton.filledTonal(onPressed: _thinking ? null : () { setState(() { _recognizedText = ''; _reply = 'Taɓa makirufo ka yi magana da Mafix AI.'; _status = 'A shirye nake in saurare ka'; }); }, icon: const Icon(Icons.refresh_rounded), tooltip: 'Fara sabo'),
        ]),
        const SizedBox(height: 10),
        const Text('Ka taɓa makirufo ka yi magana. Mafix AI zai amsa da murya.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]))),
    );
  }
}
