import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final NAtlasApiService _apiService;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiService = ref.read(nAtlasApiServiceProvider);
    _urlController = TextEditingController();
    _keyController = TextEditingController();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    try {
      await _apiService.ready;
      if (!mounted) return;
      _urlController.text = _apiService.baseUrl;
      _keyController.text = _apiService.apiKey;
    } catch (error) {
      if (mounted) _showMessage('Could not load saved settings: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _apiService.updateCredentials(
        _urlController.text,
        _keyController.text,
      );
      if (!mounted) return;
      _showMessage('API settings saved. They will apply to new requests.');
    } catch (error) {
      if (mounted) _showMessage('Could not save API settings: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'API Settings',
          style: TextStyle(
            color: Color(0xFF1E1B4B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: Color(0xFF1E1B4B),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Configure Backend Endpoint',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the API base URL and API key for your backend. '
                    'Settings are saved on this device.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'https://api.example.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      final uri = Uri.tryParse((value ?? '').trim());
                      if (uri == null ||
                          (uri.scheme != 'https' && uri.scheme != 'http') ||
                          uri.host.isEmpty) {
                        return 'Enter a valid http:// or https:// URL.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _keyController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API Key (X-API-Key)',
                      hintText: 'Enter your API key',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter an API key.'
                        : null,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveCredentials,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C248A),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
