import 'package:flutter/services.dart';
import 'dart:convert';

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

  /// Saves current changes to the stash.
  static Future<int> stashSave(String path, String message) async {
    try {
      return await _channel.invokeMethod('stashSave', {'path': path, 'message': message});
    } on PlatformException catch (e) {
      print("Failed to stash save: '${e.message}'.");
      return -1;
    }
  }

  /// Pops a stash from the stack.
  static Future<int> stashPop(String path, int index) async {
    try {
      return await _channel.invokeMethod('stashPop', {'path': path, 'index': index});
    } on PlatformException catch (e) {
      print("Failed to stash pop: '${e.message}'.");
      return -1;
    }
  }

  /// Applies a stash without removing it from the stack.
  static Future<int> stashApply(String path, int index) async {
    try {
      return await _channel.invokeMethod('stashApply', {'path': path, 'index': index});
    } on PlatformException catch (e) {
      print("Failed to stash apply: '${e.message}'.");
      return -1;
    }
  }

  /// Drops a stash from the stack.
  static Future<int> stashDrop(String path, int index) async {
    try {
      return await _channel.invokeMethod('stashDrop', {'path': path, 'index': index});
    } on PlatformException catch (e) {
      print("Failed to stash drop: '${e.message}'.");
      return -1;
    }
  }

  /// Returns a list of stashes.
  static Future<List<Map<String, dynamic>>> getStashes(String path) async {
    try {
      final String? jsonVal = await _channel.invokeMethod('getStashes', {'path': path});
      if (jsonVal == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(jsonVal));
    } on PlatformException catch (e) {
      print("Failed to get stashes: '${e.message}'.");
      return [];
    }
  }

  /// Pushes changes to the remote repository.
  static Future<int> pushRepository(String path, String token) async {
    try {
      return await _channel.invokeMethod('pushRepository', {'path': path, 'token': token});
    } on PlatformException catch (e) {
      print("Failed to push: '${e.message}'.");
      return -1;
    }
  }

  /// Pulls changes from the remote repository.
  static Future<int> pullRepository(String path, String token) async {
    try {
      return await _channel.invokeMethod('pullRepository', {'path': path, 'token': token});
    } on PlatformException catch (e) {
      print("Failed to pull: '${e.message}'.");
      return -1;
    }
  }

  static Future<String> getRemoteUrl(String path) async {
    try {
      return await _channel.invokeMethod('getRemoteUrl', {'path': path});
    } on PlatformException catch (e) {
      print("Failed to get remote URL: '${e.message}'.");
      return "";
    }
  }

  static Future<String> getReflog(String path) async {
    try {
      return await _channel.invokeMethod('getReflog', {'path': path});
    } on PlatformException catch (e) {
      print("Failed to get reflog: '${e.message}'.");
      return "[]";
    }
  }

  static Future<Map<String, dynamic>> getSyncStatus(String path) async {
    try {
      final jsonStr = await _channel.invokeMethod('getSyncStatus', {'path': path});
      return Map<String, dynamic>.from(json.decode(jsonStr));
    } on PlatformException catch (e) {
      print("Failed to get sync status: '${e.message}'.");
      return {"ahead": 0, "behind": 0};
    }
  }

  static Future<List<Map<String, dynamic>>> getConflictChunks(String path, String filePath) async {
    try {
      final jsonStr = await _channel.invokeMethod('getConflictChunks', {'path': path, 'filePath': filePath});
      return List<Map<String, dynamic>>.from(json.decode(jsonStr));
    } on PlatformException catch (e) {
      print("Failed to get conflict chunks: '${e.message}'.");
      return [];
    }
  }

  static Future<int> resolveConflict(String path, String filePath, String content) async {
    try {
      return await _channel.invokeMethod('resolveConflict', {'path': path, 'filePath': filePath, 'content': content});
    } on PlatformException catch (e) {
      print("Failed to resolve conflict: '${e.message}'.");
      return -1;
    }
  }

  static Future<String> runGitCommand(String path, String command) async {
    try {
      return await _channel.invokeMethod('runGitCommand', {'path': path, 'command': command});
    } on PlatformException catch (e) {
      print("Failed to run git command: '${e.message}'.");
      return "Error: ${e.message}";
    }
  }

  /// Returns a list of tags (name and target hash).
  static Future<List<Map<String, dynamic>>> getTags(String path) async {
    try {
      final String? json = await _channel.invokeMethod('getTags', {'path': path});
      if (json == null) return [];
      final dynamic decoded = jsonDecode(json);
      if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
      return [];
    } on PlatformException catch (e) {
      print("Failed to get tags: '${e.message}'.");
      return [];
    }
  }

  /// Creates a new tag.
  static Future<int> createTag(String path, String tagName, String targetHash) async {
    try {
      return await _channel.invokeMethod('createTag', {
        'path': path,
        'tagName': tagName,
        'targetHash': targetHash,
      });
    } on PlatformException catch (e) {
      print("Failed to create tag: '${e.message}'.");
      return -1;
    }
  }

  /// Deletes a tag.
  static Future<int> deleteTag(String path, String tagName) async {
    try {
      return await _channel.invokeMethod('deleteTag', {
        'path': path,
        'tagName': tagName,
      });
    } on PlatformException catch (e) {
      print("Failed to delete tag: '${e.message}'.");
      return -1;
    }
  }

  /// Returns a list of remotes.
  static Future<List<Map<String, dynamic>>> getRemotes(String path) async {
    try {
      final String? jsonVal = await _channel.invokeMethod('getRemotes', {'path': path});
      if (jsonVal == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(jsonVal));
    } on PlatformException catch (e) {
      print("Failed to get remotes: '${e.message}'.");
      return [];
    }
  }

  /// Adds a new remote.
  static Future<int> addRemote(String path, String name, String url) async {
    try {
      return await _channel.invokeMethod('addRemote', {
        'path': path,
        'name': name,
        'url': url,
      });
    } on PlatformException catch (e) {
      print("Failed to add remote: '${e.message}'.");
      return -1;
    }
  }

  /// Deletes a remote.
  static Future<int> deleteRemote(String path, String name) async {
    try {
      return await _channel.invokeMethod('deleteRemote', {
        'path': path,
        'name': name,
      });
    } on PlatformException catch (e) {
      print("Failed to delete remote: '${e.message}'.");
      return -1;
    }
  }

  /// Sets the URL for a remote.
  static Future<int> setRemoteUrl(String path, String name, String url) async {
    try {
      return await _channel.invokeMethod('setRemoteUrl', {
        'path': path,
        'name': name,
        'url': url,
      });
    } on PlatformException catch (e) {
      print("Failed to set remote URL: '${e.message}'.");
      return -1;
    }
  }

  /// Returns blame info for a file.
  static Future<List<Map<String, dynamic>>> getBlame(String path, String filePath) async {
    try {
      final String? jsonVal = await _channel.invokeMethod('getBlame', {
        'path': path,
        'filePath': filePath,
      });
      if (jsonVal == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(jsonVal));
    } on PlatformException catch (e) {
      print("Failed to get blame: '${e.message}'.");
      return [];
    }
  }

  /// Returns structural diff hunks for a file.
  static Future<List<Map<String, dynamic>>> getDiffHunks(String path, String filePath) async {
    try {
      final String? jsonVal = await _channel.invokeMethod('getDiffHunks', {
        'path': path,
        'filePath': filePath,
      });
      if (jsonVal == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(jsonVal));
    } on PlatformException catch (e) {
      print("Failed to get diff hunks: '${e.message}'.");
      return [];
    }
  }

  /// Applies a patch to the repository index.
  static Future<int> applyPatchToIndex(String path, String patch) async {
    try {
      return await _channel.invokeMethod('applyPatchToIndex', {
        'path': path,
        'patch': patch,
      });
    } on PlatformException catch (e) {
      print("Failed to apply patch to index: '${e.message}'.");
      return -1;
    }
  }
}
