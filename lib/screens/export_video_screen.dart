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

              // Download Button saves the result, reusing the preview download.
              ElevatedButton.icon(
                onPressed: state.isLoading || state.previewVideoPath == null
                    ? null
                    : () async {
                        final savePath = await FilePickerPlatform.instance
                            .saveFile(
                              dialogTitle: 'Save localized video',
                              fileName: localizedVideoName,
                              bytes: Uint8List(0),
                              mimeType: 'video/mp4',
                            );
                        if (savePath == null || !mounted) return;

                        final String outputPath = savePath.toFilePath();

                        final saved = await ref
                            .read(localizationProvider.notifier)
                            .downloadFinalResult(outputPath);
                        if (!mounted) return;

                        final result = ref.read(localizationProvider);
                        if (saved) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Video saved to: $outputPath'),
                              duration: const Duration(seconds: 8),
                            ),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Download failed: ${result.error ?? 'No completed video was returned.'}',
                            ),
                            duration: const Duration(seconds: 8),
                          ),
                        );
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
                    : const Icon(Icons.download, color: Colors.white, size: 20),
                label: Text(
                  state.isLoading
                      ? 'Downloading...'
                      : state.previewVideoPath != null
                      ? 'Download Video'
                      : 'Preview Video First',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
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
