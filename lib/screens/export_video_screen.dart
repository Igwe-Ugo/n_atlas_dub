import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../network/network.dart';

class ExportVideoScreen extends ConsumerStatefulWidget {
  final String targetLanguage;
  const ExportVideoScreen({Key? key, required this.targetLanguage})
    : super(key: key);

  @override
  ConsumerState<ExportVideoScreen> createState() => _ExportVideoScreenState();
}

class _ExportVideoScreenState extends ConsumerState<ExportVideoScreen> {
  Future<void> _saveMedia(String mediaType) async {
    final extension = mediaType == 'srt'
        ? 'srt'
        : mediaType == 'audio'
        ? 'wav'
        : 'mp4';
    final suffix = switch (mediaType) {
      'audio' => 'audio',
      'srt' => 'subtitles',
      'source' => 'original',
      _ => 'video',
    };
    final fileName =
        '${widget.targetLanguage.toLowerCase()}_$suffix.$extension';
    final bytes = await ref
        .read(localizationProvider.notifier)
        .fetchJobMedia(mediaType);
    if (!mounted) return;
    if (bytes == null) {
      final error = ref.read(localizationProvider).error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
      return;
    }

    final saveLocation = await FilePicker.saveFile(
      dialogTitle: 'Save $suffix',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: switch (mediaType) {
        'audio' => 'audio/wav',
        'srt' => 'text/plain',
        _ => 'video/mp4',
      },
    );
    if (saveLocation == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $fileName successfully.'),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Widget _downloadButton(
    LocalizationState state, {
    required String mediaType,
    required String label,
    required IconData icon,
  }) => OutlinedButton.icon(
    onPressed: state.isLoading ? null : () => _saveMedia(mediaType),
    icon: state.isLoading && mediaType == 'video'
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
    label: Text(state.isLoading ? state.statusMessage : label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 44),
      foregroundColor: const Color(0xFF2C248A),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localizationProvider);
    // Format name: Selected Language + "_video.mp4" (e.g., Yoruba_video.mp4)
    final String localizedVideoName =
        '${widget.targetLanguage.toLowerCase()}_video.mp4';

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
              const Center(
                child: Text(
                  'Export Video',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Your localized video is ready!',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 24),

              // Success Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Video created successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C248A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Color(0xFF2C248A),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedVideoName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Your generated preview is ready to download',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              _downloadButton(
                state,
                mediaType: 'video',
                label: 'Download Final Video',
                icon: Icons.video_file,
              ),
              const SizedBox(height: 8),
              _downloadButton(
                state,
                mediaType: 'audio',
                label: 'Download Dubbed Audio (WAV)',
                icon: Icons.audio_file,
              ),
              const SizedBox(height: 8),
              _downloadButton(
                state,
                mediaType: 'srt',
                label: 'Download Subtitles (SRT)',
                icon: Icons.subtitles,
              ),
              const SizedBox(height: 8),
              _downloadButton(
                state,
                mediaType: 'source',
                label: 'Download Original Video',
                icon: Icons.download,
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.play_arrow, color: Color(0xFF2C248A)),
                label: const Text(
                  'Back to Video Preview',
                  style: TextStyle(color: Color(0xFF2C248A)),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Restart Workflow Button
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(localizationProvider.notifier).resetWorkflow();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.add, color: Color(0xFF2C248A)),
                label: const Text(
                  'Create Another Video',
                  style: TextStyle(
                    color: Color(0xFF2C248A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
