import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlane/services/push_transaction_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('git_channel');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() async {
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startPush marks tx DONE when push succeeds', () async {
    final repoDir = await Directory.systemTemp.createTemp('gitlane-push-test-');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          log.add(call);
          switch (call.method) {
            case 'getCurrentBranch':
              return 'main';
            case 'getCommitLog':
              return '[{"hash":"abc123","message":"m","author":"a","time":1}]';
            case 'pushRepository':
              return 0;
            default:
              return null;
          }
        });

    final res = await PushTransactionManager.startPush(
      repoPath: repoDir.path,
      token: 't',
    );
    expect(res.state, PushTxState.done);
    expect(res.reconciled, isFalse);

    final journal = await PushTransactionManager.readJournalForTest(
      repoDir.path,
    );
    expect(journal, isNotEmpty);
    expect(journal.last['state'], PushTxState.done);

    await repoDir.delete(recursive: true);
  });

  test(
    'startPush marks DONE via reconciliation when push fails but ahead=0',
    () async {
      final repoDir = await Directory.systemTemp.createTemp(
        'gitlane-push-test-',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            log.add(call);
            switch (call.method) {
              case 'getCurrentBranch':
                return 'main';
              case 'getCommitLog':
                return '[{"hash":"abc123","message":"m","author":"a","time":1}]';
              case 'pushRepository':
                return -1;
              case 'fetchRemote':
                return 0;
              case 'getSyncStatus':
                return '{"ahead":0,"behind":0}';
              default:
                return null;
            }
          });

      final res = await PushTransactionManager.startPush(
        repoPath: repoDir.path,
        token: 't',
      );
      expect(res.state, PushTxState.done);
      expect(res.reconciled, isTrue);

      final journal = await PushTransactionManager.readJournalForTest(
        repoDir.path,
      );
      expect(journal, isNotEmpty);
      expect(journal.last['state'], PushTxState.done);

      await repoDir.delete(recursive: true);
    },
  );

  test(
    'startPush marks FAILED when push fails and ahead>0 after fetch',
    () async {
      final repoDir = await Directory.systemTemp.createTemp(
        'gitlane-push-test-',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            log.add(call);
            switch (call.method) {
              case 'getCurrentBranch':
                return 'main';
              case 'getCommitLog':
                return '[{"hash":"abc123","message":"m","author":"a","time":1}]';
              case 'pushRepository':
                return -1;
              case 'fetchRemote':
                return 0;
              case 'getSyncStatus':
                return '{"ahead":2,"behind":0}';
              default:
                return null;
            }
          });

      final res = await PushTransactionManager.startPush(
        repoPath: repoDir.path,
        token: 't',
      );
      expect(res.state, PushTxState.failed);
      expect(res.reconciled, isTrue);

      final journal = await PushTransactionManager.readJournalForTest(
        repoDir.path,
      );
      expect(journal, isNotEmpty);
      expect(journal.last['state'], PushTxState.failed);

      await repoDir.delete(recursive: true);
    },
  );
}
