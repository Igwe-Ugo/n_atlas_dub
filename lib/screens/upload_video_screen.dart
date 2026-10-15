import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_video_trimmer/flutter_video_trimmer.dart';

import '../network/network.dart';

class UploadVideoScreen extends ConsumerStatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends ConsumerState<UploadVideoScreen> {
  static const _maximumVideoDuration = Duration(minutes: 1);
  bool _isPreparingVideo = false;

  Future<void> _pickAndUploadVideo(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.video);

    if (!mounted || !context.mounted) return;
    if (result.isEmpty) return;

    final filePath = result.single.path;
    if (filePath == null) return;

    final File file = File(filePath);
    File fileToUpload;
    var wasTrimmed = false;

    setState(() => _isPreparingVideo = true);
    try {
      final preparedFile = await _trimIfLongerThanOneMinute(file);
      fileToUpload = preparedFile.file;
      wasTrimmed = preparedFile.wasTrimmed;
    } catch (error) {
      if (context.mounted) {
        print('Could not prepare video: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare video: $error')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isPreparingVideo = false);
    }

    if (!context.mounted) return;
    // Starting this upload clears the previous selection and its workflow data.
    await ref.read(localizationProvider.notifier).uploadVideo(fileToUpload);

    if (!context.mounted) return;

    // Check state for errors
    final state = ref.read(localizationProvider);
    if (state.error != null) {
      print('Upload failed: ${state.error}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: ${state.error}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasTrimmed
                ? 'Video trimmed to one minute and uploaded successfully!'
                : 'Video uploaded successfully!',
          ),
        ),
      );
    }
  }

  Future<({File file, bool wasTrimmed})> _trimIfLongerThanOneMinute(
    File file,
  ) async {
    final trimmer = Trimmer(
      runCommand: (command) async {
        final audioTrimCommand =
            '-af "atrim=duration=${_maximumVideoDuration.inSeconds},'
            'asetpts=PTS-STARTPTS" -c:a aac -b:a 128k';
        if (!command.contains('-c:a copy')) {
          throw Exception('Could not apply the audio duration limit.');
        }
        final commandWithTrimmedAudio = command.replaceFirst(
          '-c:a copy',
          audioTrimCommand,
        );
        final session = await FFmpegKit.execute(commandWithTrimmedAudio);
        final returnCode = await session.getReturnCode();
        if (returnCode?.getValue() != 0) {
          final output = await session.getOutput();
          throw Exception(output ?? 'FFmpeg could not trim this video.');
        }
      },
    );

    try {
      await trimmer.loadVideo(videoFile: file);
      final duration = trimmer.videoPlayerController?.value.duration;
      if (duration == null || duration == Duration.zero) {
        throw Exception('Could not read the video duration.');
      }
      if (duration <= _maximumVideoDuration) {
        return (file: file, wasTrimmed: false);
      }

      String? trimmedPath;
      await trimmer.saveTrimmedVideo(
        startValue: 0,
        endValue: _maximumVideoDuration.inMilliseconds.toDouble(),
        applyVideoEncoding: true,
        storageDir: StorageDir.temporaryDirectory,
        videoFolderName: 'natlas_trimmed_videos',
        // The package's default filename includes a formatted time with ':';
        // Windows rejects colons in filenames, so always provide a safe name.
        videoFileName: 'natlas_trimmed_${DateTime.now().millisecondsSinceEpoch}',
        onSave: (path) => trimmedPath = path,
      );

      if (trimmedPath == null) {
        throw Exception('The trimmer did not return an output file.');
      }
      final trimmedFile = File(trimmedPath!);
      if (!await trimmedFile.exists() || await trimmedFile.length() == 0) {
        throw Exception('The trimmed video file is empty or missing.');
      }
      return (file: trimmedFile, wasTrimmed: true);
    } finally {
      await trimmer.videoPlayerController?.dispose();
      trimmer.dispose();
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
                  'Upload your English marketing video\nto get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 28),

              // Upload Container Card
              GestureDetector(
                onTap: state.isLoading || _isPreparingVideo
                    ? null
                    : () => _pickAndUploadVideo(context),
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
                        child: state.isLoading || _isPreparingVideo
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
                        _isPreparingVideo
                            ? 'Preparing video (maximum 1 minute)...'
                            : state.isLoading
                            ? 'Uploading to N-ATLAS server...'
                            : 'Tap to upload video',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Supported: MP4, MOV, AVI (Max 200MB)',
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

              // Selected Video Card Preview
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C248A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.video_file,
                          color: Color(0xFF2C248A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.selectedFile!.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Video ID: ${state.videoId?.substring(0, 8)}...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Continue CTA Button
              ElevatedButton(
                onPressed: state.videoId != null
                    ? () => Navigator.pushNamed(context, '/selectLanguage')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
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
