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
      final String? result = await _channel.invokeMethod('getCommitDiff', {
        'path': path,
        'commitHash': hash, // Fixed: Kotlin expects 'commitHash'
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to get commit diff: '${e.message}'.");
      return null;
    }
  }

  /// Stages all changes and creates a commit.
  static Future<int> commitAll(String path, String message) async {
    try {
      return await _channel.invokeMethod('commitAll', {'path': path, 'message': message});
    } on PlatformException catch (e) {
      print("Failed to commitall: '${e.message}'.");
      return -1;
    }
  }

  /// Creates a new branch.
  static Future<int> createBranch(String path, String branchName) async {
    try {
      return await _channel.invokeMethod('createBranch', {'path': path, 'branchName': branchName});
    } on PlatformException catch (e) {
      print("Failed to create branch: '${e.message}'.");
      return -1;
    }
  }

  /// Checks out a branch.
  static Future<int> checkoutBranch(String path, String branchName) async {
    try {
      return await _channel.invokeMethod('checkoutBranch', {'path': path, 'branchName': branchName});
    } on PlatformException catch (e) {
      print("Failed to checkout branch: '${e.message}'.");
      return -1;
    }
  }

  /// Merges a branch.
  static Future<int> mergeBranch(String path, String branchName) async {
    try {
      return await _channel.invokeMethod('mergeBranch', {'path': path, 'branchName': branchName});
    } on PlatformException catch (e) {
      print("Failed to merge branch: '${e.message}'.");
      return -1;
    }
  }

  /// Adds a specific file to index.
  static Future<int> gitAddFile(String path, String filePath) async {
    try {
      return await _channel.invokeMethod('gitAddFile', {'path': path, 'filePath': filePath});
    } on PlatformException catch (e) {
      print("Failed to add file: '${e.message}'.");
      return -1;
    }
  }

  /// Clones a repository.
  static Future<int> cloneRepository(String url, String path) async {
    try {
      return await _channel.invokeMethod('cloneRepository', {'url': url, 'path': path});
    } on PlatformException catch (e) {
      print("Failed to clone: '${e.message}'.");
      return -1;
    }
  }

  /// Returns a list of local branches.
  static Future<List<String>> getBranches(String path) async {
    try {
      final String? json = await _channel.invokeMethod('getBranches', {'path': path});
      if (json == null) return [];
      // Basic JSON parsing as a simple workaround for now
      final String content = json.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      if (content.isEmpty) return [];
      return content.split(',').map((e) => e.trim()).toList();
    } on PlatformException catch (e) {
      print("Failed to get branches: '${e.message}'.");
      return [];
    }
  }

  /// Returns the current branch name.
  static Future<String> getCurrentBranch(String path) async {
    try {
      return await _channel.invokeMethod('getCurrentBranch', {'path': path});
    } on PlatformException catch (e) {
      print("Failed to get current branch: '${e.message}'.");
      return 'HEAD';
    }
  }

  /// Returns a list of filenames with active conflicts.
  static Future<List<String>> getConflicts(String path) async {
    try {
      final String? json = await _channel.invokeMethod('getConflicts', {'path': path});
      if (json == null) return [];
      final String content = json.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      if (content.isEmpty) return [];
      return content.split(',').map((e) => e.trim()).toList();
    } on PlatformException catch (e) {
      print("Failed to get conflicts: '${e.message}'.");
      return [];
    }
  }

  /// Deletes a local branch.
  static Future<int> deleteBranch(String path, String branchName) async {
    try {
      return await _channel.invokeMethod('deleteBranch', {'path': path, 'branchName': branchName});
    } on PlatformException catch (e) {
      print("Failed to delete branch: '${e.message}'.");
      return -1;
    }
  }
}
