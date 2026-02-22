import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/git_service.dart';
import '../../theme/app_theme.dart';

class HunkStagingScreen extends StatefulWidget {
  final String repoPath;
  final String filePath;
  final String fileName;

  const HunkStagingScreen({
    super.key,
    required this.repoPath,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<HunkStagingScreen> createState() => _HunkStagingScreenState();
}

class _HunkStagingScreenState extends State<HunkStagingScreen> {
  List<Map<String, dynamic>> _hunks = [];
  bool _isLoading = true;
  final Map<int, Set<int>> _selectedLines = {}; // hunkIndex -> set of lineIndexes

  @override
  void initState() {
    super.initState();
    _loadHunks();
  }

  Future<void> _loadHunks() async {
    setState(() => _isLoading = true);
    final data = await GitService.getDiffHunks(widget.repoPath, widget.fileName);
    setState(() {
      _hunks = data;
      _isLoading = false;
    });
  }

  void _toggleLine(int hunkIdx, int lineIdx) {
    setState(() {
      final set = _selectedLines.putIfAbsent(hunkIdx, () => {});
      if (set.contains(lineIdx)) {
        set.remove(lineIdx);
      } else {
        set.add(lineIdx);
      }
    });
  }

  Future<void> _stageSelected() async {
    if (_selectedLines.isEmpty || _selectedLines.values.every((s) => s.isEmpty)) {
      _showSnack("No lines selected", context.accentOrange);
      return;
    }

    // Generate Patch
    StringBuffer patch = StringBuffer();
    patch.writeln("diff --git a/${widget.fileName} b/${widget.fileName}");
    patch.writeln("--- a/${widget.fileName}");
    patch.writeln("+++ b/${widget.fileName}");

    bool hasAnyHunk = false;
    for (int i = 0; i < _hunks.length; i++) {
      final hunk = _hunks[i];
      final lines = hunk['lines'] as List;
      final selected = _selectedLines[i] ?? {};

      if (selected.isEmpty) continue;
      hasAnyHunk = true;

      patch.writeln(hunk['header']);
      for (int j = 0; j < lines.length; j++) {
        final line = lines[j];
        final type = line['type'] as String;
        final content = line['content'] as String;
        final isSelected = selected.contains(j);

        if (type == ' ') {
          patch.writeln(" $content");
        } else if (type == '-') {
          if (isSelected) {
            patch.writeln("-$content");
          } else {
            patch.writeln(" $content"); // Treat as context
          }
        } else if (type == '+') {
          if (isSelected) {
            patch.writeln("+$content");
          }
          // Discard unselected added lines
        }
      }
    }

    if (!hasAnyHunk) return;

    final res = await GitService.applyPatchToIndex(widget.repoPath, patch.toString());
    if (mounted) {
      if (res == 0) {
        _showSnack("✓ Partial changes staged", context.accentGreen);
        Navigator.pop(context, true);
      } else {
        _showSnack("Failed to stage: $res", context.accentRed);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Partial Staging"),
        actions: [
          IconButton(
            icon: Icon(Icons.playlist_add_check_rounded, color: context.accentCyan),
            onPressed: _stageSelected,
            tooltip: "Stage Selection",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hunks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hunks.length,
                  itemBuilder: (context, hIdx) => _buildHunkCard(hIdx),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 48, color: context.textMuted),
          const SizedBox(height: 16),
          Text("No unstaged changes found", style: GoogleFonts.inter(color: context.textMuted)),
        ],
      ),
    );
  }

  Widget _buildHunkCard(int hunkIdx) {
    final hunk = _hunks[hunkIdx];
    final lines = hunk['lines'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSlate.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              hunk['header'],
              style: GoogleFonts.firaMono(color: context.textMuted, fontSize: 11),
            ),
          ),
          ...List.generate(lines.length, (lIdx) {
            final line = lines[lIdx];
            final type = line['type'] as String;
            final content = line['content'] as String;
            final isSelectable = type != ' ';
            final isSelected = _selectedLines[hunkIdx]?.contains(lIdx) ?? false;

            Color bgColor = Colors.transparent;
            if (type == '+') bgColor = context.accentGreen.withValues(alpha: isSelected ? 0.15 : 0.05);
            if (type == '-') bgColor = context.accentRed.withValues(alpha: isSelected ? 0.15 : 0.05);

            return InkWell(
              onTap: isSelectable ? () => _toggleLine(hunkIdx, lIdx) : null,
              child: Container(
                color: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        type,
                        style: TextStyle(
                          color: type == '+' ? context.accentGreen : (type == '-' ? context.accentRed : context.textMuted),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        content,
                        style: GoogleFonts.firaMono(
                          color: isSelectable ? (isSelected ? context.textPrimary : context.textSecondary) : context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isSelectable)
                      Icon(
                        isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: isSelected ? context.accentCyan : context.textMuted.withValues(alpha: 0.3),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}