import 'package:flutter/services.dart';

class GitService {
  static const _channel = MethodChannel('git_channel');

  /// Initializes a new Git repository at the given [path].
  static Future<int> initRepository(String path) async {
    try {
      final int result = await _channel.invokeMethod('initRepository', {'path': path});
      return result;
    } on PlatformException catch (e) {
      print("Failed to init repository: '${e.message}'.");
      return -1;
    }
  }

  /// Returns the commit log for the repository at [path].
  static Future<String?> getCommitLog(String path) async {
    try {
      final String? result = await _channel.invokeMethod('getCommitLog', {'path': path});
      return result;
    } on PlatformException catch (e) {
      print("Failed to get commit log: '${e.message}'.");
      return null;
    }
  }

  /// Returns the repository status at [path].
  static Future<String?> getRepositoryStatus(String path) async {
    try {
      final String? result = await _channel.invokeMethod('getRepositoryStatus', {'path': path});
      return result;
    } on PlatformException catch (e) {
      print("Failed to get repo status: '${e.message}'.");
      return null;
    }
  }

  /// Returns the diff for a specific commit hash.
  static Future<String?> getCommitDiff(String path, String hash) async {
    try {
      final String? result = await _channel.invokeMethod('getCommitDiff', {'path': path, 'hash': hash});
      return result;
    } on PlatformException catch (e) {
      print("Failed to get commit diff: '${e.message}'.");
      return null;
    }
  }
}
