import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network.dart';

class SelectLanguageScreen extends ConsumerStatefulWidget {
  const SelectLanguageScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SelectLanguageScreen> createState() =>
      _SelectLanguageScreenState();
}

class _SelectLanguageScreenState extends ConsumerState<SelectLanguageScreen> {
  // Default selected target language
  String selectedLanguage = 'Yoruba';
  String? selectedVoice;
  final TextEditingController _protectedTermsController =
      TextEditingController();

  final List<Map<String, String>> languages = [
    {'name': 'Yoruba', 'native': 'Èdè Yorùbá'},
    {'name': 'Igbo', 'native': 'Asụsụ Igbo'},
    {'name': 'Hausa', 'native': 'Harshen Hausa'},
  ];

  @override
  void dispose() {
    _protectedTermsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(localizationProvider).isLoading;

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
                  'Select Language',
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
                  'Choose the language to translate\nyour video into.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 24),

              // Language options list view
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = selectedLanguage == lang['name'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => selectedLanguage = lang['name']!),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2C248A)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2C248A)
                                        : const Color(0xFFCBD5E1),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2C248A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang['name']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1E1B4B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang['native']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Nigerian flag indicator widget
                              Container(
                                width: 32,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        color: const Color(0xFF008751),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(color: Colors.white),
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: const Color(0xFF008751),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Text(
                'Select a voice',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildVoiceOption('female', 'Female')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildVoiceOption('male', 'Male')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _protectedTermsController,
                decoration: InputDecoration(
                  labelText: 'Names to keep unchanged (optional)',
                  hintText: 'Moniepoint, product names',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Start the background processing job and wait for review segments.
              ElevatedButton(
                onPressed: selectedVoice == null || isLoading
                    ? null
                    : () async {
                        final notifier = ref.read(
                          localizationProvider.notifier,
                        );

                        final languageCode = switch (selectedLanguage) {
                          'Yoruba' => 'yo',
                          'Hausa' => 'ha',
                          'Igbo' => 'ig',
                          _ => throw StateError('Unsupported language.'),
                        };
                        await notifier.startProcessing(
                          targetLanguage: languageCode,
                          voice: selectedVoice!,
                          protectedTerms: _protectedTermsController.text
                              .split(',')
                              .map((term) => term.trim())
                              .where((term) => term.isNotEmpty)
                              .toList(),
                        );
                        if (!context.mounted) return;

                        final workflowState = ref.read(localizationProvider);
                        if (workflowState.error != null ||
                            workflowState.stage != 'review' ||
                            workflowState.segments.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                workflowState.error ??
                                    'The server did not return segments for review.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pushNamed(
                          context,
                          '/translation',
                          arguments: {
                            'language': selectedLanguage,
                            'voice': selectedVoice,
                          },
                        );
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

  Widget _buildVoiceOption(String voice, String label) {
    final isSelected = selectedVoice == voice;
    return OutlinedButton(
      onPressed: () => setState(() => selectedVoice = voice),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFF2C248A) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF2C248A) : const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
