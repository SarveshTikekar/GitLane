import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/cpp.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import '../../../services/indexer_service.dart';

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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentCyan,
              ),
              child: const Text("Commit", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final msg =
            commitController.text.trim().isEmpty
                ? "Update ${widget.fileName}"
                : commitController.text;
        await GitService.commitAll(widget.repoPath, msg);
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  void _handleSymbolInteraction() {
    final selection = _codeController.selection;
    if (selection.isCollapsed && selection.baseOffset < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Place cursor on a symbol or select text")),
      );
      return;
    }

    String? symbol;
    if (!selection.isCollapsed) {
      symbol = _codeController.text.substring(selection.start, selection.end);
    } else {
      final text = _codeController.text;
      final offset = selection.baseOffset;
      symbol = IndexerService.getSymbolAt(text, offset);
    }

    if (symbol == null || symbol.isEmpty) return;

    final loc = IndexerService.findSymbol(symbol);
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Definition not found for '$symbol'")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: context.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.code_rounded,
                  color: context.accentCyan,
                ),
                title: Text(
                  "Go to Definition: $symbol",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  loc.path.split(Platform.pathSeparator).last,
                  style: TextStyle(color: context.textMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (loc.path == widget.filePath) {
                    _codeController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _getOffsetForLine(loc.line)),
                    );
                    _scrollController.animateTo(
                      (loc.line - 1) * 19.0, // Rough estimation of line height
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => FileEditorScreen(
                              filePath: loc.path,
                              fileName:
                                  loc.path.split(Platform.pathSeparator).last,
                              repoPath: widget.repoPath,
                            ),
                      ),
                    );
                  }
                },
              ),
              if (loc.documentation != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSlate,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.border),
                    ),
                    child: Text(
                      loc.documentation!,
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  int _getOffsetForLine(int line) {
    if (line <= 1) return 0;
    final text = _codeController.text;
    final lines = text.split('\n');
    int offset = 0;
    for (int i = 0; i < line - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    return offset;
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
              color: _showBlame ? context.accentCyan : null,
            ),
            tooltip: "Git Blame",
            onPressed: _toggleBlame,
          ),
          IconButton(
            icon: Icon(Icons.bolt_rounded, color: context.accentOrange),
            tooltip: "LSP Code Intel",
            onPressed: _handleSymbolInteraction,
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
        decoration: BoxDecoration(
          color: context.bg1,
          border: Border(right: BorderSide(color: context.border)),
        ),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: context.bg1,
        border: Border(right: BorderSide(color: context.border)),
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
                    style: TextStyle(color: context.textMuted, fontSize: 10),
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
      context.accentCyan,
      context.accentPurple,
      context.accentOrange,
      context.accentGreen,
      context.accentPurple,
    ];
    return colors[name.hashCode % colors.length];
  }

  Map<String, TextStyle> _getEditorStyles() {
    return {
      'root': TextStyle(backgroundColor: AppTheme.backgroundBlack, color: AppTheme.textLight),
      'keyword': const TextStyle(color: Color(0xFFC678DD)),
      'string': const TextStyle(color: Color(0xFF98C379)),
      'comment': const TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic),
      'function': const TextStyle(color: Color(0xFF61AFEF)),
      'number': const TextStyle(color: Color(0xFFD19A66)),
    };
  }
}