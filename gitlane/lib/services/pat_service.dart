import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PATService {
  static Future<File> _getFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/gitlane_pats.json');
  }

  static Future<List<Map<String, dynamic>>> getTokens() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(content);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _saveTokens(List<Map<String, dynamic>> tokens) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(tokens));
  }

  /// Cleans up expired tokens based on their added date and expiresInDays.
  static Future<void> cleanupExpiredTokens() async {
    final tokens = await getTokens();
    if (tokens.isEmpty) return;

    final now = DateTime.now();
    final validTokens = tokens.where((t) {
      final addedAt = DateTime.parse(t['addedAt']);
      final expiresDays = t['expiresInDays'] as int;
      final expiryDate = addedAt.add(Duration(days: expiresDays));
      return now.isBefore(expiryDate);
    }).toList();

    if (validTokens.length != tokens.length) {
      // If the active token expired, we should deactivate all for safety (or keep the first valid one active)
      bool activeStillExists = validTokens.any((t) => t['isActive'] == true);
      if (!activeStillExists && validTokens.isNotEmpty) {
        validTokens.first['isActive'] = true;
      }
      await _saveTokens(validTokens);
    }
  }

  /// Adds a new PAT. If it's the first one, it becomes active.
  static Future<void> addToken(String label, String token, int expiresInDays) async {
    await cleanupExpiredTokens();
    
    final tokens = await getTokens();
    
    // Auto active if it's the first token
    final isActive = tokens.isEmpty;

    tokens.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'label': label,
      'token': token,
      'addedAt': DateTime.now().toIso8601String(),
      'expiresInDays': expiresInDays,
      'isActive': isActive,
    });

    await _saveTokens(tokens);
  }

  /// Sets a specific token as active by ID.
  static Future<void> setActiveToken(String id) async {
    await cleanupExpiredTokens();
    final tokens = await getTokens();
    
    for (var t in tokens) {
      t['isActive'] = (t['id'] == id);
    }
    
    await _saveTokens(tokens);
  }

  /// Deletes a specific token by ID.
  static Future<void> deleteToken(String id) async {
    final tokens = await getTokens();
    final tokenToRemove = tokens.firstWhere((t) => t['id'] == id, orElse: () => {});
    
    if (tokenToRemove.isNotEmpty) {
      tokens.removeWhere((t) => t['id'] == id);
      
      // If we deleted the active token, make the first one active if available
      if (tokenToRemove['isActive'] == true && tokens.isNotEmpty) {
        tokens.first['isActive'] = true;
      }
      
      await _saveTokens(tokens);
    }
  }

  /// Returns the current active token string, or null if none.
  static Future<String?> getActiveTokenString() async {
    await cleanupExpiredTokens();
    final tokens = await getTokens();
    final active = tokens.firstWhere((t) => t['isActive'] == true, orElse: () => {});
    return active.isNotEmpty ? active['token'] as String : null;
  }
}
