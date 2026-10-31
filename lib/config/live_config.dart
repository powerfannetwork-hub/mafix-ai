class LiveConfig {
  LiveConfig._();

  static const String workerBaseUrl =
      'https://mafix-ai-backend.idrisatijjani9.workers.dev';
  static const String authToken = String.fromEnvironment('MAFIX_LIVE_TOKEN');
  static const String model = 'models/gemini-3.8-live';

  static const int inputSampleRate = 16000;
  static const int outputSampleRate = 24000;

  static const List<Map<String, String>> languages = [
    {'code': 'auto', 'name': 'Automatic'},
    {'code': 'ha', 'name': 'Hausa'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'yo', 'name': 'Yoruba'},
    {'code': 'ig', 'name': 'Igbo'},
    {'code': 'sw', 'name': 'Swahili'},
  ];

  static const List<String> voices = [
    'Puck', 'Charon', 'Kore', 'Fenrir', 'Aoede', 'Leda', 'Orus', 'Zephyr'
  ];

  static Uri get websocketUri => Uri.parse(
        '${workerBaseUrl.replaceFirst('https://', 'wss://')}/live',
      );
}
