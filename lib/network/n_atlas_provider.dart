import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models.dart';
import 'n_atlas_api_service.dart';

final nAtlasApiServiceProvider = Provider<NAtlasApiService>((ref) {
  return NAtlasApiService();
});

class LocalizationState {
  final bool isLoading;
  final String statusMessage;
  final File? selectedFile;
  final String? jobId;
  final String? jobStatus;
  final String? stage;
  final List<DubSegment> segments;
  final double? uploadedDuration;
  final double? uploadedSizeMb;
  final double? trimmedFrom;
  final List<int>? audioBytes;
  final String? audioContentType;
  final String? previewVideoPath;
  final String? error;

  const LocalizationState({
    this.isLoading = false,
    this.statusMessage = '',
    this.selectedFile,
    this.jobId,
    this.jobStatus,
    this.stage,
    this.segments = const [],
    this.uploadedDuration,
    this.uploadedSizeMb,
    this.trimmedFrom,
    this.audioBytes,
    this.audioContentType,
    this.previewVideoPath,
    this.error,
  });

  String get transcription => segments.map((s) => s.originalText).join(' ');
  String get translation => segments
      .map((s) => s.editedText.isNotEmpty ? s.editedText : s.translatedText)
      .join(' ');

  LocalizationState copyWith({
    bool? isLoading,
    String? statusMessage,
    File? selectedFile,
    String? jobId,
    String? jobStatus,
    String? stage,
    List<DubSegment>? segments,
    double? uploadedDuration,
    double? uploadedSizeMb,
    double? trimmedFrom,
    List<int>? audioBytes,
    String? audioContentType,
    bool clearAudio = false,
    String? previewVideoPath,
    bool clearPreviewVideoPath = false,
    String? error,
  }) => LocalizationState(
    isLoading: isLoading ?? this.isLoading,
    statusMessage: statusMessage ?? this.statusMessage,
    selectedFile: selectedFile ?? this.selectedFile,
    jobId: jobId ?? this.jobId,
    jobStatus: jobStatus ?? this.jobStatus,
    stage: stage ?? this.stage,
    segments: segments ?? this.segments,
    uploadedDuration: uploadedDuration ?? this.uploadedDuration,
    uploadedSizeMb: uploadedSizeMb ?? this.uploadedSizeMb,
    trimmedFrom: trimmedFrom ?? this.trimmedFrom,
    audioBytes: clearAudio ? null : audioBytes ?? this.audioBytes,
    audioContentType: clearAudio
        ? null
        : audioContentType ?? this.audioContentType,
    previewVideoPath: clearPreviewVideoPath
        ? null
        : previewVideoPath ?? this.previewVideoPath,
    error: error,
  );
}

class LocalizationNotifier extends StateNotifier<LocalizationState> {
  final NAtlasApiService _apiService;

  LocalizationNotifier(this._apiService) : super(const LocalizationState());

  static const _pollInterval = Duration(seconds: 5);
  static const _jobTimeout = Duration(minutes: 20);

  void resetWorkflow() {
    final previewPath = state.previewVideoPath;
    if (previewPath != null) {
      unawaited(File(previewPath).parent.delete(recursive: true));
    }
    state = const LocalizationState();
  }

  void clearGeneratedAudio() {
    state = state.copyWith(clearAudio: true, error: null);
  }

  Future<void> uploadVideo(
    File file, {
    required String testerName,
    required String testerEmail,
  }) async {
    state = const LocalizationState(
      isLoading: true,
      statusMessage:
          'Connecting to N-ATLaS and uploading. The first request can take a few minutes...',
    );
    try {
      // Do not block the first upload on /health: a sleeping Render service or
      // offline GPU can report worker.online=false while the API wakes up.
      final upload = await _apiService.uploadVideo(
        file,
        testerName: testerName,
        testerEmail: testerEmail,
        trimToSeconds: 90,
      );
      final jobId = upload['job_id']?.toString();
      if (jobId == null || jobId.trim().isEmpty) {
        throw Exception('The upload response did not include a job ID.');
      }
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Video uploaded. Ready to process.',
        selectedFile: file,
        jobId: jobId,
        jobStatus: 'done',
        stage: 'uploaded',
        uploadedDuration: _asDouble(upload['duration']),
        uploadedSizeMb: _asDouble(upload['size_mb']),
        trimmedFrom: _asDouble(upload['trimmed_from']),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> startProcessing({
    required String targetLanguage,
    required String voice,
    required List<String> protectedTerms,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(error: 'Upload a video before processing it.');
      return;
    }
    await _runJobStage(
      startMessage: 'Starting transcription and translation...',
      waitingMessage: 'Transcribing and translating video...',
      start: () => _apiService.startProcessing(
        jobId,
        targetLanguage: targetLanguage,
        voice: voice,
        protectedTerms: protectedTerms,
      ),
      targetStage: 'review',
    );
  }

  Future<void> _runJobStage({
    required String startMessage,
    required String waitingMessage,
    required Future<void> Function() start,
    required String targetStage,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(
        error: 'There is no active job. Upload a video first.',
      );
      return;
    }

    final startedAt = DateTime.now();
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: startMessage,
        error: null,
      );
      await start();
      // Give the server time to transition the job out of the previous stage
      // before reading the first status snapshot.
      await Future.delayed(_pollInterval);

      while (DateTime.now().difference(startedAt) < _jobTimeout) {
        final job = await _apiService.getJob(jobId);
        _applyJobSnapshot(job, waitingMessage);
        final status = (job['status']?.toString() ?? '').toLowerCase();
        final stage = job['stage']?.toString().toLowerCase() ?? '';
        if (status == 'error') {
          throw Exception(
            job['reason']?.toString() ??
                job['error']?.toString() ??
                'The server reported that this job failed.',
          );
        }
        if (stage == targetStage && status != 'error') {
          state = state.copyWith(
            isLoading: false,
            statusMessage: 'Stage complete: $targetStage.',
            error: null,
          );
          return;
        }
        if (status != 'running') {
          throw Exception(
            'The job stopped at stage "$stage" before reaching "$targetStage".',
          );
        }
        await Future.delayed(_pollInterval);
      }
      throw Exception('The job is taking too long. Please try again later.');
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void _applyJobSnapshot(Map<String, dynamic> job, String waitingMessage) {
    final rawSegments = job['segments'];
    final segments = rawSegments is List
        ? rawSegments
              .whereType<Map>()
              .map(
                (item) => DubSegment.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : state.segments;
    state = state.copyWith(
      jobStatus: job['status']?.toString(),
      stage: job['stage']?.toString(),
      segments: segments,
      statusMessage: job['stage'] == null
          ? waitingMessage
          : '$waitingMessage (${job['stage']})',
    );
  }

  Future<void> updateSegment(int index, String editedText) async {
    final jobId = state.jobId;
    if (jobId == null) throw Exception('There is no active job.');
    if (editedText.length > 2000) {
      throw Exception('A segment can contain at most 2,000 characters.');
    }
    await _apiService.updateSegment(jobId, index, editedText);
    state = state.copyWith(
      segments: [
        for (final segment in state.segments)
          if (segment.index == index)
            segment.copyWith(editedText: editedText)
          else
            segment,
      ],
    );
  }

  Future<void> approveSegment(int index, String editedText) async {
    final jobId = state.jobId;
    if (jobId == null) throw Exception('There is no active job.');
    await updateSegment(index, editedText);
    await _apiService.approveSegment(jobId, index);
    state = state.copyWith(
      segments: [
        for (final segment in state.segments)
          if (segment.index == index)
            segment.copyWith(
              editedText: editedText,
              finalText: editedText,
              status: 'approved',
            )
          else
            segment,
      ],
    );
  }

  Future<void> approveAllSegments(Map<int, String> editedTexts) async {
    final jobId = state.jobId;
    if (jobId == null) throw Exception('There is no active job.');
    for (final segment in state.segments) {
      final text =
          editedTexts[segment.index] ??
          (segment.editedText.isNotEmpty
              ? segment.editedText
              : segment.translatedText);
      await updateSegment(segment.index, text);
    }
    await _apiService.approveAllSegments(jobId);
    state = state.copyWith(
      segments: [
        for (final segment in state.segments)
          () {
            final text =
                editedTexts[segment.index] ??
                (segment.editedText.isNotEmpty
                    ? segment.editedText
                    : segment.translatedText);
            return segment.copyWith(
              editedText: text,
              finalText: text,
              status: 'approved',
            );
          }(),
      ],
      stage: 'review',
    );
  }

  Future<void> generateSpeech({
    required double speed,
    required String voice,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(error: 'Upload and process a video first.');
      return;
    }
    await _runJobStage(
      startMessage: 'Starting Nigerian voice generation...',
      waitingMessage:
          'Generating dubbed voice. This can take several minutes...',
      targetStage: 'voiced',
      start: () => _apiService.startTts(jobId, speed: speed, voice: voice),
    );
    if (state.error != null) return;

    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Downloading generated audio...',
        error: null,
      );
      final audio = await _apiService.downloadJobMedia(jobId, 'audio');
      state = state.copyWith(
        isLoading: false,
        audioBytes: audio,
        audioContentType: 'audio/wav',
        statusMessage: 'Voice generated successfully.',
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> renderVideo({
    required bool subtitles,
    required String subtitlePosition,
    required bool background,
    bool mask = true,
    double maskHeight = 0.14,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(error: 'There is no active job to render.');
      return;
    }
    await _runJobStage(
      startMessage: 'Starting final video render...',
      waitingMessage: 'Rendering video. Please keep the app open...',
      targetStage: 'rendered',
      start: () => _apiService.startRender(
        jobId,
        subtitles: subtitles,
        subtitlePosition: subtitlePosition,
        background: background,
        mask: mask,
        maskHeight: maskHeight,
      ),
    );
    if (state.error != null) return;

    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Downloading final video...',
        error: null,
      );
      final video = await _apiService.downloadJobMedia(jobId, 'video');
      final directory = await Directory.systemTemp.createTemp(
        'natlas_video_preview_',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}localized_video.mp4',
      );
      await file.writeAsBytes(video, flush: true);
      state = state.copyWith(
        isLoading: false,
        previewVideoPath: file.path,
        statusMessage: 'Preview ready.',
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<List<int>?> fetchJobMedia(String mediaType) async {
    final jobId = state.jobId;
    if (jobId == null) return null;
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Downloading $mediaType...',
        error: null,
      );
      final bytes = mediaType == 'video' && state.previewVideoPath != null
          ? await File(state.previewVideoPath!).readAsBytes()
          : await _apiService.downloadJobMedia(jobId, mediaType);
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Ready to save $mediaType.',
      );
      return bytes;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return null;
    }
  }

  Future<void> discardLocalizedVideo() async {
    final previewPath = state.previewVideoPath;
    if (previewPath != null) {
      final previewFile = File(previewPath);
      if (await previewFile.exists()) await previewFile.delete();
      final parent = previewFile.parent;
      if (await parent.exists()) await parent.delete(recursive: true);
    }
    state = state.copyWith(
      clearPreviewVideoPath: true,
      statusMessage: 'Preview removed from this device.',
      error: null,
    );
  }

  double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

final localizationProvider =
    StateNotifierProvider<LocalizationNotifier, LocalizationState>((ref) {
      final apiService = ref.watch(nAtlasApiServiceProvider);
      return LocalizationNotifier(apiService);
    });
