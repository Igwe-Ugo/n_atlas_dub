import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../network/network.dart';

class EnglishTranscriptionScreen extends ConsumerStatefulWidget {
  const EnglishTranscriptionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EnglishTranscriptionScreen> createState() => _EnglishTranscriptionScreenState();
}

class _EnglishTranscriptionScreenState extends ConsumerState<EnglishTranscriptionScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    final state = ref.read(localizationProvider);
    if (state.selectedFile != null) {
      _videoController = VideoPlayerController.file(state.selectedFile!)
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localizationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'English Transcription',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Extracting speech from your video using\nAI (Whisper).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 24),

              // Real Uploaded Video Player Container
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.black,
                  child: _isInitialized && _videoController != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            // Play/Pause Overlay Button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                            // Bottom Progress Info
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                                  ],
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

              // Transcription Result Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.article_outlined, color: Color(0xFF2C248A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Transcription Result',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E1B4B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      state.isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C248A)))
                          : Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  state.transcription ?? 'No transcription available yet.',
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Continue CTA Button -> Moves to Translation selection/screen
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/yoruba-translation');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
