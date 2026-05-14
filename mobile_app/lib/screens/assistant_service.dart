import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Drop-in replacement for AssistantService.
///
/// Reads your Groq API key from a compile-time constant so it is
/// never hard-coded in source and NEVER spoken aloud to the driver.
///
/// How to run / build:
///   flutter run  --dart-define=GROQ_API_KEY=gsk_xxxxxxxxxxxx
///   flutter build apk --dart-define=GROQ_API_KEY=gsk_xxxxxxxxxxxx
///
/// You can also put it in a launch.json (VS Code) or run configuration
/// (Android Studio) so you only type it once.

class AssistantService {
  // ---------------------------------------------------------------------------
  // Key – read from .env file at runtime via flutter_dotenv
  // ---------------------------------------------------------------------------
  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const _model = 'llama3-8b-8192'; // fast & free on Groq
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  // System prompt tuned for a distraction-free driving assistant
  static const _systemPrompt = '''
You are ADAMS, an in-car voice assistant designed for safe driving.
Rules you must always follow:
- Keep every reply SHORT (1-3 sentences max).
- Never ask the driver to look at the screen.
- If you cannot help, say so briefly and suggest they pull over first.
- Do not mention API keys, configuration, or technical errors to the driver.
''';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Send [prompt] to Groq and return the assistant reply.
  /// Returns a safe fallback message on any error – never leaks technical
  /// details to the driver or TTS.
  Future<String> ask(String prompt) async {
    if (!isConfigured) {
      // Log to console only – do NOT return this as TTS text.
      // ignore: avoid_print
      print('[ADAMS] GROQ_API_KEY is not set. '
          'Run with --dart-define=GROQ_API_KEY=<your_key>');
      return "I'm not fully set up yet. Please check the app configuration.";
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': prompt},
              ],
              'max_tokens': 120, // keep replies short for TTS
              'temperature': 0.6,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            data['choices'][0]['message']['content'] as String? ?? '';
        return content.trim();
      }

      // Log HTTP errors for the developer, return safe text for TTS
      // ignore: avoid_print
      print('[ADAMS] Groq HTTP ${response.statusCode}: ${response.body}');
      return "I couldn't get a response right now. Try again in a moment.";
    } catch (e) {
      // ignore: avoid_print
      print('[ADAMS] Network error: $e');
      return "I lost my connection. Please try again shortly.";
    }
  }
}