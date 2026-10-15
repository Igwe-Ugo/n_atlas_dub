class TranslationRequest {
  final String text;
  final String language;

  TranslationRequest({required this.text, required this.language});

  Map<String, dynamic> toJson() => {'text': text, 'language': language};
}

class SpeechRequest {
  final String text;
  final String language;
  final String voice;
  final double speed;

  SpeechRequest({
    required this.text,
    required this.language,
    required this.voice,
    required this.speed,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'language': language,
    'voice': voice,
    'speed': speed,
  };
}

class RenderRequest {
  final String videoId;
  final String audioId;
  final String translatedText;
  final String language;

  RenderRequest({
    required this.videoId,
    required this.audioId,
    required this.translatedText,
    required this.language,
  });

  Map<String, dynamic> toJson() => {
    'video_id': videoId,
    'audio_id': audioId,
    'translated_text': translatedText,
    'language': language,
  };
}
