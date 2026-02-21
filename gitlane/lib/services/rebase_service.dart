import 'package:flutter/services.dart';
import 'dart:convert';

enum RebaseOperationType {
  pick,
  reword,
  edit,
  squash,
  fixup,
  exec
}

class RebaseOp {
  final int type;
  final String hash;
  
  RebaseOp({required this.type, required this.hash});
  
  factory RebaseOp.fromJson(Map<String, dynamic> json) {
    return RebaseOp(
      type: json['type'] ?? 0,
      hash: json['hash'] ?? '',
    );
  }
}

class RebaseService {
  static const _channel = MethodChannel('git_channel');

  /// Starts a rebase operation.
  static Future<int> init(String repoPath, String upstream, String onto) async {
    try {
      final int result = await _channel.invokeMethod('rebaseInit', {
        'path': repoPath,
        'upstream': upstream,
        'onto': onto,
      });
      return result;
    } catch (e) {
      return -1;
    }
  }

  /// Gets the next operation in the rebase.
  static Future<Map<String, dynamic>> next(String repoPath) async {
    try {
      final String result = await _channel.invokeMethod('rebaseNext', {'path': repoPath});
      return jsonDecode(result);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Commits the current rebase operation.
  static Future<int> commit(String repoPath, String message, {String name = "User", String email = "user@example.com"}) async {
    try {
      return await _channel.invokeMethod('rebaseCommit', {
        'path': repoPath,
        'authorName': name,
        'authorEmail': email,
        'message': message,
      });
    } catch (e) {
      return -1;
    }
  }

  /// Aborts the rebase.
  static Future<int> abort(String repoPath) async {
    try {
      return await _channel.invokeMethod('rebaseAbort', {'path': repoPath});
    } catch (e) {
      return -1;
    }
  }

  /// Finishes the rebase.
  static Future<int> finish(String repoPath) async {
    try {
      return await _channel.invokeMethod('rebaseFinish', {'path': repoPath});
    } catch (e) {
      return -1;
    }
  }
}
