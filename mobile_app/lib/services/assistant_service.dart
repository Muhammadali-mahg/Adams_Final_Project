import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  AssistantService({
    String? apiKey,
    String? modelName,
  })  : _apiKey = apiKey ?? _setting('GROQ_API_KEY'),
        _modelName = modelName ??
            _setting(
              'GROQ_MODEL',
              defaultValue: 'llama-3.3-70b-versatile',
            );

  final String _apiKey;
  final String _modelName;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  static String _setting(String key, {String defaultValue = ''}) {
    const buildTimeValues = {
      'GROQ_API_KEY': String.fromEnvironment('GROQ_API_KEY'),
      'GROQ_MODEL': String.fromEnvironment('GROQ_MODEL'),
    };

    final buildTimeValue = buildTimeValues[key]?.trim() ?? '';
    if (buildTimeValue.isNotEmpty) {
      return buildTimeValue;
    }

    final envValue = dotenv.env[key]?.trim() ?? '';
    if (envValue.isNotEmpty) {
      return envValue;
    }

    return defaultValue;
  }

  Future<String> ask(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      return 'I am listening. Tell me what you need.';
    }

    if (!isConfigured) {
      return 'I need the Groq API key before I can answer live requests. Check that mobile_app/.env contains GROQ_API_KEY.';
    }

    final request = {
      'model': _modelName,
      'temperature': 0.35,
      'max_tokens': 220,
      'messages': [
        {'role': 'system', 'content': _systemInstruction},
        {'role': 'user', 'content': cleanPrompt},
      ],
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request),
          )
          .timeout(const Duration(seconds: 18));

      final payload = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = payload['error'];
        final message = error is Map<String, dynamic>
            ? error['message']?.toString()
            : response.reasonPhrase;
        return 'I could not reach Groq correctly: ${message ?? 'request failed'}.';
      }

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        return 'I did not receive a usable answer.';
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        return 'I did not receive a usable answer.';
      }

      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        return 'I did not receive a usable answer.';
      }

      final text = message['content']?.toString().trim();
      if (text == null || text.isEmpty) {
        return 'I did not receive a usable answer.';
      }

      return text;
    } catch (_) {
      return 'I am having trouble connecting right now. Check the network and try again.';
    }
  }
}

const _systemInstruction = '''
You are ADAMS Co-Pilot, a warm, calm female voice assistant for a driver.
Sound natural and companionable, but keep the driver safe.
Keep answers short enough to be spoken aloud while driving.
Do not mention being a language model.
Do not encourage looking at the phone while driving.
For navigation, fuel, food, music, news, or vehicle help, give practical next steps.
If live location, map data, vehicle sensors, or account data is missing, say what you need in one sentence.
Prefer one to three short sentences.
''';
