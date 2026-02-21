import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlane/main.dart';

void main() {
  testWidgets('GitLane UI Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GitLaneApp());

    // Verify that Dashboard renders
    expect(find.text('GitLane'), findsOneWidget);
    expect(find.text('New Repo'), findsOneWidget);

    // Tap 'New Repo' (it should show a Snackbar)
    await tester.tap(find.text('New Repo'));
    await tester.pump();
    
    // Note: Snackbar testing might require pumpAndSettle or specific finders, 
    // but for now we just verify it doesn't crash.
  });
}
