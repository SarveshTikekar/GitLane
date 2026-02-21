import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import '../../widgets/glass_card.dart';

class VisualMergeEditor extends StatefulWidget {
  final String repoPath;
  final String filePath;

  const VisualMergeEditor({
    super.key,
    required this.repoPath,
    required this.filePath,
  });

  @override
  State<VisualMergeEditor> createState() => _VisualMergeEditorState();
}

class _VisualMergeEditorState extends State<VisualMergeEditor> {
  List<Map<String, dynamic>> _chunks = [];
  Map<int, String> _selections = {}; // index -> 'local' or 'remote'
  bool _isLoading = true;

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
      // Initialize with no selection
    });
  }

  Future<void> _applyResolution() async {
    if (_selections.length < _chunks.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please resolve all conflicts first.")),
      );
      return;
    }

    String finalContent = "";
    // In a real app we'd need to re-read the file and replace ONLY the conflict zones.
    // For this hackathon, we assume the file IS a set of chunks.
    for (int i = 0; i < _chunks.length; i++) {
        finalContent += _chunks[i][_selections[i]] + "\n";
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
        title: const Text("Visual Merge Resolver"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accentCyan),
            onPressed: _applyResolution,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chunks.length,
              itemBuilder: (context, index) {
                final chunk = _chunks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Conflict #${index + 1}", 
                        style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildOptionCard(index, 'local', chunk['local'], Colors.blue),
                      const Center(child: Icon(Icons.compare_arrows, color: AppTheme.textDim, size: 20)),
                      _buildOptionCard(index, 'remote', chunk['remote'], Colors.orange),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOptionCard(int chunkIndex, String type, String content, Color highlightColor) {
    final isSelected = _selections[chunkIndex] == type;

    return InkWell(
      onTap: () => setState(() => _selections[chunkIndex] = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? highlightColor.withOpacity(0.1) : AppTheme.surfaceSlate.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? highlightColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type == 'local' ? Icons.laptop_rounded : Icons.cloud_download_rounded, 
                  size: 14, color: isSelected ? highlightColor : AppTheme.textDim),
                const SizedBox(width: 8),
                Text(type.toUpperCase(), 
                  style: TextStyle(color: isSelected ? highlightColor : AppTheme.textDim, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content.isEmpty ? "[Empty]" : content.trim(),
              style: const TextStyle(color: AppTheme.textLight, fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
