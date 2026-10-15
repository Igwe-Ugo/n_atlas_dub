import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network.dart';

class UploadVideoScreen extends ConsumerStatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends ConsumerState<UploadVideoScreen> {
  static const _maximumVideoSize = 100 * 1024 * 1024;
  bool _consentAccepted = false;

  Future<void> _pickAndUploadVideo() async {
    if (!_consentAccepted) {
      _showMessage('Please agree to video processing before uploading.');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
    );
    if (!mounted || result.isEmpty) return;
    final path = result.single.path;
    if (path == null) return;
    final file = File(path);
    if (await file.length() > _maximumVideoSize) {
      _showMessage('Choose an MP4 file smaller than 100 MB.');
      return;
    }

    await ref
        .read(localizationProvider.notifier)
        .uploadVideo(file, testerName: '', testerEmail: '');
    if (!mounted) return;
    final state = ref.read(localizationProvider);
    if (state.error != null) {
      _showMessage('Upload failed: ${state.error}');
      print('Upload failed: ${state.error}');
    } else {
      final message = state.trimmedFrom != null
          ? 'Video uploaded and trimmed to ${state.uploadedDuration?.toStringAsFixed(0) ?? '90'} seconds.'
          : 'Video uploaded successfully.';
      _showMessage(message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Upload Video',
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
                  'Choose an English MP4 video to dub.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _consentAccepted,
                onChanged: state.isLoading
                    ? null
                    : (value) =>
                          setState(() => _consentAccepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I agree to have this video processed by N-ATLaS.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: state.isLoading ? null : _pickAndUploadVideo,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C248A).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: state.isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF2C248A),
                              )
                            : const Icon(
                                Icons.cloud_upload_outlined,
                                size: 38,
                                color: Color(0xFF2C248A),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.isLoading
                            ? state.statusMessage
                            : 'Tap to choose a video',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'MP4 · maximum 100 MB · up to 90 seconds',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (state.selectedFile != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.video_file, color: Color(0xFF2C248A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${state.selectedFile!.path.split(Platform.pathSeparator).last}\n'
                          'Job: ${state.jobId}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: state.jobId != null && !state.isLoading
                    ? () => Navigator.pushNamed(context, '/selectLanguage')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
