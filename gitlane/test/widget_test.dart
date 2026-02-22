import 'package:flutter_test/flutter_test.dart';
import 'package:gitlane/main.dart';

void main() {
  testWidgets('GitLane UI Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: We avoid actions that call native methods in this simple smoke test
    await tester.pumpWidget(const GitLaneApp());

    // Verify that Dashboard renders
    expect(find.text('GitLane'), findsOneWidget);
    expect(find.text('Clone / Init'), findsOneWidget);
  });
}
