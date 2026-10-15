import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natlas_video_localizer/network/n_atlas_api_service.dart';
import 'package:natlas_video_localizer/network/n_atlas_provider.dart';
import 'package:natlas_video_localizer/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings save and reload API credentials', (tester) async {
    final apiService = NAtlasApiService();
    await apiService.ready;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [nAtlasApiServiceProvider.overrideWithValue(apiService)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), ' https://settings.example.com/// ');
    await tester.enterText(fields.at(1), 'test-settings-key');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(apiService.baseUrl, 'https://settings.example.com');
    expect(apiService.apiKey, 'test-settings-key');
    expect(find.text('API settings saved. They will apply to new requests.'),
        findsOneWidget);

    final reloadedApiService = NAtlasApiService();
    await reloadedApiService.ready;
    expect(reloadedApiService.baseUrl, 'https://settings.example.com');
    expect(reloadedApiService.apiKey, 'test-settings-key');
  });

  testWidgets('settings rejects an invalid base URL', (tester) async {
    final apiService = NAtlasApiService();
    await apiService.ready;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [nAtlasApiServiceProvider.overrideWithValue(apiService)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'not-a-url');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid http:// or https:// URL.'), findsOneWidget);
    expect(apiService.baseUrl, NAtlasApiService.defaultBaseUrl);
  });
}
