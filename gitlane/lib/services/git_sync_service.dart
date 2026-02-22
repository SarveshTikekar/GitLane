import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'git_service.dart';

enum PushTxState { pending, done, failed }

class PushTx {
  final String txId;
  final String repoPath;
  final String branch;
  final String headOidAtStart;
  PushTxState state;
  int attempt;
  DateTime updatedAt;

  PushTx({
    required this.txId,
    required this.repoPath,
    required this.branch,
    required this.headOidAtStart,
    this.state = PushTxState.pending,
    this.attempt = 1,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'txId': txId,
    'repoPath': repoPath,
    'branch': branch,
    'headOidAtStart': headOidAtStart,
    'state': state.name,
    'attempt': attempt,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PushTx.fromJson(Map<String, dynamic> json) => PushTx(
    txId: json['txId'],
    repoPath: json['repoPath'],
    branch: json['branch'],
    headOidAtStart: json['headOidAtStart'],
    state: PushTxState.values.firstWhere(
      (e) => e.name == json['state'],
      orElse: () => PushTxState.failed,
    ),
    attempt: json['attempt'] ?? 1,
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

class PushAlreadyRunningException implements Exception {
  final String message;
  PushAlreadyRunningException(this.message);
  @override
  String toString() => message;
}

class GitSyncService {
  static const String _journalFileName = 'git_push_journal.json';
  static final Map<String, bool> _repoBranchLocks = {};

  // For thread-safe journal writes
  static bool _isWritingJournal = false;

  /// Acquires an in-memory lock for the given repo and branch.
  static bool _acquireLock(String repoPath, String branch) {
    final key = '$repoPath|$branch';
    if (_repoBranchLocks[key] == true) {
      return false; // Already locked
    }
    _repoBranchLocks[key] = true;
    return true;
  }

  /// Releases the in-memory lock for the given repo and branch.
  static void _releaseLock(String repoPath, String branch) {
    final key = '$repoPath|$branch';
    _repoBranchLocks[key] = false;
  }

  // ==== Journal Management ====

  static Future<File> _getJournalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_journalFileName');
    if (!await file.exists()) {
      await file.writeAsString(jsonEncode([]));
    }
    return file;
  }

  static Future<List<PushTx>> _readJournal() async {
    try {
      final file = await _getJournalFile();
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((j) => PushTx.fromJson(j)).toList();
    } catch (e) {
      print('Failed to read journal: $e');
      return [];
    }
  }

  static Future<void> _writeJournal(List<PushTx> journal) async {
    while (_isWritingJournal) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isWritingJournal = true;
    try {
      final file = await _getJournalFile();
      final jsonList = journal.map((tx) => tx.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } finally {
      _isWritingJournal = false;
    }
  }

  static Future<void> _upsertTx(PushTx tx) async {
    final journal = await _readJournal();
    final index = journal.indexWhere((t) => t.txId == tx.txId);
    if (index >= 0) {
      journal[index] = tx;
    } else {
      journal.add(tx);
    }
    // Cleanup old DONE/FAILED transactions (keep only pending and recent)
    final now = DateTime.now();
    journal.removeWhere(
      (t) =>
          t.state != PushTxState.pending &&
          now.difference(t.updatedAt).inDays > 7,
    );
    await _writeJournal(journal);
  }

  // ==== Core Logic ====

  static Future<String> _getCurrentBranch(String repoPath) async {
    try {
      final statusJson = await GitService.getRepositoryStatus(repoPath);
      if (statusJson != null) {
        final Map<String, dynamic> status = jsonDecode(statusJson);
        return status['branch'] ?? 'main';
      }
    } catch (_) {}
    return 'main';
  }

  static Future<String?> _getHeadOid(String repoPath) async {
    try {
      // Use log to get the first commit hash
      final logJson = await GitService.getCommitLog(repoPath);
      if (logJson != null) {
        final List<dynamic> commits = jsonDecode(logJson);
        if (commits.isNotEmpty) {
          return commits.first['hash'];
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> _remoteContainsOid(
    String repoPath,
    String branch,
    String oid,
    String token,
  ) async {
    // 1. Fetch the remote
    await GitService.runGitCommand(
      repoPath,
      'fetch origin',
    ); // Or native fetch via bridge if implemented
    // Note: If authentication is required for fetch, we should ideally use a native fetch command passing the token.
    // Assuming runGitCommand handles tokens or the token is cached by the native layer for https.
    // For this simple fallback, we just check via log on the remote tracking branch.

    try {
      final remoteBranchLog = await GitService.runGitCommand(
        repoPath,
        'log origin/$branch --format="%H"',
      );
      if (remoteBranchLog.contains(oid)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Starts the push flow ensuring ACID compliance.
  /// Throws [PushAlreadyRunningException] if already in progress.
  static Future<int> startPush(String repoPath, String token) async {
    final branch = await _getCurrentBranch(repoPath);

    if (!_acquireLock(repoPath, branch)) {
      throw PushAlreadyRunningException('Push already in progress for $branch');
    }

    try {
      final headOid = await _getHeadOid(repoPath);
      if (headOid == null) {
        // Nothing to push or invalid repo
        return -1;
      }

      final tx = PushTx(
        txId: DateTime.now().millisecondsSinceEpoch.toString(),
        repoPath: repoPath,
        branch: branch,
        headOidAtStart: headOid,
        state: PushTxState.pending,
      );

      await _upsertTx(tx);

      // Execute native push
      final pushResultCode = await GitService.pushRepository(repoPath, token);
      final pushSucceeded = (pushResultCode == 0);

      return await _finishOrReconcile(tx, token, pushSucceeded: pushSucceeded)
          ? pushResultCode
          : -1;
    } finally {
      _releaseLock(repoPath, branch);
    }
  }

  /// Finalizes or reconciles a transaction based on the push outcome or startup recovery.
  static Future<bool> _finishOrReconcile(
    PushTx tx,
    String token, {
    bool pushSucceeded = false,
  }) async {
    tx.updatedAt = DateTime.now();

    if (pushSucceeded) {
      tx.state = PushTxState.done;
      await _upsertTx(tx);
      return true;
    }

    // Push failed or timed out. Reconcile by checking ancestry on remote.
    // If we're during startup recovery, we might not have a token.
    if (token.isEmpty) {
      // Need a token to fetch and reconcile accurately. Keep it pending or mark failed.
      // For now, mark failed so user can manually retry with prompt.
      tx.state = PushTxState.failed;
      await _upsertTx(tx);
      return false;
    }

    final containsOid = await _remoteContainsOid(
      tx.repoPath,
      tx.branch,
      tx.headOidAtStart,
      token,
    );

    if (containsOid) {
      // Remote actually received it before we crashed or timed out.
      tx.state = PushTxState.done;
    } else {
      // Push genuinely failed (e.g., auth error, branch diverging).
      tx.state = PushTxState.failed;
      tx.attempt++;
    }

    await _upsertTx(tx);
    return tx.state == PushTxState.done;
  }

  /// Runs on application startup to clean up dangling states.
  static Future<void> recoverPendingTxOnStartup() async {
    final journal = await _readJournal();
    final pendingTxs = journal
        .where((t) => t.state == PushTxState.pending)
        .toList();

    for (var tx in pendingTxs) {
      // We don't have a token at startup without prompting the user.
      // Safest fallback: Mark as failed so the user can see it in the UI and retry manually.
      tx.state = PushTxState.failed;
      tx.updatedAt = DateTime.now();
      await _upsertTx(tx);
    }
  }
}