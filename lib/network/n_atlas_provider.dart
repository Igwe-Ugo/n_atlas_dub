import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'n_atlas_api_service.dart';
import 'models.dart';

final nAtlasApiServiceProvider = Provider<NAtlasApiService>((ref) {
  return NAtlasApiService();
});

class LocalizationState {
  final bool isLoading;
  final String statusMessage;
  final File? selectedFile;
  final String? videoId;
  final String? transcription;
  final String? translation;
  final String? audioId;
  final List<int>? audioBytes;
  final String? audioContentType;
  final String? jobId;
  final String? jobStatus;
  final String? previewVideoPath;
  final String? error;

  LocalizationState({
    this.isLoading = false,
    this.statusMessage = '',
    this.selectedFile,
    this.videoId,
    this.transcription,
    this.translation,
    this.audioId,
    this.audioBytes,
    this.audioContentType,
    this.jobId,
    this.jobStatus,
    this.previewVideoPath,
    this.error,
  });

  LocalizationState copyWith({
    bool? isLoading,
    String? statusMessage,
    File? selectedFile,
    String? videoId,
    String? transcription,
    String? translation,
    String? audioId,
    List<int>? audioBytes,
    String? audioContentType,
    bool clearAudioId = false,
    String? jobId,
    String? jobStatus,
    String? previewVideoPath,
    bool clearPreviewVideoPath = false,
    String? error,
  }) {
    return LocalizationState(
      isLoading: isLoading ?? this.isLoading,
      statusMessage: statusMessage ?? this.statusMessage,
      selectedFile: selectedFile ?? this.selectedFile,
      videoId: videoId ?? this.videoId,
      transcription: transcription ?? this.transcription,
      translation: translation ?? this.translation,
      audioId: clearAudioId ? null : audioId ?? this.audioId,
      audioBytes: clearAudioId ? null : audioBytes ?? this.audioBytes,
      audioContentType: clearAudioId
          ? null
          : audioContentType ?? this.audioContentType,
      jobId: jobId ?? this.jobId,
      jobStatus: jobStatus ?? this.jobStatus,
      previewVideoPath: clearPreviewVideoPath
          ? null
          : previewVideoPath ?? this.previewVideoPath,
      error: error,
    );
  }
}

class LocalizationNotifier extends StateNotifier<LocalizationState> {
  final NAtlasApiService _apiService;

  LocalizationNotifier(this._apiService) : super(LocalizationState());

  void resetWorkflow() {
    final previewPath = state.previewVideoPath;
    if (previewPath != null) {
      unawaited(File(previewPath).parent.delete(recursive: true));
    }
    state = LocalizationState();
  }

  void updateTranslation(String translation) {
    state = state.copyWith(translation: translation);
  }

  void clearGeneratedSpeech() {
    state = state.copyWith(clearAudioId: true);
  }

  // Step 1: Upload Video
  Future<void> uploadVideo(File file) async {
    state = LocalizationState(
      isLoading: true,
      statusMessage: 'Uploading video...',
    );
    try {
      final videoId = await _apiService.uploadVideo(file);
      if (videoId.trim().isEmpty) {
        throw Exception('The upload endpoint did not return a video ID.');
      }
      state = state.copyWith(
        isLoading: false,
        selectedFile: file,
        videoId: videoId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Step 2: Transcribe Video
  Future<void> transcribeVideo() async {
    if (state.videoId == null) {
      state = state.copyWith(
        transcription: '',
        translation: '',
        error: 'Upload a video before starting transcription.',
      );
      return;
    }
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Extracting speech via Whisper...',
        transcription: '',
        translation: '',
        error: null,
      );
      final transcription = await _apiService.transcribeVideo(state.videoId!);
      state = state.copyWith(isLoading: false, transcription: transcription);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Step 3: Translate Text
  Future<void> translateText(String targetLanguage) async {
    final sourceText = state.transcription;
    if (sourceText == null || sourceText.trim().isEmpty) {
      state = state.copyWith(
        translation: '',
        error: 'No transcript is available to translate.',
      );
      return;
    }
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Translating to $targetLanguage...',
        translation: '',
        error: null,
      );
      final translation = await _apiService.translateText(
        sourceText,
        targetLanguage,
      );
      if (translation.trim().isEmpty) {
        throw Exception('The translation endpoint returned empty text.');
      }
      state = state.copyWith(isLoading: false, translation: translation);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Step 4: Submit speech generation, poll its job, then download the WAV.
  Future<void> generateSpeech(
    String targetLanguage,
    String text,
    String voice,
    double speed,
  ) async {
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Generating natural speech...',
        clearAudioId: true,
        error: null,
      );
      final speechJob = await _apiService.startSpeechGeneration(
        text,
        targetLanguage,
        voice,
        speed,
      );

      // The synchronous /generate-speech endpoint returns the audio bytes
      // directly instead of returning a job_id for the async polling flow.
      final directAudio = speechJob['raw_audio'];
      if (directAudio is List && directAudio.isNotEmpty) {
        final audioId = speechJob['audio_id']?.toString();
        if (audioId == null || audioId.isEmpty) {
          throw Exception(
            'Speech audio was generated, but the response did not include an '
            'audio_id. The backend must provide X-Audio-ID so /localize can '
            'use the generated audio.',
          );
        }
        state = state.copyWith(
          isLoading: false,
          audioId: audioId,
          audioBytes: List<int>.from(directAudio),
          audioContentType: speechJob['content_type']?.toString(),
          jobStatus: 'completed',
          statusMessage: 'Speech generated successfully.',
        );
        return;
      }

      final speechJobId = speechJob['job_id'];
      if (speechJobId == null || speechJobId.trim().isEmpty) {
        throw Exception(
          'The speech response contained neither audio bytes nor a usable '
          'job_id. Check the response format from the speech endpoint.',
        );
      }
      var audioId = speechJob['audio_id'];
      state = state.copyWith(
        statusMessage: 'Speech job submitted. Waiting for audio...',
        jobStatus: 'pending',
      );

      final deadline = DateTime.now().add(const Duration(minutes: 10));
      var status = 'pending';
      while (status != 'completed' && status != 'failed') {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('Speech generation did not finish within 10 minutes.');
        }
        await Future.delayed(const Duration(seconds: 2));
        final speechJobStatus = await _apiService.getSpeechJob(speechJobId);
        status = speechJobStatus['status']?.toString().toLowerCase() ??
            'pending';
        final resultData = speechJobStatus['result'];
        audioId ??= speechJobStatus['audio_id']?.toString() ??
            (resultData is Map ? resultData['audio_id']?.toString() : null);
        state = state.copyWith(
          jobStatus: status,
          statusMessage: status == 'completed'
              ? 'Downloading generated audio...'
              : 'Generating natural speech... ($status)',
        );
      }
      if (status == 'failed') {
        throw Exception('Speech generation job failed on the server.');
      }

      final result = await _apiService.downloadSpeechResult(
        speechJobId,
        audioId: audioId,
      );
      audioId = result['audio_id']?.toString() ?? audioId;
      if (audioId == null || audioId.isEmpty) {
        throw Exception(
          'Speech audio was generated, but the server did not provide an '
          'audio_id. The backend must return audio_id in the job response, '
          'job status, or X-Audio-ID response header so /localize can find it.',
        );
      }
      final audioBytes = List<int>.from(
        result['raw_audio'] as List? ?? const [],
      );
      if (audioBytes.isEmpty) {
        throw Exception('Speech generation returned no audio data.');
      }
      state = state.copyWith(
        isLoading: false,
        audioId: audioId,
        audioBytes: audioBytes,
        audioContentType: result['content_type']?.toString(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Step 5 & 6: Localize Video & Poll Job Status until 'completed'
  Future<void> startLocalizationJob(
    String targetLanguage,
    String editedTranslation,
  ) async {
    if (state.videoId == null || state.audioId == null) {
      state = state.copyWith(
        error: 'A video and generated speech are required before rendering.',
      );
      return;
    }
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Submitting render job...',
        jobId: '',
        jobStatus: '',
        error: null,
      );

      final jobId = await _apiService.localizeVideo(
        RenderRequest(
          videoId: state.videoId!,
          audioId: state.audioId!,
          translatedText: editedTranslation,
          language: targetLanguage,
        ),
      );
      if (jobId.trim().isEmpty) {
        throw Exception('The render endpoint did not return a job ID.');
      }

      state = state.copyWith(
        jobId: jobId,
        statusMessage: 'Processing video localization...',
      );

      // Polling loop
      String status = 'pending';
      while (status != 'completed' && status != 'failed') {
        await Future.delayed(const Duration(seconds: 3));
        status = await _apiService.checkJobStatus(jobId);
        state = state.copyWith(jobStatus: status);
        if (status == 'failed') {
          throw Exception('Localization job failed on server.');
        }
      }

      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Localization complete!',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Step 7: Download Result Video
  Future<File?> prepareFinalResultPreview() async {
    final jobId = state.jobId;
    if (jobId == null || jobId.isEmpty) {
      state = state.copyWith(error: 'There is no completed video to preview.');
      return null;
    }

    final existingPath = state.previewVideoPath;
    if (existingPath != null) {
      final existingFile = File(existingPath);
      if (await existingFile.exists() && await existingFile.length() > 0) {
        return existingFile;
      }
    }

    Directory? previewDirectory;
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Preparing video preview...',
        error: null,
      );
      final response = await _apiService.downloadResult(jobId);
      final bytes = response.data;
      if (bytes is! List<int> || bytes.isEmpty) {
        throw Exception('The server returned an empty video file.');
      }
      previewDirectory = await Directory.systemTemp.createTemp(
        'natlas_video_preview_',
      );
      final previewFile = File(
        '${previewDirectory.path}${Platform.pathSeparator}localized_video.mp4',
      );
      await previewFile.writeAsBytes(bytes, flush: true);
      state = state.copyWith(
        isLoading: false,
        previewVideoPath: previewFile.path,
        statusMessage: 'Preview ready.',
      );
      return previewFile;
    } catch (error) {
      if (previewDirectory != null && await previewDirectory.exists()) {
        await previewDirectory.delete(recursive: true);
      }
      state = state.copyWith(isLoading: false, error: error.toString());
      return null;
    }
  }

  Future<void> discardLocalizedVideo() async {
    final previewPath = state.previewVideoPath;
    if (previewPath != null) {
      final previewFile = File(previewPath);
      if (await previewFile.exists()) {
        await previewFile.delete();
      }
      final parent = previewFile.parent;
      if (await parent.exists()) {
        await parent.delete(recursive: true);
      }
    }
    state = state.copyWith(
      previewVideoPath: '',
      clearPreviewVideoPath: true,
      jobId: '',
      jobStatus: '',
      error: null,
      statusMessage: 'Localized preview discarded.',
    );
  }

  Future<bool> downloadFinalResult(String savePath) async {
    if (state.jobId == null) return false;
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Downloading final video...',
      );
      final previewPath = state.previewVideoPath;
      final previewFile = previewPath == null ? null : File(previewPath);
      if (previewFile != null &&
          await previewFile.exists() &&
          await previewFile.length() > 0) {
        await previewFile.copy(savePath);
      } else {
        final response = await _apiService.downloadResult(state.jobId!);
        final bytes = response.data;
        if (bytes is! List<int> || bytes.isEmpty) {
          throw Exception('The server returned an empty video file.');
        }
        await File(savePath).writeAsBytes(bytes, flush: true);
      }
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Video saved to $savePath',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final localizationProvider =
    StateNotifierProvider<LocalizationNotifier, LocalizationState>((ref) {
      final apiService = ref.watch(nAtlasApiServiceProvider);
      return LocalizationNotifier(apiService);
    });
