import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class NAtlasApiService {
  late final Dio _dio;
  static const String defaultBaseUrl =
      'https://setup-attraction-met-columnists.trycloudflare.com';

  // Fix: Use proper string keys for SharedPreferences storage lookup
  static const String _baseUrlPreference = 'pref_base_url';
  static const String _apiKeyPreference = 'pref_api_key';

  static const String defaultApiKey = 'n-atlas-secure-key-2026';

  String baseUrl = defaultBaseUrl;
  String apiKey = defaultApiKey;
  late final Future<void> ready;

  NAtlasApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 180),
        receiveTimeout: const Duration(seconds: 180),
        headers: {'Accept': 'application/json'},
      ),
    );
    ready = _loadCredentials();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            await ready;
            options.baseUrl = baseUrl;
            if (apiKey.isEmpty) {
              options.headers.remove('X-API-Key');
            } else {
              options.headers['X-API-Key'] = apiKey;
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
      ),
    );
  }

  Future<void> _loadCredentials() async {
    final preferences = await SharedPreferences.getInstance();
    baseUrl = preferences.getString(_baseUrlPreference) ?? defaultBaseUrl;
    // Fix: Fall back to defaultApiKey if no saved key exists yet
    apiKey = preferences.getString(_apiKeyPreference) ?? defaultApiKey;
    _applyCredentials();
  }

  void _applyCredentials() {
    _dio.options.baseUrl = baseUrl;
    if (apiKey.isEmpty) {
      _dio.options.headers.remove('X-API-Key');
    } else {
      _dio.options.headers['X-API-Key'] = apiKey;
    }
  }

  Future<void> updateCredentials(String url, String key) async {
    await ready;
    final normalizedUrl = url.trim().replaceFirst(RegExp(r'/+$'), '');
    final parsedUrl = Uri.tryParse(normalizedUrl);
    if (parsedUrl == null ||
        (parsedUrl.scheme != 'https' && parsedUrl.scheme != 'http') ||
        parsedUrl.host.isEmpty) {
      throw const FormatException(
        'Enter a valid API base URL starting with http:// or https://.',
      );
    }
    if (key.trim().isEmpty) {
      throw const FormatException('Enter an API key.');
    }

    final preferences = await SharedPreferences.getInstance();
    final savedUrl = await preferences.setString(
      _baseUrlPreference,
      normalizedUrl,
    );
    final savedKey = await preferences.setString(_apiKeyPreference, key.trim());
    if (!savedUrl || !savedKey) {
      throw Exception('Could not save API settings on this device.');
    }
    baseUrl = normalizedUrl;
    apiKey = key.trim();
    _applyCredentials();
  }

  String _apiLanguage(String language) {
    return language == 'Nigerian English' ? 'English' : language;
  }

  String _describeDioError(String endpoint, DioException error) {
    final responseData = error.response?.data;
    final responseBody = responseData is List<int>
        ? utf8.decode(responseData, allowMalformed: true)
        : responseData?.toString();
    final responseSnippet = responseBody == null || responseBody.isEmpty
        ? ''
        : ': ${responseBody.substring(0, responseBody.length > 1000 ? 1000 : responseBody.length)}';
    final description =
        '$endpoint failed with HTTP ${error.response?.statusCode ?? 'no response'}'
        '$responseSnippet';
    if (kDebugMode) {
      debugPrint('$description (type=${error.type}, message=${error.message})');
    }
    return description;
  }

  // 1. POST /upload (Video)
  Future<String> uploadVideo(File file) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });
    final response = await _dio.post('/upload', data: formData);
    return response.data['video_id'] ?? response.data['id'] ?? '';
  }

  // 2. POST /transcribe/{video_id}
  Future<String> transcribeVideo(String videoId) async {
    final response = await _dio.post('/transcribe/$videoId');
    return response.data['transcription'] ?? response.data['text'] ?? '';
  }

  // 3. POST /translate
  Future<String> translateText(String text, String language) async {
    final response = await _dio.post(
      '/translate',
      data: TranslationRequest(
        text: text,
        language: _apiLanguage(language),
      ).toJson(),
    );
    return response.data['translated_text'] ??
        response.data['translation'] ??
        '';
  }

  // 4. POST /generate-speech (Directly returns audio file bytes and handles everything)
  Future<Map<String, dynamic>> startSpeechGeneration(
    String text,
    String language,
    String voice,
    double speed,
  ) async {
    final requestData = SpeechRequest(
      text: text,
      language: _apiLanguage(language),
      voice: voice,
      speed: speed,
    ).toJson();

    try {
      final response = await _dio.post<List<int>>(
        '/generate-speech',
        data: requestData,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.bytes,
        ),
      );

      final body = response.data ?? const <int>[];
      if (body.isEmpty) {
        throw Exception('The speech endpoint returned no audio data.');
      }

      final audioId = response.headers.value('x-audio-id');

      // Return everything the UI needs right away so it never calls /results/ or /jobs/
      return {
        'audio_id': audioId,
        'raw_audio': body,
        'content_type': 'audio/wav',
        'status': 'completed',
      };
    } on DioException catch (error) {
      throw Exception(_describeDioError('POST /generate-speech', error));
    }
  }

  // 5. GET /jobs/{job_id} (Handled gracefully for non-speech jobs or mocked if called)
  Future<Map<String, dynamic>> getSpeechJob(String jobId) async {
    // Since /generate-speech is synchronous, if this is called for speech,
    // we can return a completed status immediately.
    return {'status': 'completed', 'audio_id': jobId};
  }

  // 6. Retrieve generated audio (Handles synchronous results or fetches if stored)
  Future<Map<String, dynamic>> downloadSpeechResult(
    String jobId, {
    String? audioId,
  }) async {
    // Since /generate-speech is synchronous and returns the audio directly,
    // if the UI attempts to fetch via /speech-results/{job_id}, we can map it
    // to check the general results or handle it gracefully.
    // Alternatively, if you have a /results/{job_id} endpoint for rendered videos,
    // ensure audio caching handles the bytes directly from the initial POST /generate-speech response.

    try {
      final response = await _dio.get<List<int>>(
        '/results/$jobId', // Or use the results endpoint if it's a video render job
        options: Options(responseType: ResponseType.bytes),
      );
      final body = response.data ?? const <int>[];
      return {
        'audio_id': response.headers.value('x-audio-id') ?? audioId ?? jobId,
        'raw_audio': body,
        'content_type': response.headers.value('content-type') ?? 'audio/wav',
      };
    } on DioException catch (error) {
      throw Exception(_describeDioError('GET /results/$jobId', error));
    }
  }

  // 7. POST /localize
  Future<String> localizeVideo(RenderRequest request) async {
    final payload = request.toJson();
    payload['language'] = _apiLanguage(request.language);
    if (kDebugMode) {
      debugPrint('POST /localize payload: ${jsonEncode(payload)}');
    }
    try {
      final response = await _dio.post('/localize', data: payload);
      return response.data['job_id'] ?? '';
    } on DioException catch (error) {
      throw Exception(_describeDioError('POST /localize', error));
    }
  }

  // 8. GET /jobs/{job_id} (Render job status)
  Future<String> checkJobStatus(String jobId) async {
    try {
      final response = await _dio.get('/jobs/$jobId');
      return response.data['status'] ?? 'pending';
    } on DioException catch (error) {
      throw Exception(_describeDioError('GET /jobs/$jobId', error));
    }
  }

  // 9. GET /results/{job_id} (Download Result Video)
  Future<Response> downloadResult(String jobId) async {
    try {
      return await _dio.get(
        '/results/$jobId',
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (error) {
      throw Exception(_describeDioError('GET /results/$jobId', error));
    }
  }
}
