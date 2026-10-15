import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network.dart';
import 'preview_video_screen.dart';

class GenerateVoiceScreen extends ConsumerStatefulWidget {
  final String targetLanguage;
  final String voice;
  const GenerateVoiceScreen({
    Key? key,
    required this.targetLanguage,
    required this.voice,
  }) : super(key: key);

  @override
  ConsumerState<GenerateVoiceScreen> createState() =>
      _GenerateVoiceScreenState();
}

class _GenerateVoiceScreenState extends ConsumerState<GenerateVoiceScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Directory? _audioTempDirectory;
  bool _generatedForCurrentSelection = false;
  double _speechSpeed = 0.85;

  @override
  void dispose() {
    unawaited(_disposeAudioResources());
    super.dispose();
  }

  Future<void> _disposeAudioResources() async {
    await _audioPlayer.dispose();
    final directory = _audioTempDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _openPreview() async {
    // Settle the audio player's stream before changing routes. This also avoids
    // keeping an active native audio session beneath the preview screen.
    await _audioPlayer.stop();
    if (!mounted) return;

    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        settings: RouteSettings(
          name: '/previewVideo',
          arguments: widget.targetLanguage,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            PreviewVideoScreen(targetLanguage: widget.targetLanguage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localizationProvider);
    final isAudioReady =
        _generatedForCurrentSelection &&
        state.audioId != null &&
        state.audioId!.isNotEmpty;

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
                  'Generate ${widget.targetLanguage} Voice',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Convert the translation to natural\nlocalized speech.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Selected voice',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.voice == 'female' ? 'Female voice' : 'Male voice',
                  style: const TextStyle(
                    color: Color(0xFF1E1B4B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Speech speed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  Text(
                    '${_speechSpeed.toStringAsFixed(2)}×',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C248A),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _speechSpeed,
                min: 0.65,
                max: 1.25,
                divisions: 12,
                label: '${_speechSpeed.toStringAsFixed(2)}×',
                activeColor: const Color(0xFF2C248A),
                onChanged: state.isLoading
                    ? null
                    : (speed) {
                        if (speed == _speechSpeed) return;
                        setState(() {
                          _speechSpeed = speed;
                          _generatedForCurrentSelection = false;
                        });
                        unawaited(_audioPlayer.stop());
                        ref
                            .read(localizationProvider.notifier)
                            .clearGeneratedSpeech();
                      },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('0.65×'), Text('1.25×')],
                ),
              ),
              const SizedBox(height: 20),

              // Generate Voice Action Button
              ElevatedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        setState(() => _generatedForCurrentSelection = false);
                        await _audioPlayer.stop();
                        await ref
                            .read(localizationProvider.notifier)
                            .generateSpeech(
                              widget.targetLanguage,
                              state.translation ?? '',
                              widget.voice,
                              _speechSpeed,
                            );
                        final result = ref.read(localizationProvider);
                        final audioId = result.audioId;
                        final audioBytes = result.audioBytes;
                        if (mounted &&
                            result.error == null &&
                            audioId != null &&
                            audioId.isNotEmpty) {
                          try {
                            if (audioBytes == null || audioBytes.isEmpty) {
                              throw Exception(
                                'The speech response contained no audio data.',
                              );
                            }
                            final extension = switch (result.audioContentType
                                ?.split(';')
                                .first) {
                              'audio/wav' || 'audio/x-wav' => 'wav',
                              'audio/ogg' => 'ogg',
                              'audio/mp4' || 'audio/m4a' => 'm4a',
                              _ => 'mp3',
                            };
                            _audioTempDirectory ??= await Directory.systemTemp
                                .createTemp('natlas_generated_audio_');
                            final audioFile = File(
                              '${_audioTempDirectory!.path}${Platform.pathSeparator}'
                              'speech-${DateTime.now().microsecondsSinceEpoch}.'
                              '$extension',
                            );
                            await audioFile.writeAsBytes(audioBytes);
                            await _audioPlayer.setFilePath(audioFile.path);
                            if (!mounted) return;
                            setState(
                              () => _generatedForCurrentSelection = true,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voice generated successfully!'),
                              ),
                            );
                          } catch (error) {
                            if (!mounted) return;
                            print('Could not load generated audio: $error');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not load generated audio: $error',
                                ),
                              ),
                            );
                          }
                        } else if (mounted && result.error != null) {
                          print('Voice generation failed: ${result.error}');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Voice generation failed: ${result.error}',
                              ),
                            ),
                          );
                        }
                      },
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2C248A),
                        ),
                      )
                    : const Icon(Icons.graphic_eq, color: Color(0xFF2C248A)),
                label: Text(
                  state.isLoading ? 'Generating Audio...' : 'Generate Voice',
                  style: const TextStyle(
                    color: Color(0xFF2C248A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  disabledBackgroundColor: Colors.grey.shade100,
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Audio Player Feed Indicator (Locked until generated)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    StreamBuilder<PlayerState>(
                      stream: _audioPlayer.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return GestureDetector(
                          onTap: isAudioReady
                              ? () async {
                                  if (isPlaying) {
                                    await _audioPlayer.pause();
                                  } else {
                                    await _audioPlayer.play();
                                  }
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isAudioReady
                                  ? const Color(0xFF2C248A)
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: isAudioReady ? 1.0 : 0.0,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: const Color(0xFF2C248A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isAudioReady ? 'Ready' : 'Not generated',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAudioReady ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue Button
              ElevatedButton(
                onPressed: isAudioReady
                    ? _openPreview
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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
