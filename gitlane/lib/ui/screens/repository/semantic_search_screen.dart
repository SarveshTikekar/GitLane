import 'package:flutter/material.dart';
import 'dart:io';
import '../../../services/indexer_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'file_editor_screen.dart';

class SemanticSearchScreen extends StatefulWidget {
  final String repoPath;

  const SemanticSearchScreen({super.key, required this.repoPath});

  @override
  State<SemanticSearchScreen> createState() => _SemanticSearchScreenState();
}

class _SemanticSearchScreenState extends State<SemanticSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _queryController = TextEditingController();
  List<SearchResult> _symbolResults = [];
  List<SearchResult> _contentResults = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    String q = _queryController.text.trim().toLowerCase();
    if (q.length < 2) {
      setState(() {
        _symbolResults = [];
        _contentResults = [];
        _hasSearched = false;
      });
      return;
    }

    // Smart Intelligence: Handle "symbol:" or other NL-like prefixes
    bool symbolOnly = false;
    if (q.startsWith('symbol:') || q.startsWith('func:') || q.startsWith('class:')) {
      q = q.split(':').last.trim();
      symbolOnly = true;
    }

    setState(() {
      _hasSearched = true;
      _symbolResults = IndexerService.searchSymbols(q);
      _contentResults = symbolOnly ? [] : IndexerService.searchContent(q);
    });
  }

  void _openResult(SearchResult result) {
    final fileName = result.filePath.split(Platform.pathSeparator).last;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileEditorScreen(
          filePath: result.filePath,
          fileName: fileName,
          repoPath: widget.repoPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbolCount = IndexerService.symbolCount;
    final fileCount = IndexerService.fileCount;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        backgroundColor: AppTheme.bg0,
        title: TextField(
          controller: _queryController,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search symbols or text...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16),
            border: InputBorder.none,
            suffixIcon: _queryController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 20),
                    onPressed: () => _queryController.clear(),
                  )
                : null,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentCyan,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 12),
          tabs: [
            Tab(text: '🔷 SYMBOLS (${_symbolResults.length})'),
            Tab(text: '📄 TEXT (${_contentResults.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_hasSearched)
            _buildIdxStats(symbolCount, fileCount),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildResultsList(_symbolResults, isSymbol: true),
                _buildResultsList(_contentResults, isSymbol: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdxStats(int symbols, int files) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.manage_search_rounded, size: 56, color: AppTheme.accentCyan.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            "Semantic Search",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Search across $symbols symbols in $files files.",
            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (symbols == 0) ...[
            const SizedBox(height: 16),
            Text(
              "Index is still loading. Results will appear shortly.",
              style: GoogleFonts.inter(color: AppTheme.accentOrange, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsList(List<SearchResult> results, {required bool isSymbol}) {
    if (_hasSearched && results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text("No ${isSymbol ? 'symbols' : 'matches'} found", style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final fileName = result.filePath.split(Platform.pathSeparator).last;
        final ext = fileName.contains('.') ? fileName.split('.').last : '';

        return InkWell(
          onTap: () => _openResult(result),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FileIcon(ext: ext),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedText(
                        text: result.content,
                        query: _queryController.text.trim(),
                        isSymbol: result.isSymbolMatch,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            fileName,
                            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ':${result.line}',
                            style: GoogleFonts.firaCode(color: AppTheme.accentCyan, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _FileIcon extends StatelessWidget {
  final String ext;
  const _FileIcon({required this.ext});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (ext) {
      case 'dart': color = AppTheme.accentCyan; label = 'D'; break;
      case 'kt':   color = AppTheme.accentPurple; label = 'K'; break;
      case 'c':    color = AppTheme.accentOrange; label = 'C'; break;
      case 'h':    color = AppTheme.accentYellow; label = 'H'; break;
      default:      color = AppTheme.textMuted; label = ext.isNotEmpty ? ext[0].toUpperCase() : '?';
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(label, style: GoogleFonts.firaCode(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final bool isSymbol;
  const _HighlightedText({required this.text, required this.query, required this.isSymbol});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: GoogleFonts.firaCode(color: AppTheme.textPrimary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx < 0) {
      return Text(text, style: GoogleFonts.firaCode(color: AppTheme.textPrimary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: GoogleFonts.firaCode(color: AppTheme.textPrimary, fontSize: 13),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: GoogleFonts.firaCode(
              color: isSymbol ? AppTheme.accentCyan : AppTheme.accentYellow,
              fontWeight: FontWeight.bold,
              backgroundColor: (isSymbol ? AppTheme.accentCyan : AppTheme.accentYellow).withValues(alpha: 0.15),
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}
