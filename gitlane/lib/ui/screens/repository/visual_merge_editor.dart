import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/indexer_service.dart';

class VisualMergeEditor extends StatefulWidget {
  final String repoPath;
  final String filePath;

  VisualMergeEditor({
    super.key,
    required this.repoPath,
    required this.filePath,
  });

  @override
  State<VisualMergeEditor> createState() => _VisualMergeEditorState();
}

class _VisualMergeEditorState extends State<VisualMergeEditor> {
  List<Map<String, dynamic>> _chunks = [];
  Map<int, String> _selections = {}; // index -> 'local', 'remote', or 'both'
  bool _isLoading = true;
  int _currentConflictIndex = 0;
  final ScrollController _mineScroll = ScrollController();
  final ScrollController _theirsScroll = ScrollController();
  final ScrollController _resultScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    setState(() => _isLoading = true);
    final chunks = await GitService.getConflictChunks(widget.repoPath, widget.filePath);
    setState(() {
      _chunks = chunks;
      _isLoading = false;
    });
  }

  Future<void> _applyResolution() async {
    if (_selections.length < _chunks.where((c) => c['local'] != c['remote']).length) {
      // Basic check for conflicts (where local != remote)
    }

    String finalContent = "";
    for (int i = 0; i < _chunks.length; i++) {
        final selection = _selections[i];
        if (selection == 'local') {
          finalContent += _chunks[i]['local'] + "\n";
        } else if (selection == 'remote') {
          finalContent += _chunks[i]['remote'] + "\n";
        } else if (selection == 'both') {
          finalContent += _chunks[i]['local'] + "\n" + _chunks[i]['remote'] + "\n";
        } else {
          // Default to local if no conflict, or local if unselected
          finalContent += _chunks[i]['local'] + "\n";
        }
    }

    final result = await GitService.resolveConflict(widget.repoPath, widget.filePath, finalContent);
    if (result == 0) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to resolve: code $result")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppTheme.accentGreen),
            tooltip: "Apply Resolution",
            onPressed: _applyResolution,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : Column(
              children: [
                _buildConflictNavigator(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSourcePane("YOURS", 'local', AppTheme.accentCyan, _mineScroll)),
                      VerticalDivider(width: 1, color: AppTheme.border),
                      Expanded(child: _buildSourcePane("THEIRS", 'remote', AppTheme.accentOrange, _theirsScroll)),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppTheme.border),
                Container(
                  height: 200,
                  color: AppTheme.bg1,
                  child: _buildResultPane(),
                ),
              ],
            ),
    );
  }

  Widget _buildConflictNavigator() {
    final conflicts = _chunks.where((c) => c['local'] != c['remote']).toList();
    if (conflicts.isEmpty) return SizedBox.shrink();

    final symbols = IndexerService.getSymbolsInText(conflicts[_currentConflictIndex]['local'] + "\n" + conflicts[_currentConflictIndex]['remote']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceSlate,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "Conflict ${_currentConflictIndex + 1} of ${conflicts.length}",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    onPressed: _currentConflictIndex > 0 ? () => setState(() => _currentConflictIndex--) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    onPressed: _currentConflictIndex < conflicts.length - 1 ? () => setState(() => _currentConflictIndex++) : null,
                  ),
                ],
              ),
            ],
          ),
          if (symbols.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.psychology_rounded, color: AppTheme.accentCyan, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Semantic Hint: Conflicting logic in ${symbols.join(', ')}",
                    style: GoogleFonts.inter(color: AppTheme.accentCyan, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourcePane(String title, String type, Color color, ScrollController scroll) {
    final chunk = _chunks[_currentConflictIndex];
    final isSelected = _selections[_currentConflictIndex] == type || _selections[_currentConflictIndex] == 'both';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          child: Row(
            children: [
              Icon(type == 'local' ? Icons.laptop_rounded : Icons.cloud_download_rounded, size: 12, color: color),
              const SizedBox(width: 4),
              Text(title, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isSelected) Icon(Icons.check_circle_rounded, size: 14, color: color),
            ],
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                if (_selections[_currentConflictIndex] == type) {
                  _selections.remove(_currentConflictIndex);
                } else if (_selections[_currentConflictIndex] != null && _selections[_currentConflictIndex] != 'both') {
                  _selections[_currentConflictIndex] = 'both';
                } else {
                  _selections[_currentConflictIndex] = type;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                controller: scroll,
                child: Text(
                  chunk[type],
                  style: GoogleFonts.firaCode(color: AppTheme.textLight, fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPane() {
    final chunk = _chunks[_currentConflictIndex];
    final selection = _selections[_currentConflictIndex];
    String preview = "";
    if (selection == 'local') preview = chunk['local'];
    else if (selection == 'remote') preview = chunk['remote'];
    else if (selection == 'both') preview = "${chunk['local']}\n${chunk['remote']}";
    else preview = "// Select a source above to resolve";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppTheme.border.withValues(alpha: 0.3),
          child: Text("LIVE RESULT PREVIEW", 
            style: GoogleFonts.inter(color: AppTheme.textDim, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              controller: _resultScroll,
              child: Text(
                preview,
                style: GoogleFonts.firaCode(
                  color: selection == null ? AppTheme.textMuted : AppTheme.accentGreen, 
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}