import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class GPGService {
  static const _channel = MethodChannel('git_channel');

  /// Prepares commit content for signing. 
  /// Returns a string representing the commit object data.
  static Future<String> getCommitContent(String repoPath, String message) async {
    try {
      final String? content = await _channel.invokeMethod('getCommitContent', {
        'path': repoPath,
        'message': message,
      });
      return content ?? "";
    } catch (e) {
      return "";
    }
  }

  /// Creates a signed commit given the unsigned content and signature.
  static Future<bool> commitSigned(String repoPath, String content, String signature, String message) async {
    try {
      final int result = await _channel.invokeMethod('commitSigned', {
        'path': repoPath,
        'message': message,
        'signature': signature,
      });
      return result == 0;
    } catch (e) {
      return false;
    }
  }

  static Future<File> _getKeysFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/gpg_keys.json');
  }

  /// Lists available GPG keys in the app sandbox.
  static Future<List<String>> listKeys() async {
    try {
      final file = await _getKeysFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> keys = jsonDecode(content);
      return keys.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Imports a new GPG key.
  static Future<void> importKey(String keyBlock) async {
    try {
      final file = await _getKeysFile();
      List<String> keys = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        keys = jsonDecode(content).cast<String>();
      }
      
      // Basic validation
      if (!keyBlock.contains('BEGIN PGP PRIVATE KEY BLOCK')) {
        throw Exception("Invalid PGP Private Key block");
      }

      // Extract a mock label/email from the block for display
      final emailMatch = RegExp(r'<(.+@.+)>').firstMatch(keyBlock);
      final label = emailMatch != null ? emailMatch.group(1)! : "Imported GPG Key ${DateTime.now().toLocal().toString().split('.')[0]}";
      
      if (!keys.contains(label)) {
        keys.add(label);
        await file.writeAsString(jsonEncode(keys));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a GPG key.
  static Future<void> deleteKey(String label) async {
    try {
      final file = await _getKeysFile();
      if (!await file.exists()) return;
      final content = await file.readAsString();
      List<String> keys = jsonDecode(content).cast<String>();
      keys.remove(label);
      await file.writeAsString(jsonEncode(keys));
    } catch (e) {
      // Ignore
    }
  }
}
