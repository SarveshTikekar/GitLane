import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  String? token; // stored so we can retry without prompting

  PushTx({
    required this.txId,
    required this.repoPath,
    required this.branch,
    required this.headOidAtStart,
    this.state = PushTxState.pending,
    this.attempt = 1,
    DateTime? updatedAt,
    this.token,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'txId': txId,
    'repoPath': repoPath,
    'branch': branch,
    'headOidAtStart': headOidAtStart,
    'state': state.name,
    'attempt': attempt,
    'updatedAt': updatedAt.toIso8601String(),
    'token': token,
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
    token: json['token'],
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
  static bool _isWritingJournal = false;

  // ── Connectivity watcher ────────────────────────────────────────────────────
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Notifier that emits the count of pending/failed transactions.
  /// Listen to this in UI to show a sync-pending badge.
  static final StreamController<int> pendingCountStream =
      StreamController<int>.broadcast();

  /// Start watching network changes. Call once from `main()`.
  static void startConnectivityWatcher() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final hasNetwork = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasNetwork) {
        await _retryPendingPushes();
      }
    });
  }

  static void stopConnectivityWatcher() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ── Retry pending pushes ───────────────────────────────────────────────────

  static Future<void> _retryPendingPushes() async {
    final journal = await _readJournal();
    final retryable = journal
        .where(
          (t) =>
              (t.state == PushTxState.pending ||
                  t.state == PushTxState.failed) &&
              t.token != null &&
              t.token!.isNotEmpty,
        )
        .toList();

    if (retryable.isEmpty) return;

    for (final tx in retryable) {
      // Exponential backoff: wait 2^attempt seconds before retrying (max 64s)
      final backoff = Duration(seconds: (1 << tx.attempt.clamp(0, 6)));
      await Future.delayed(backoff);

      if (!_acquireLock(tx.repoPath, tx.branch)) continue;

      try {
        final code = await GitService.pushRepository(tx.repoPath, tx.token!);
        tx.attempt++;
        await _finishOrReconcile(tx, tx.token!, pushSucceeded: code == 0);
      } finally {
        _releaseLock(tx.repoPath, tx.branch);
      }
    }

    // Update UI badge
    await _emitPendingCount();
  }

  static Future<void> _emitPendingCount() async {
    final journal = await _readJournal();
    final count = journal
        .where(
          (t) =>
              t.state == PushTxState.pending || t.state == PushTxState.failed,
        )
        .length;
    pendingCountStream.add(count);
  }

  // ── Lock management ────────────────────────────────────────────────────────

  static bool _acquireLock(String repoPath, String branch) {
    final key = '$repoPath|$branch';
    if (_repoBranchLocks[key] == true) return false;
    _repoBranchLocks[key] = true;
    return true;
  }

  static void _releaseLock(String repoPath, String branch) {
    _repoBranchLocks['$repoPath|$branch'] = false;
  }

  // ── Journal management ─────────────────────────────────────────────────────

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
    } catch (_) {
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
      await file.writeAsString(jsonEncode(journal.map((t) => t.toJson()).toList()));
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
    // Prune old completed/failed entries older than 7 days
    final now = DateTime.now();
    journal.removeWhere(
      (t) =>
          t.state != PushTxState.pending &&
          now.difference(t.updatedAt).inDays > 7,
    );
    await _writeJournal(journal);
    await _emitPendingCount();
  }

  // ── Core push logic ────────────────────────────────────────────────────────

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
      final logJson = await GitService.getCommitLog(repoPath);
      if (logJson != null) {
        final List<dynamic> commits = jsonDecode(logJson);
        if (commits.isNotEmpty) return commits.first['hash'];
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
    await GitService.runGitCommand(repoPath, 'fetch origin');
    try {
      final log = await GitService.runGitCommand(
        repoPath,
        'log origin/$branch --format="%H"',
      );
      return log.contains(oid);
    } catch (_) {}
    return false;
  }

  /// Initiates a push, stores a journal entry, and sets up auto-retry if it fails.
  static Future<int> startPush(String repoPath, String token) async {
    final branch = await _getCurrentBranch(repoPath);

    if (!_acquireLock(repoPath, branch)) {
      throw PushAlreadyRunningException(
        'Push already in progress for $branch',
      );
    }

    try {
      final headOid = await _getHeadOid(repoPath);
      if (headOid == null) return -1;

      final tx = PushTx(
        txId: DateTime.now().millisecondsSinceEpoch.toString(),
        repoPath: repoPath,
        branch: branch,
        headOidAtStart: headOid,
        state: PushTxState.pending,
        token: token, // persisted for auto-retry
      );

      await _upsertTx(tx);

      final code = await GitService.pushRepository(repoPath, token);
      final succeeded = (code == 0);

      return await _finishOrReconcile(tx, token, pushSucceeded: succeeded)
          ? code
          : -1;
    } finally {
      _releaseLock(repoPath, branch);
    }
  }

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

    if (token.isEmpty) {
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

    tx.state = containsOid ? PushTxState.done : PushTxState.failed;
    if (!containsOid) tx.attempt++;

    await _upsertTx(tx);
    return tx.state == PushTxState.done;
  }

  /// Runs on startup — keeps pending txs as pending so connectivity watcher can retry them.
  static Future<void> recoverPendingTxOnStartup() async {
    // Start the watcher immediately — it will retry any pending/failed txs
    // as soon as the network becomes available.
    startConnectivityWatcher();
    await _emitPendingCount();
  }

  /// Returns the current count of pending/failed pushes (for UI badges).
  static Future<int> getPendingCount() async {
    final journal = await _readJournal();
    return journal
        .where(
          (t) =>
              t.state == PushTxState.pending || t.state == PushTxState.failed,
        )
        .length;
  }
}