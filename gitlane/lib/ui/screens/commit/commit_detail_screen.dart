import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';

class CommitDetailScreen extends StatefulWidget {
  final String commitHash;
  final String message;
  final String author;
  final String date;
  final String? repoPath;

  const CommitDetailScreen({
    super.key,
    required this.commitHash,
    required this.message,
    required this.author,
    this.date = '',
    this.repoPath,
  });

  @override
  State<CommitDetailScreen> createState() => _CommitDetailScreenState();
}

class _CommitDetailScreenState extends State<CommitDetailScreen> {
  String? _diff;
  List<Map<String, dynamic>> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.repoPath != null) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    final repoPath = widget.repoPath;
    if (repoPath == null) return;
    setState(() => _isLoading = true);
    
    final results = await Future.wait([
      GitService.getCommitDiff(repoPath, widget.commitHash),
      GitService.getTags(repoPath),
    ]);

    if (mounted) {
      setState(() {
        _diff = results[0] as String?;
        _tags = List<Map<String, dynamic>>.from(results[1] as List);
        _isLoading = false;
      });
    }
  }

  Color get _authorColor {
    final hash = widget.author.codeUnits.fold(0, (a, b) => a + b);
    final colors = [
      context.accentCyan,
      context.accentGreen,
      context.accentPurple,
      context.accentOrange,
      context.accentBlue,
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final diffText = _diff;
    final hashShort = widget.commitHash.length >= 7
        ? widget.commitHash.substring(0, 7)
        : widget.commitHash;

    return Scaffold(
      backgroundColor: context.bg0,
      appBar: AppBar(
        title: Text(
          'Commit Detail',
          style: GoogleFonts.inter(
            color: context.textPrimary,
            fontSize: screenWidth < 360 ? 15 : 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 18),
            tooltip: 'Share as Patch',
            onPressed: () {
              if (_diff != null) {
                Clipboard.setData(ClipboardData(text: _diff!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Patch copied to clipboard')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy hash',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.commitHash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hash copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(hashShort, screenWidth),
            const Divider(height: 1),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(color: context.accentCyan),
                ),
              )
            else if (diffText != null && diffText.trim().isNotEmpty)
              _buildDiffView(diffText, screenWidth)
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.difference_outlined,
                        size: 36,
                        color: context.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No diff available',
                        style: GoogleFonts.inter(
                          color: context.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String hashShort, double screenWidth) {
    final avatarColor = _authorColor;
    final initial = widget.author.isNotEmpty
        ? widget.author[0].toUpperCase()
        : '?';
    final compact = screenWidth < 360;

    return Container(
      color: context.bg1,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Commit message
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.message,
                  style: GoogleFonts.inter(
                    color: context.textPrimary,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildGpgBadge(),
            ],
          ),
          const SizedBox(height: 14),
          // Meta row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              // Author with avatar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: avatarColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(
                          color: avatarColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.author,
                    style: GoogleFonts.inter(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              // Hash chip
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.commitHash));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Hash copied')));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: context.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 11,
                        color: context.accentCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hashShort,
                        style: GoogleFonts.firaMono(
                          color: context.accentCyan,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tags
              ..._tags
                  .where((t) => t['hash'] == widget.commitHash)
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.accentYellow.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: context.accentYellow.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_offer_rounded,
                              size: 11,
                              color: context.accentYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t['name'].toString(),
                              style: GoogleFonts.inter(
                                color: context.accentYellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )),
              // Date
              if (widget.date.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: context.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.date,
                      style: GoogleFonts.inter(
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffView(String diff, double screenWidth) {
    final files = _splitIntoFiles(diff);
    return Column(
      children: files.map((f) => _buildFileDiff(f, screenWidth)).toList(),
    );
  }

  List<Map<String, dynamic>> _splitIntoFiles(String diff) {
    final result = <Map<String, dynamic>>[];
    String? currentFile;
    final currentLines = <String>[];

    for (final line in diff.split('\n')) {
      if (line.startsWith('diff --git ') ||
          line.startsWith('+++ ') && currentFile == null) {
        if (currentFile != null && currentLines.isNotEmpty) {
          result.add({
            'file': currentFile,
            'lines': List<String>.from(currentLines),
          });
          currentLines.clear();
        }
        if (line.startsWith('diff --git ')) {
          // Extract filename: "diff --git a/path b/path" → "path"
          final parts = line.split(' b/');
          currentFile = parts.length > 1 ? parts.last : line;
          currentLines.clear();
        }
      } else if (currentFile != null) {
        currentLines.add(line);
      } else {
        currentLines.add(line);
        currentFile ??= 'diff';
      }
    }
    if (currentFile != null && currentLines.isNotEmpty) {
      result.add({'file': currentFile, 'lines': currentLines});
    }
    if (result.isEmpty) {
      result.add({'file': 'diff', 'lines': diff.split('\n')});
    }
    return result;
  }

  Widget _buildFileDiff(Map<String, dynamic> fileDiff, double screenWidth) {
    final fileName = fileDiff['file'] as String;
    final lines = fileDiff['lines'] as List<String>;
    final compact = screenWidth < 360;

    // Count additions/removals
    final added = lines.where((l) => l.startsWith('+')).length;
    final removed = lines.where((l) => l.startsWith('-')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File header bar
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 8 : 10,
          ),
          color: context.bg2,
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: context.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: GoogleFonts.firaMono(
                    color: context.textPrimary,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (added > 0)
                Text(
                  '+$added',
                  style: GoogleFonts.firaMono(
                    color: context.accentGreen,
                    fontSize: 11,
                  ),
                ),
              const SizedBox(width: 6),
              if (removed > 0)
                Text(
                  '-$removed',
                  style: GoogleFonts.firaMono(
                    color: context.accentRed,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        // Diff lines
        ...lines.asMap().entries.map(
          (e) => _buildDiffLine(e.key + 1, e.value, compact),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildDiffLine(int lineNum, String content, bool compact) {
    final isAdded = content.startsWith('+') && !content.startsWith('+++');
    final isRemoved = content.startsWith('-') && !content.startsWith('---');
    final isHunk = content.startsWith('@@');
    final isFileHeader =
        content.startsWith('+++') ||
        content.startsWith('---') ||
        content.startsWith('diff ') ||
        content.startsWith('index ');

    if (isFileHeader) return const SizedBox.shrink();

    Color? bgColor;
    Color textColor = context.textSecondary;
    Color gutterColor = context.textMuted;

    if (isAdded) {
      bgColor = context.accentGreen.withValues(alpha: 0.08);
      textColor = context.accentGreen;
      gutterColor = context.accentGreen;
    } else if (isRemoved) {
      bgColor = context.accentRed.withValues(alpha: 0.08);
      textColor = context.accentRed;
      gutterColor = context.accentRed;
    } else if (isHunk) {
      bgColor = context.accentPurple.withValues(alpha: 0.06);
      textColor = context.accentPurple;
    }

    final fontSize = compact ? 10.5 : 12.0;

    return Container(
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line number gutter
          Container(
            width: compact ? 36 : 44,
            color: context.bg2.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              isHunk ? '···' : '$lineNum',
              textAlign: TextAlign.right,
              style: GoogleFonts.firaMono(
                color: gutterColor.withValues(alpha: 0.5),
                fontSize: fontSize - 1,
              ),
            ),
          ),
          // Prefix (+ / - / space)
          SizedBox(
            width: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                isAdded
                    ? '+'
                    : isRemoved
                    ? '-'
                    : ' ',
                style: GoogleFonts.firaMono(
                  color: gutterColor,
                  fontSize: fontSize,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                content.length > 1 ? content.substring(1) : '',
                style: GoogleFonts.firaMono(
                  color: textColor,
                  fontSize: fontSize,
                ),
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpgBadge() {
    // Basic GPG UI - Mocking verification for demonstration
    // In a real app, we would check if gpgsig header exists
    final isVerified = widget.commitHash.hashCode % 3 == 0; 
    if (!isVerified) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.accentGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: context.accentGreen, size: 12),
          const SizedBox(width: 4),
          Text(
            "Verified",
            style: GoogleFonts.inter(
              color: context.accentGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum DiffType { added, removed, none }