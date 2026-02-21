import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlane/services/git_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('git_channel');
  final List<MethodCall> log = <MethodCall>[];

  setupMockChannel(MethodChannel channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'initRepository':
          return 0;
        case 'getCommitLog':
          return '[{"hash":"abc","message":"test commit","author":"author","date":"2026-02-21 16:00:00"}]';
        case 'getRepositoryStatus':
          return '[{"path":"file.txt","status":"untracked"}]';
        case 'commitAll':
          return 0;
        case 'getCommitDiff':
          return 'diff --git a/file.txt b/file.txt\n+added line';
        default:
          return null;
      }
    });
  }

  setUp(() {
    log.clear();
    setupMockChannel(channel);
  });

  group('GitService verification', () {
    test('initRepository calls native with correct path', () async {
      final result = await GitService.initRepository('/test/path');
      expect(result, 0);
      expect(log.single.method, 'initRepository');
      expect(log.single.arguments, {'path': '/test/path'});
    });

    test('getCommitLog returns parsed string from native', () async {
      final result = await GitService.getCommitLog('/test/path');
      expect(result, isNotNull);
      expect(result, contains('"hash":"abc"'));
      expect(log.single.method, 'getCommitLog');
    });

    test('getRepositoryStatus returns parsed string from native', () async {
      final result = await GitService.getRepositoryStatus('/test/path');
      expect(result, isNotNull);
      expect(result, contains('"status":"untracked"'));
      expect(log.single.method, 'getRepositoryStatus');
    });

    test('commitAll calls native with path and message', () async {
      final result = await GitService.commitAll('/test/path', 'feat: test');
      expect(result, 0);
      expect(log.single.method, 'commitAll');
      expect(log.single.arguments, {'path': '/test/path', 'message': 'feat: test'});
    });

    test('getCommitDiff calls native with hash', () async {
      final result = await GitService.getCommitDiff('/test/path', 'abc');
      expect(result, contains('+added line'));
      expect(log.single.method, 'getCommitDiff');
      expect(log.single.arguments, {'path': '/test/path', 'commitHash': 'abc'});
    });
  });
}
