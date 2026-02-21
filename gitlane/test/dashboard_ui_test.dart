import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlane/ui/screens/home/dashboard_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:google_fonts/google_fonts.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/test/docs';
  @override
  Future<String?> getTemporaryPath() async => '/test/temp';
  @override
  Future<String?> getLibraryPath() async => '/test/lib';
  @override
  Future<String?> getApplicationSupportPath() async => '/test/support';
  @override
  Future<String?> getExternalStoragePath() async => '/test/ext';
  @override
  Future<List<String>?> getExternalCachePaths() async => ['/test/ext/cache'];
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async => ['/test/ext/storage'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('git_channel');

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null; // Silent mock for UI tests
    });

    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('DashboardScreen renders correctly with empty state', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));

    // Verify Title
    expect(find.text('GitLane'), findsOneWidget);

    // Verify Empty State message
    expect(find.text('No repositories yet'), findsOneWidget);

    // Verify FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New Repo'), findsOneWidget);
  });

  testWidgets('DashboardScreen shows search bar', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search repositories…'), findsOneWidget);
  });
}
