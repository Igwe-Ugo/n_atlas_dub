import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/widget.dart';

void main() {
  runApp(const ProviderScope(child: NAtlasApp()));
}

class NAtlasApp extends StatelessWidget {
  const NAtlasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N-ATLAS Video Localizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/dashboard': (context) => const WorkflowScreen(),
        '/uploadVideo': (context) => const UploadVideoScreen(),
        '/selectLanguage': (context) => const SelectLanguageScreen(),
        '/englishTranscript': (context) => const EnglishTranscriptionScreen(),
        '/completion': (context) => const CompletionCelebrationScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/exportVideo': (context) => ExportVideoScreen(
          targetLanguage:
              ModalRoute.of(context)?.settings.arguments as String? ?? 'Yoruba',
        ),
        '/generateVoice': (context) {
          return GenerateVoiceScreen(
            targetLanguage: _requiredRouteString(context, 'language'),
            voice: _requiredRouteString(context, 'voice'),
          );
        },
        '/previewVideo': (context) => PreviewVideoScreen(
          targetLanguage:
              ModalRoute.of(context)?.settings.arguments as String? ?? 'Yoruba',
        ),
        '/translation': (context) => UniversalTranslationScreen(
          targetLanguage: _requiredRouteString(context, 'language'),
          voice: _requiredRouteString(context, 'voice'),
        ),
        // Add UploadScreen, SelectLanguageScreen, TranscriptionScreen next
      },
    );
  }

  String _requiredRouteString(BuildContext context, String key) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map && arguments[key] is String) {
      return arguments[key] as String;
    }
    throw StateError('The "$key" route argument is required.');
  }
}
