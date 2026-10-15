import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NAtlasApiService {
  late final Dio _dio;
  static const String defaultBaseUrl = 'https://natlas-dub.onrender.com';
  static const String _baseUrlPreference = 'pref_base_url';
  static const String _apiKeyPreference = 'pref_api_key';

  String baseUrl = defaultBaseUrl;
  String apiKey = '';
  late final Future<void> ready;

  NAtlasApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 300),
        sendTimeout: const Duration(seconds: 300),
        receiveTimeout: const Duration(seconds: 300),
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
            if (options.path.startsWith('/api/') && apiKey.isNotEmpty) {
              options.headers['X-API-Key'] = apiKey;
            } else {
              options.headers.remove('X-API-Key');
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
    final savedBaseUrl = preferences.getString(_baseUrlPreference);
    // These were temporary tunnel defaults in older builds. Move existing
    // installs to the live API while retaining an explicitly configured URL.
    baseUrl =
        savedBaseUrl == null ||
            savedBaseUrl.contains('trycloudflare.com') ||
            savedBaseUrl.contains('trycloudflare.co')
        ? defaultBaseUrl
        : savedBaseUrl;
    final savedKey = preferences.getString(_apiKeyPreference) ?? '';
    // Older app builds shipped with this default key. The live mobile API has
    // no authentication enabled, so don't send that obsolete value.
    apiKey = savedKey == 'n-atlas-secure-key-2026' ? '' : savedKey;
    _applyCredentials();
  }

  void _applyCredentials() {
    _dio.options.baseUrl = baseUrl;
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

  Map<String, dynamic> _asMap(dynamic value, String endpoint) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('$endpoint returned an unexpected response.');
  }

  String _describeDioError(String endpoint, DioException error) {
    final responseData = error.response?.data;
    final responseBody = responseData is List<int>
        ? utf8.decode(responseData, allowMalformed: true)
        : responseData?.toString();
    final snippet = responseBody == null || responseBody.isEmpty
        ? ''
        : ': ${responseBody.substring(0, responseBody.length > 1000 ? 1000 : responseBody.length)}';
    final statusCode = error.response?.statusCode;
    final description = switch (statusCode) {
      413 => 'The video is too large. Choose an MP4 smaller than 100 MB.',
      429 =>
        'Too many uploads came from this network. Wait a few minutes and try again.',
      502 ||
      503 => 'The GPU worker is offline or waking up. Wait briefly and retry.',
      404 => 'This job could not be found. Jobs expire when the worker sleeps.',
      _ =>
        error.response == null
            ? '$endpoint failed: ${error.message ?? error.type.name}'
            : '$endpoint failed with HTTP $statusCode$snippet',
    };
    if (kDebugMode) debugPrint(description);
    return description;
  }

  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return _asMap(response.data, 'GET /health');
    } on DioException catch (error) {
      throw Exception(_describeDioError('GET /health', error));
    }
  }

  Future<Map<String, dynamic>> uploadVideo(
    File file, {
    required String testerName,
    required String testerEmail,
    required int trimToSeconds,
  }) async {
    final fileName = file.uri.pathSegments.isEmpty
        ? 'video.mp4'
        : file.uri.pathSegments.last;
    final fields = <String, dynamic>{
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
      'consent': 'true',
      'trim_to_seconds': trimToSeconds.toString(),
    };
    if (testerName.trim().isNotEmpty) fields['tester_name'] = testerName.trim();
    if (testerEmail.trim().isNotEmpty) {
      fields['tester_email'] = testerEmail.trim();
    }

    try {
      final response = await _dio.post(
        '/api/upload',
        data: FormData.fromMap(fields),
      );
      return _asMap(response.data, 'POST /api/upload');
    } on DioException catch (error) {
      throw Exception(_describeDioError('POST /api/upload', error));
    }
  }

  Future<void> startProcessing(
    String jobId, {
    required String targetLanguage,
    required String voice,
    required List<String> protectedTerms,
  }) async {
    try {
      await _dio.post(
        '/api/jobs/$jobId/process',
        data: {
          'target_language': targetLanguage,
          'source_language': 'en',
          'voice': voice,
          'protected_terms': protectedTerms,
        },
      );
    } on DioException catch (error) {
      throw Exception(
        _describeDioError('POST /api/jobs/$jobId/process', error),
      );
    }
  }

  Future<Map<String, dynamic>> getJob(String jobId) async {
    try {
      final response = await _dio.get('/api/jobs/$jobId');
      return _asMap(response.data, 'GET /api/jobs/$jobId');
    } on DioException catch (error) {
      throw Exception(_describeDioError('GET /api/jobs/$jobId', error));
    }
  }

  Future<void> updateSegment(String jobId, int index, String editedText) async {
    try {
      await _dio.put(
        '/api/jobs/$jobId/segments/$index',
        data: {'edited_text': editedText},
      );
    } on DioException catch (error) {
      throw Exception(
        _describeDioError('PUT /api/jobs/$jobId/segments/$index', error),
      );
    }
  }

  Future<void> approveSegment(String jobId, int index) async {
    try {
      await _dio.post('/api/jobs/$jobId/segments/$index/approve');
    } on DioException catch (error) {
      throw Exception(
        _describeDioError(
          'POST /api/jobs/$jobId/segments/$index/approve',
          error,
        ),
      );
    }
  }

  Future<void> approveAllSegments(String jobId) async {
    try {
      await _dio.post('/api/jobs/$jobId/approve-all');
    } on DioException catch (error) {
      throw Exception(
        _describeDioError('POST /api/jobs/$jobId/approve-all', error),
      );
    }
  }

  Future<void> startTts(
    String jobId, {
    required double speed,
    required String voice,
  }) async {
    try {
      await _dio.post(
        '/api/jobs/$jobId/tts',
        data: {'speed': speed, 'voice': voice},
      );
    } on DioException catch (error) {
      throw Exception(_describeDioError('POST /api/jobs/$jobId/tts', error));
    }
  }

  Future<void> startRender(
    String jobId, {
    required bool subtitles,
    required String subtitlePosition,
    required bool background,
    required bool mask,
    required double maskHeight,
  }) async {
    try {
      await _dio.post(
        '/api/jobs/$jobId/render',
        data: {
          'subtitles': subtitles,
          'sub_position': subtitlePosition,
          'background': background,
          'mask': mask,
          'mask_height': maskHeight,
        },
      );
    } on DioException catch (error) {
      throw Exception(_describeDioError('POST /api/jobs/$jobId/render', error));
    }
  }

  Future<List<int>> downloadJobMedia(String jobId, String mediaType) async {
    if (!const {'video', 'audio', 'srt', 'source'}.contains(mediaType)) {
      throw ArgumentError.value(mediaType, 'mediaType');
    }
    try {
      final response = await _dio.get<List<int>>(
        '/api/jobs/$jobId/$mediaType',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data ?? const <int>[];
      if (bytes.isEmpty)
        throw Exception('The server returned an empty $mediaType file.');
      return bytes;
    } on DioException catch (error) {
      throw Exception(
        _describeDioError('GET /api/jobs/$jobId/$mediaType', error),
      );
    }
  }
}
