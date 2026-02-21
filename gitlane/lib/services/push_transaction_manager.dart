import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'git_service.dart';

class PushTxState {
  static const String pending = 'PENDING';
  static const String done = 'DONE';
  static const String failed = 'FAILED';
}

class PushTxFinalization {
  final String state;
  final int pushCode;
  final int? fetchCode;
  final bool reconciled;

  const PushTxFinalization({
    required this.state,
    required this.pushCode,
    this.fetchCode,
    required this.reconciled,
  });
}

class PushTransactionManager {
  static const String _journalDirName = '.gitlane';
  static const String _journalFileName = 'push_tx_journal.json';

  static final Map<String, Future<void>> _repoLocks = <String, Future<void>>{};

  static Future<PushTxFinalization> startPush({
    required String repoPath,
    required String token,
  }) async {
    final branch = await GitService.getCurrentBranch(repoPath);
    return _withRepoLock(repoPath, () async {
      final headOid = await _resolveHeadOid(repoPath);
      final txId = DateTime.now().microsecondsSinceEpoch.toString();
      final tx = <String, dynamic>{
        'txId': txId,
        'repoPath': repoPath,
        'branch': branch,
        'headOidAtStart': headOid,
        'state': PushTxState.pending,
        'attempt': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await _upsertTx(repoPath, tx);

      final pushCode = await GitService.pushRepository(repoPath, token);
      if (pushCode == 0) {
        tx['state'] = PushTxState.done;
        tx['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _upsertTx(repoPath, tx);
        return const PushTxFinalization(
          state: PushTxState.done,
          pushCode: 0,
          reconciled: false,
        );
      }

      final fetchCode = await GitService.fetchRemote(repoPath, token);
      String finalState = PushTxState.failed;
      if (fetchCode == 0) {
        final sync = await GitService.getSyncStatus(repoPath);
        final ahead = (sync['ahead'] as num?)?.toInt() ?? 0;
        if (ahead == 0) {
          finalState = PushTxState.done;
        }
      }

      tx['state'] = finalState;
      tx['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _upsertTx(repoPath, tx);
      return PushTxFinalization(
        state: finalState,
        pushCode: pushCode,
        fetchCode: fetchCode,
        reconciled: true,
      );
    });
  }

  static Future<void> recoverPending({
    required String repoPath,
    required String token,
  }) async {
    await _withRepoLock(repoPath, () async {
      final entries = await _readJournal(repoPath);
      for (final tx in entries) {
        if (tx['state'] != PushTxState.pending) continue;
        final fetchCode = await GitService.fetchRemote(repoPath, token);
        String finalState = PushTxState.failed;
        if (fetchCode == 0) {
          final sync = await GitService.getSyncStatus(repoPath);
          final ahead = (sync['ahead'] as num?)?.toInt() ?? 0;
          if (ahead == 0) finalState = PushTxState.done;
        }
        tx['state'] = finalState;
        tx['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      }
      await _writeJournal(repoPath, entries);
    });
  }

  static Future<void> seedPendingForTest({
    required String repoPath,
    required String branch,
    String headOidAtStart = 'test-head',
  }) async {
    final tx = <String, dynamic>{
      'txId': DateTime.now().microsecondsSinceEpoch.toString(),
      'repoPath': repoPath,
      'branch': branch,
      'headOidAtStart': headOidAtStart,
      'state': PushTxState.pending,
      'attempt': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _upsertTx(repoPath, tx);
  }

  static Future<List<Map<String, dynamic>>> readJournalForTest(
    String repoPath,
  ) async {
    return _readJournal(repoPath);
  }

  static Future<T> _withRepoLock<T>(
    String repoPath,
    Future<T> Function() body,
  ) async {
    final previous = _repoLocks[repoPath] ?? Future<void>.value();
    final completer = Completer<void>();
    _repoLocks[repoPath] = previous.whenComplete(() => completer.future);
    await previous;
    try {
      return await body();
    } finally {
      completer.complete();
      if (identical(_repoLocks[repoPath], completer.future)) {
        _repoLocks.remove(repoPath);
      }
    }
  }

  static Future<String> _resolveHeadOid(String repoPath) async {
    final logJson = await GitService.getCommitLog(repoPath);
    if (logJson == null || logJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(logJson);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map && first['hash'] != null) {
          return first['hash'].toString();
        }
      }
    } catch (_) {}
    return '';
  }

  static Future<void> _upsertTx(
    String repoPath,
    Map<String, dynamic> tx,
  ) async {
    final list = await _readJournal(repoPath);
    final txId = tx['txId'];
    bool replaced = false;
    for (var i = 0; i < list.length; i++) {
      if (list[i]['txId'] == txId) {
        list[i] = tx;
        replaced = true;
        break;
      }
    }
    if (!replaced) list.add(tx);
    await _writeJournal(repoPath, list);
  }

  static Future<List<Map<String, dynamic>>> _readJournal(
    String repoPath,
  ) async {
    final file = File(_journalPath(repoPath));
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final txt = await file.readAsString();
      final decoded = jsonDecode(txt);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> _writeJournal(
    String repoPath,
    List<Map<String, dynamic>> items,
  ) async {
    final dir = Directory(_journalDirPath(repoPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(_journalPath(repoPath));
    await file.writeAsString(jsonEncode(items));
  }

  static String _journalDirPath(String repoPath) =>
      '$repoPath/$_journalDirName';
  static String _journalPath(String repoPath) =>
      '${_journalDirPath(repoPath)}/$_journalFileName';
}
