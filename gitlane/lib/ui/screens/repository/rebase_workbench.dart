import 'package:flutter/material.dart';
import '../../../services/git_service.dart';
import '../../../services/rebase_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

class RebaseWorkbench extends StatefulWidget {
  final String repoPath;
  final String currentBranch;

  const RebaseWorkbench({
    super.key,
    required this.repoPath,
    required this.currentBranch,
  });

  @override
  State<RebaseWorkbench> createState() => _RebaseWorkbenchState();
}

class _RebaseWorkbenchState extends State<RebaseWorkbench> {
  List<Map<String, dynamic>> _allCommits = [];
  List<Map<String, dynamic>> _rebasePlan = [];
  String? _targetHash;
  bool _isLoading = true;
  bool _isRebasing = false;

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    setState(() => _isLoading = true);
    final logJson = await GitService.getCommitLog(widget.repoPath);
    if (logJson != null) {
      final data = jsonDecode(logJson);
      if (data is List) {
        setState(() {
          _allCommits = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    }
  }

  void _prepareRebase(String targetHash) {
    // Collect commits between HEAD and target
    final plan = <Map<String, dynamic>>[];
    for (var commit in _allCommits) {
      if (commit['hash'] == targetHash) break;
      plan.add({...commit, 'action': 'pick'});
    }
    
    setState(() {
      _targetHash = targetHash;
      _rebasePlan = plan.reversed.toList(); // Common to rebase from oldest to newest
    });
  }

  Future<void> _executeRebase() async {
    if (_targetHash == null) return;
    
    setState(() => _isRebasing = true);
    
    // In a real interactive rebase, we would need to handle reorders.
    // However, our current native bridge handles standard rebase onto 'target'.
    // To support full interactive rebase (reorder/squash), we would need 
    // to iterate through our plan and call rebaseNext/Commit/Abort.
    
    final res = await RebaseService.init(widget.repoPath, _targetHash!, _targetHash!);
    if (res < 0) {
      if (mounted) {
        setState(() => _isRebasing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rebase Init failed: $res")));
      }
      return;
    }

    // Process step by step according to plan
    bool finished = false;
    while (!finished) {
      final nextInfo = await RebaseService.next(widget.repoPath);
      if (nextInfo['finished'] == true) {
        finished = true;
        break;
      }
      
      final currentHash = nextInfo['hash'];
      // Find what action the user wanted for this hash
      final planItem = _rebasePlan.firstWhere((p) => p['hash'] == currentHash, orElse: () => {'action': 'pick'});
      
      if (planItem['action'] == 'drop') {
        // Just don't commit it? Libgit2 rebase_next handles the checkout.
        // If we don't commit, we just call next again.
        continue;
      } else {
        // Commit it
        final commitRes = await RebaseService.commit(
          widget.repoPath, 
          planItem['message'] ?? "Rebase commit",
        );
        if (commitRes < 0) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rebase step failed for $currentHash")));
           await RebaseService.abort(widget.repoPath);
           setState(() => _isRebasing = false);
           return;
        }
      }
    }

    await RebaseService.finish(widget.repoPath);
    if (mounted) {
      setState(() => _isRebasing = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: const Text("Interactive Rebase"),
        backgroundColor: AppTheme.bg0,
        actions: [
          if (_rebasePlan.isNotEmpty && !_isRebasing)
            TextButton(
              onPressed: _executeRebase,
              child: const Text("START", style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _targetHash == null
              ? _buildTargetSelection()
              : _buildRebaseWorkbench(),
    );
  }

  Widget _buildTargetSelection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Base Commit", style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Interactive rebase will rewrite all commits from your selection up to current HEAD.", 
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _allCommits.length,
            itemBuilder: (context, index) {
              final commit = _allCommits[index];
              return ListTile(
                leading: const Icon(Icons.radio_button_unchecked_rounded, color: AppTheme.textMuted, size: 20),
                title: Text(commit['message'] ?? "No message", style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(commit['hash']?.toString().substring(0, 7) ?? "", style: GoogleFonts.firaCode(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () => _prepareRebase(commit['hash']),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRebaseWorkbench() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.accentCyan.withValues(alpha: 0.05),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Drag to reorder. Tap action to change (pick/squash/drop).",
                  style: GoogleFonts.inter(color: AppTheme.accentCyan, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _rebasePlan.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _rebasePlan.removeAt(oldIndex);
                _rebasePlan.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final item = _rebasePlan[index];
              final action = item['action'];
              Color actionColor = AppTheme.accentGreen;
              if (action == 'drop') actionColor = AppTheme.accentRed;
              if (action == 'squash') actionColor = AppTheme.accentOrange;

              return ListTile(
                key: ValueKey(item['hash']),
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                         setState(() {
                           if (action == 'pick') item['action'] = 'squash';
                           else if (action == 'squash') item['action'] = 'drop';
                           else item['action'] = 'pick';
                         });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: actionColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          action.toUpperCase(),
                          style: GoogleFonts.inter(color: actionColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(item['message'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: const Icon(Icons.drag_indicator_rounded, color: AppTheme.textMuted),
              );
            },
          ),
        ),
        if (_isRebasing)
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.bg2,
            child: Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan)),
                const SizedBox(width: 16),
                Text("Executing Rebase Plan...", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}
