import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/cpp.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';

class FileEditorScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String repoPath;

  const FileEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.repoPath,
  });

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> {
  late CodeController _codeController;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final content = File(widget.filePath).readAsStringSync();
    _codeController = CodeController(
      text: content,
      language: _getLanguage(widget.fileName),
    );
    _codeController.addListener(() {
      if (!_isDirty) setState(() => _isDirty = true);
    });
  }

  dynamic _getLanguage(String fileName) {
    if (fileName.endsWith('.dart')) return dart;
    if (fileName.endsWith('.py')) return python;
    if (fileName.endsWith('.js')) return javascript;
    if (fileName.endsWith('.cpp') || fileName.endsWith('.c') || fileName.endsWith('.h')) return cpp;
    return null;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _saveFile() async {
    try {
      await File(widget.filePath).writeAsString(_codeController.text);
      setState(() => _isDirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File saved successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    }
  }

  Future<void> _commitChanges() async {
    await _saveFile();
    final commitController = TextEditingController();
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceSlate,
          title: const Text("Commit Changes"),
          content: TextField(
            controller: commitController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: "Enter commit message"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
              child: const Text("Commit", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final msg = commitController.text.trim().isEmpty ? "Update ${widget.fileName}" : commitController.text;
        await GitService.commitAll(widget.repoPath, msg);
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          if (_isDirty)
            IconButton(
              icon: const Icon(Icons.save_rounded, color: AppTheme.accentCyan),
              onPressed: _saveFile,
            ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded),
            tooltip: "Save & Commit",
            onPressed: _commitChanges,
          ),
        ],
      ),
      body: CodeTheme(
        data: CodeThemeData(styles: _getEditorStyles()),
        child: SingleChildScrollView(
          child: CodeField(
            controller: _codeController,
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
      ),
    );
  }

  Map<String, TextStyle> _getEditorStyles() {
    return {
      'root': const TextStyle(backgroundColor: AppTheme.backgroundBlack, color: AppTheme.textLight),
      'keyword': const TextStyle(color: Color(0xFFC678DD)),
      'string': const TextStyle(color: Color(0xFF98C379)),
      'comment': const TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic),
      'function': const TextStyle(color: Color(0xFF61AFEF)),
      'number': const TextStyle(color: Color(0xFFD19A66)),
    };
  }
}
