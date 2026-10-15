import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network.dart';

class UniversalTranslationScreen extends ConsumerStatefulWidget {
  final String targetLanguage;
  final String voice;

  const UniversalTranslationScreen({
    Key? key,
    required this.targetLanguage,
    required this.voice,
  }) : super(key: key);

  @override
  ConsumerState<UniversalTranslationScreen> createState() =>
      _UniversalTranslationScreenState();
}

class _UniversalTranslationScreenState
    extends ConsumerState<UniversalTranslationScreen> {
  final Map<int, TextEditingController> _controllers = {};
  int? _savingIndex;

  @override
  void initState() {
    super.initState();
    for (final segment in ref.read(localizationProvider).segments) {
      _controllers[segment.index] = TextEditingController(
        text: segment.editedText.isNotEmpty
            ? segment.editedText
            : segment.translatedText,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _approveSegment(DubSegment segment) async {
    setState(() => _savingIndex = segment.index);
    try {
      await ref
          .read(localizationProvider.notifier)
          .approveSegment(segment.index, _controllers[segment.index]!.text);
    } catch (error) {
      _showMessage('Could not approve segment: $error');
    } finally {
      if (mounted) setState(() => _savingIndex = null);
    }
  }

  Future<void> _approveAllAndContinue() async {
    final state = ref.read(localizationProvider);
    final edits = {
      for (final segment in state.segments)
        segment.index: _controllers[segment.index]!.text,
    };
    setState(() => _savingIndex = -1);
    try {
      await ref.read(localizationProvider.notifier).approveAllSegments(edits);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/generateVoice',
        arguments: {'language': widget.targetLanguage, 'voice': widget.voice},
      );
    } catch (error) {
      _showMessage('Could not approve the segments: $error');
    } finally {
      if (mounted) setState(() => _savingIndex = null);
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
        title: Text('${widget.targetLanguage} review'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Text(
                'Review each translated segment before generating speech. '
                'Approved text is used for the dubbed voice.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: state.segments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final segment = state.segments[index];
                    final controller = _controllers.putIfAbsent(
                      segment.index,
                      () => TextEditingController(
                        text: segment.editedText.isNotEmpty
                            ? segment.editedText
                            : segment.translatedText,
                      ),
                    );
                    final approved = segment.status.toLowerCase() == 'approved';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Segment ${segment.index + 1} · '
                              '${segment.start.toStringAsFixed(1)}–'
                              '${segment.end.toStringAsFixed(1)} s',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C248A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('Original'),
                            Text(segment.originalText),
                            const SizedBox(height: 10),
                            TextField(
                              controller: controller,
                              maxLength: 2000,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Translated text',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (segment.flags.isNotEmpty ||
                                segment.warnings.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  ...segment.flags.map((e) => 'Flag: $e'),
                                  ...segment.warnings.map((e) => 'Warning: $e'),
                                ].join('\n'),
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed:
                                    state.isLoading ||
                                        _savingIndex != null ||
                                        approved
                                    ? null
                                    : () => _approveSegment(segment),
                                icon: Icon(
                                  approved ? Icons.check_circle : Icons.check,
                                ),
                                label: Text(
                                  approved ? 'Approved' : 'Save & approve',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (state.isLoading || _savingIndex != null) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(state.statusMessage),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed:
                    state.segments.isEmpty ||
                        state.isLoading ||
                        _savingIndex != null
                    ? null
                    : _approveAllAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C248A),
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: const Text(
                  'Approve All & Continue to Voice',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
