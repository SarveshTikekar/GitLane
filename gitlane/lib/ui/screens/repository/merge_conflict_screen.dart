import 'package:flutter/material.dart';
import 'dart:io';
import 'visual_merge_editor.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';

class MergeConflictScreen extends StatefulWidget {
  final String repoPath;
  final List<String> conflictingFiles;
  
  const MergeConflictScreen({
    super.key, 
    required this.repoPath, 
    required this.conflictingFiles
  });

  @override
  State<MergeConflictScreen> createState() => _MergeConflictScreenState();
}

class _MergeConflictScreenState extends State<MergeConflictScreen> {
  late List<String> _files;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.conflictingFiles);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final list = await GitService.getConflicts(widget.repoPath);
    if (mounted) {
      setState(() {
        _files = list;
        _isLoading = false;
      });
      if (_files.isEmpty) {
        // All resolved!
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _openResolver(String fileName) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VisualMergeEditor(
          repoPath: widget.repoPath,
          filePath: fileName,
        ),
      ),
    );

    if (confirmed == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Merge Conflicts"),
        backgroundColor: Colors.redAccent.withOpacity(0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
        : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "The following files have merge conflicts. Edit them to remove markers (<<<<, ====, >>>>) and stage the final version.",
                  style: TextStyle(color: AppTheme.textDim, fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final f = _files[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppTheme.surfaceSlate,
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        title: Text(f, style: const TextStyle(color: AppTheme.textLight)),
                        subtitle: const Text("Conflicting markers detected", style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
                        trailing: const Icon(Icons.edit, color: AppTheme.accentCyan, size: 20),
                        onTap: () => _openResolver(f),
                      ),
                    );
                  },
                ),
              ),
              if (_files.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppTheme.accentCyan, size: 64),
                      SizedBox(height: 16),
                      Text("All conflicts resolved!", style: TextStyle(color: AppTheme.textLight, fontSize: 18)),
                    ],
                  ),
                ),
            ],
          ),
    );
  }
}
