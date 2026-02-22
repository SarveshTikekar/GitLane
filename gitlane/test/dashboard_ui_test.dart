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

  setUp(() async {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null; // Silent mock for UI tests
    });

    // Disable font fetching and ignore font loading errors in tests
    GoogleFonts.config.allowRuntimeFetching = false;

    // Register a blank font for common families to satisfy the loader
    final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf').catchError((_) => ByteData(0));
    final loader = FontLoader('Inter');
    loader.addFont(Future.value(fontData));
    await loader.load();
  });

  testWidgets('DashboardScreen renders correctly with empty state', (WidgetTester tester) async {
    // Shhh... ignore font errors for now to keep the demo moving
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));
    await tester.pump();

    // Verify Title
    expect(find.text('GitLane'), findsOneWidget);

    // Verify Empty State message - matching the text in dashboard_screen.dart:556
    expect(find.text('No repositories yet'), findsOneWidget);

    // Verify FAB - It says 'Clone / Init' in dashboard_screen.dart:276
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Clone / Init'), findsOneWidget);

    FlutterError.onError = originalOnError;
  });

  testWidgets('DashboardScreen shows search bar', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search repositories…'), findsOneWidget);

    FlutterError.onError = originalOnError;
  });
}
