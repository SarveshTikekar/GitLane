import 'package:flutter/services.dart';
import 'dart:convert';

class SSHKey {
  final String label;
  final DateTime created;
  final String type;

  SSHKey({required this.label, required this.created, required this.type});

  factory SSHKey.fromJson(Map<String, dynamic> json) {
    return SSHKey(
      label: json['label'],
      created: DateTime.fromMillisecondsSinceEpoch(json['created']),
      type: json['type'],
    );
  }
}

class SSHService {
  static const _channel = MethodChannel('git_channel');

  /// Generates a new SSH key pair.
  /// Returns the public key in OpenSSH format if successful.
  static Future<String> generateKey(String label, {String type = "RSA", int bits = 2048}) async {
    try {
      final String result = await _channel.invokeMethod('generateSSHKey', {
        'label': label,
        'type': type,
        'bits': bits,
      });
      return result;
    } catch (e) {
      return "ERROR: $e";
    }
  }

  /// Lists all stored SSH public keys.
  static Future<List<SSHKey>> listKeys() async {
    try {
      final String result = await _channel.invokeMethod('listSSHKeys');
      final List<dynamic> list = jsonDecode(result);
      return list.map((e) => SSHKey.fromJson(e)).toList();
    } catch (e) {
      print("SSH list error: $e");
      return [];
    }
  }

  /// Returns the public key in OpenSSH format for a given label.
  static Future<String> getPublicKey(String label) async {
    try {
      final String result = await _channel.invokeMethod('getSSHPublicKey', {'label': label});
      return result;
    } catch (e) {
      return "ERROR: $e";
    }
  }

  /// Deletes an SSH key pair.
  static Future<bool> deleteKey(String label) async {
    try {
      final bool result = await _channel.invokeMethod('deleteSSHKey', {'label': label});
      return result;
    } catch (e) {
      return false;
    }
  }
}
