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
  bool _showBlame = false;
  List<Map<String, dynamic>> _blameData = [];
  bool _isBlameLoading = false;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleBlame() async {
    if (_showBlame) {
      setState(() => _showBlame = false);
      return;
    }

    setState(() {
      _isBlameLoading = true;
      _showBlame = true;
    });

    final data = await GitService.getBlame(widget.repoPath, widget.fileName);
    if (mounted) {
      setState(() {
        _blameData = data;
        _isBlameLoading = false;
      });
    }
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
          IconButton(
            icon: Icon(
              _showBlame ? Icons.person_off_rounded : Icons.person_search_rounded,
              color: _showBlame ? AppTheme.accentCyan : null,
            ),
            tooltip: "Git Blame",
            onPressed: _toggleBlame,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded),
            tooltip: "Save & Commit",
            onPressed: _commitChanges,
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showBlame) _buildBlameGutter(),
          Expanded(
            child: CodeTheme(
              data: CodeThemeData(styles: _getEditorStyles()),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: CodeField(
                  controller: _codeController,
                  textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlameGutter() {
    if (_isBlameLoading) {
      return Container(
        width: 80,
        decoration: const BoxDecoration(
          color: AppTheme.bg1,
          border: Border(right: BorderSide(color: AppTheme.border)),
        ),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return Container(
      width: 100,
      decoration: const BoxDecoration(
        color: AppTheme.bg1,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: ListView.builder(
        controller: _scrollController, // Sync with code field
        padding: const EdgeInsets.only(top: 10), // Match CodeField padding if any
        itemCount: _blameData.length,
        itemBuilder: (context, index) {
          final blame = _blameData[index];
          final author = blame['author'] ?? 'unknown';
          final firstLetter = author.isNotEmpty ? author[0].toUpperCase() : '?';

          return Container(
            height: 19, // Approximation for 13px mono font + line spacing
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  firstLetter,
                  style: TextStyle(
                    color: _getAuthorColor(author),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    author,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getAuthorColor(String name) {
    final colors = [
      AppTheme.accentCyan,
      AppTheme.accentPurple,
      AppTheme.accentOrange,
      AppTheme.accentGreen,
      AppTheme.accentPurple,
    ];
    return colors[name.hashCode % colors.length];
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
