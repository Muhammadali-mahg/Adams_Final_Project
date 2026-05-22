import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<FirebaseApp?>? _initialization;
  static Object? _lastError;

  static Object? get lastError => _lastError;

  static String get databaseUrl => _setting('FIREBASE_DATABASE_URL');

  static Future<FirebaseApp?> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<FirebaseApp?> _initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }

    Object? nativeConfigError;
    try {
      final app = await Firebase.initializeApp();
      _lastError = null;
      return app;
    } catch (error) {
      nativeConfigError = error;
    }

    final apiKey = _setting('FIREBASE_API_KEY');
    final appId = _setting('FIREBASE_APP_ID');
    final messagingSenderId = _setting('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = _setting('FIREBASE_PROJECT_ID');
    final databaseUrl = FirebaseBootstrap.databaseUrl;

    final missingKeys = <String>[
      if (apiKey.isEmpty) 'FIREBASE_API_KEY',
      if (appId.isEmpty) 'FIREBASE_APP_ID',
      if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
      if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      if (databaseUrl.isEmpty) 'FIREBASE_DATABASE_URL',
    ];

    if (missingKeys.isNotEmpty) {
      _lastError = StateError(
        'Missing Firebase config: ${missingKeys.join(', ')}. '
        'Native Firebase initialization also failed: $nativeConfigError',
      );
      return null;
    }

    try {
      final app = await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          databaseURL: databaseUrl,
        ),
      );
      _lastError = null;
      return app;
    } catch (error) {
      _lastError = error;
      return null;
    }
  }

  static String _setting(String key) {
    const buildTimeValues = {
      'FIREBASE_API_KEY': String.fromEnvironment('FIREBASE_API_KEY'),
      'FIREBASE_APP_ID': String.fromEnvironment('FIREBASE_APP_ID'),
      'FIREBASE_MESSAGING_SENDER_ID':
          String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
      'FIREBASE_DATABASE_URL': String.fromEnvironment('FIREBASE_DATABASE_URL'),
    };

    final buildTimeValue = buildTimeValues[key]?.trim() ?? '';
    if (buildTimeValue.isNotEmpty) {
      return buildTimeValue;
    }

    return dotenv.env[key]?.trim() ?? '';
  }
}
