import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';

class CommitDetailScreen extends StatefulWidget {
  final String commitHash;
  final String message;
  final String? repoPath;

  const CommitDetailScreen({
    super.key,
    required this.commitHash,
    required this.message,
    this.repoPath,
  });

  @override
  State<CommitDetailScreen> createState() => _CommitDetailScreenState();
}

class _CommitDetailScreenState extends State<CommitDetailScreen> {
  String? _diff;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.repoPath != null) {
      _fetchDiff();
    }
  }

  Future<void> _fetchDiff() async {
    setState(() => _isLoading = true);
    final diff = await GitService.getCommitDiff(
      widget.repoPath!,
      widget.commitHash,
    );
    setState(() {
      _diff = diff;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commit Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommitHeader(),
            const Divider(color: AppTheme.surfaceSlate, height: 1),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                ),
              )
            else if (_diff != null)
              _buildDiffSection('Full Diff', _diff!)
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "No diff available (mock view)",
                  style: TextStyle(color: AppTheme.textDim),
                ),
              ),

            // Mock sections for visualization if no real diff
            if (_diff == null) ...[
              _buildMockDiffSection('lib/main.dart'),
              _buildMockDiffSection('lib/ui/theme/app_theme.dart'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommitHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.accentCyan,
                child: Icon(Icons.person, size: 16, color: Colors.black),
              ),
              const SizedBox(width: 8),
              const Text(
                'gautam',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                widget.commitHash.length > 7
                    ? widget.commitHash.substring(0, 7)
                    : widget.commitHash,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.accentCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffSection(String title, String diffContent) {
    final lines = diffContent.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceSlate,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            DiffType type = DiffType.none;
            if (line.startsWith('+')) type = DiffType.added;
            if (line.startsWith('-')) type = DiffType.removed;
            return _buildDiffLine(line, type);
          },
        ),
      ],
    );
  }

  Widget _buildMockDiffSection(String fileName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceSlate.withValues(alpha: 0.5),
          child: Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        _buildDiffLine('- old_function_name()', DiffType.removed),
        _buildDiffLine('+ new_function_name()', DiffType.added),
        _buildDiffLine('  unchanged_line()', DiffType.none),
      ],
    );
  }

  Widget _buildDiffLine(String content, DiffType type) {
    Color? bgColor;
    Color? textColor;
    if (type == DiffType.added) {
      bgColor = Colors.green.withValues(alpha: 0.1);
      textColor = Colors.green[300];
    } else if (type == DiffType.removed) {
      bgColor = Colors.red.withValues(alpha: 0.1);
      textColor = Colors.red[300];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: bgColor,
      child: Text(
        content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: textColor ?? AppTheme.textLight,
        ),
      ),
    );
  }
}

enum DiffType { added, removed, none }
