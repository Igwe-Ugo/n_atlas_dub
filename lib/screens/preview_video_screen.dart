import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../network/network.dart';

class PreviewVideoScreen extends ConsumerStatefulWidget {
  final String targetLanguage;
  const PreviewVideoScreen({Key? key, required this.targetLanguage})
    : super(key: key);

  @override
  ConsumerState<PreviewVideoScreen> createState() => _PreviewVideoScreenState();
}

class _PreviewVideoScreenState extends ConsumerState<PreviewVideoScreen> {
  bool showSubtitles = true;
  bool backgroundMusic = false;
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _generationStarted = false;
  bool _hasRequestedVideoLoad = false;
  int _videoLoadGeneration = 0;
  String? _videoError;
  String? _currentVideoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateLocalizedPreview();
    });
  }

  Future<void> _loadVideo(String? path) async {
    if (_hasRequestedVideoLoad && _currentVideoPath == path) return;
    final loadGeneration = ++_videoLoadGeneration;
    _hasRequestedVideoLoad = true;
    _currentVideoPath = path;

    final previousController = _videoController;
    _videoController = null;
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _videoError = null;
      });
    }
    // VideoPlayer owns a texture and semantics node. Let Flutter detach the
    // old VideoPlayer from the render tree before disposing that texture.
    await WidgetsBinding.instance.endOfFrame;
    await previousController?.dispose();
    if (loadGeneration != _videoLoadGeneration) return;

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _videoError = 'No generated video is available. Render it to preview.';
      });
      return;
    }

    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(_videoController, controller)) {
        await controller.dispose();
        return;
      }
      setState(() => _isInitialized = true);
    } catch (error) {
      if (!mounted || !identical(_videoController, controller)) return;
      setState(() => _videoError = 'Could not load video: $error');
    }
  }

  Future<void> _generateLocalizedPreview() async {
    if (_generationStarted || !mounted) return;
    _generationStarted = true;
    setState(() => _videoError = null);

    final state = ref.read(localizationProvider);
    final existingPath = state.previewVideoPath;
    if (existingPath != null && await File(existingPath).exists()) {
      await _loadVideo(existingPath);
      return;
    }

    final notifier = ref.read(localizationProvider.notifier);
    await notifier.startLocalizationJob(
      widget.targetLanguage,
      state.translation ?? '',
    );
    if (!mounted) return;

    final jobState = ref.read(localizationProvider);
    if (jobState.error != null) {
      setState(() => _videoError = jobState.error);
      _generationStarted = false;
      return;
    }
    if (jobState.jobId == null || jobState.jobStatus != 'completed') {
      setState(() {
        _videoError = 'Video rendering did not complete. Please try again.';
      });
      _generationStarted = false;
      return;
    }

    final previewFile = await notifier.prepareFinalResultPreview();
    if (!mounted) return;
    if (previewFile == null) {
      final previewState = ref.read(localizationProvider);
      setState(() {
        _videoError =
            'Could not load generated video: '
            '${previewState.error ?? 'Unknown error.'}';
      });
      _generationStarted = false;
      return;
    }
    await _loadVideo(previewFile.path);
  }

  Future<void> _openExportScreen() async {
    // Routes registered in MaterialApp.routes are MaterialPageRoute<dynamic>.
    // Match that result type here to avoid a runtime Route<bool?> cast.
    final shouldDiscard = await Navigator.pushNamed<dynamic>(
      context,
      '/exportVideo',
      arguments: widget.targetLanguage,
    );
    if (shouldDiscard != true || !mounted) return;

    await _videoController?.pause();
    final previousController = _videoController;
    _videoController = null;
    _currentVideoPath = null;
    _hasRequestedVideoLoad = false;
    setState(() => _isInitialized = false);
    await WidgetsBinding.instance.endOfFrame;
    await previousController?.dispose();
    await ref.read(localizationProvider.notifier).discardLocalizedVideo();
  }

  Future<void> _deleteDisplayedVideo() async {
    final hasGeneratedVideo =
        ref.read(localizationProvider).previewVideoPath != null;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hasGeneratedVideo ? 'Discard generated video?' : 'Remove selected video?',
        ),
        content: Text(
          hasGeneratedVideo
              ? 'This removes the downloaded result from this device. '
                    'You can render it again.'
              : 'This clears the selected video and workflow from the app. '
                    'You can then choose another video to upload.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              hasGeneratedVideo ? 'Discard' : 'Remove',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final notifier = ref.read(localizationProvider.notifier);
    if (hasGeneratedVideo) {
      await _videoController?.pause();
      final previousController = _videoController;
      _videoController = null;
      _currentVideoPath = null;
      _hasRequestedVideoLoad = false;
      setState(() => _isInitialized = false);
      await WidgetsBinding.instance.endOfFrame;
      await previousController?.dispose();
      await notifier.discardLocalizedVideo();
      return;
    }
    notifier.resetWorkflow();
    Navigator.pushReplacementNamed(context, '/uploadVideo');
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localizationProvider);
    ref.listen<String?>(
      localizationProvider.select((value) => value.previewVideoPath),
      (_, nextPath) {
        unawaited(_loadVideo(nextPath));
        if (nextPath == null) _generationStarted = false;
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Preview Localized Video',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Review your generated video with voiceover and subtitles.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 20),

              // Video Player with Subtitles Overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.black,
                  child: _videoError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _videoError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                      : _isInitialized && _videoController != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            if (showSubtitles)
                              Positioned(
                                bottom: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  color: Colors.black.withOpacity(0.7),
                                  child: Text(
                                    state.translation ?? '',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: state.isLoading ? null : _deleteDisplayedVideo,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Delete Video',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _buildToggleRow(
                Icons.closed_caption,
                'Show Subtitles',
                showSubtitles,
                (v) => setState(() => showSubtitles = v),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                Icons.music_note,
                'Background Music (Optional)',
                backgroundMusic,
                (v) => setState(() => backgroundMusic = v),
              ),

              if (state.isLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF2C248A)),
                      const SizedBox(height: 8),
                      Text(
                        state.statusMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Display the generated video here, then open export controls.
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (state.previewVideoPath != null) {
                          await _openExportScreen();
                          return;
                        }
                        await _generateLocalizedPreview();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.isLoading
                          ? 'Generating Video...'
                          : state.previewVideoPath == null
                          ? 'Render Video Again'
                          : 'Continue to Export',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2C248A), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1E1B4B),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}
