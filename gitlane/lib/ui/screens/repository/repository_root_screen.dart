import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import 'package:file_picker/file_picker.dart';
import 'file_editor_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../services/git_service.dart';
import '../commit/commit_detail_screen.dart';
import '../commit/commit_graph_screen.dart';
import 'native_terminal_screen.dart';
import 'merge_conflict_screen.dart';
import 'stash_screen.dart';
import 'share_repo_screen.dart';
import 'reflog_screen.dart';

class RepositoryRootScreen extends StatefulWidget {
  final String repoName;
  final String repoPath;
  const RepositoryRootScreen({
    super.key,
    required this.repoName,
    required this.repoPath,
  });

  @override
  State<RepositoryRootScreen> createState() => _RepositoryRootScreenState();
}

class _RepositoryRootScreenState extends State<RepositoryRootScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  List<dynamic> _commits = [];
  bool _isLoading = false;
  bool _isNotGitRepo = false;

  List<dynamic> _statusFiles = [];
  String _currentBranch = 'HEAD';
  List<String> _branches = [];

  List<FileSystemEntity> _currentFiles = [];
  String _currentDir = '';

  String? _personalAccessToken;

  @override
  void initState() {
    super.initState();
    _currentDir = widget.repoPath;
    _fetchData();
    _listRepoFiles();
  }

  // ── File system ─────────────────────────────────────────────────────────────
  void _listRepoFiles() {
    try {
      final dir = Directory(_currentDir);
      if (!dir.existsSync()) return;
      setState(() {
        _currentFiles =
            dir.listSync().where((e) {
              final name = e.path.split(Platform.pathSeparator).last;
              return name != '.git' && !name.startsWith('.');
            }).toList()..sort((a, b) {
              if (a is Directory && b is File) return -1;
              if (a is File && b is Directory) return 1;
              return a.path
                  .split(Platform.pathSeparator)
                  .last
                  .toLowerCase()
                  .compareTo(
                    b.path.split(Platform.pathSeparator).last.toLowerCase(),
                  );
            });
      });
    } catch (e) {
      debugPrint('Error listing files: $e');
    }
  }

  // ── Git data ─────────────────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final logJson = await GitService.getCommitLog(widget.repoPath);
    final statusJson = await GitService.getRepositoryStatus(widget.repoPath);
    if (!mounted) return;
    setState(() {
      if (logJson == null && statusJson == null) {
        _isNotGitRepo = true;
      } else {
        _isNotGitRepo = false;
        if (logJson != null) {
          try {
            final d = jsonDecode(logJson);
            if (d is List) _commits = d;
          } catch (_) {}
        }
        if (statusJson != null) {
          try {
            final d = jsonDecode(statusJson);
            if (d is List) _statusFiles = d;
          } catch (_) {}
        }
      }
      _isLoading = false;
    });
    _updateBranchInfo();
  }

  Future<void> _updateBranchInfo() async {
    final current = await GitService.getCurrentBranch(widget.repoPath);
    final list = await GitService.getBranches(widget.repoPath);
    if (mounted) {
      setState(() {
        _currentBranch = current;
        _branches = list;
      });
    }
  }

  // ── Graph nodes ───────────────────────────────────────────────────────────────
  List<CommitNode> _graphNodesFromCommits() {
    if (_commits.isEmpty) return [];
    final nodes = <CommitNode>[];

    for (var i = 0; i < _commits.length; i++) {
      final current = _commits[i];
      if (current is! Map) continue;

      final hash = (current['hash'] ?? '').toString();
      if (hash.isEmpty) continue;

      String parentHash = '';
      if (i + 1 < _commits.length) {
        final parent = _commits[i + 1];
        if (parent is Map) {
          parentHash = (parent['hash'] ?? '').toString();
        }
      }

      final ts = current['time'];
      int unix = 0;
      if (ts is num) unix = ts.toInt();
      if (ts is String) unix = int.tryParse(ts) ?? 0;

      nodes.add(
        CommitNode(
          id: hash,
          parentIds: parentHash.isEmpty ? const [] : [parentHash],
          message: (current['message'] ?? 'No message').toString(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            unix * 1000,
            isUtc: true,
          ).toLocal(),
          lane: 0,
        ),
      );
    }

    return nodes;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    int? unix;
    if (ts is num) unix = ts.toInt();
    if (ts is String) unix = int.tryParse(ts);
    if (unix == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      unix * 1000,
      isUtc: true,
    ).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  String _currentRelativePathLabel() {
    if (_currentDir == widget.repoPath) return '';
    if (_currentDir.startsWith(widget.repoPath)) {
      final relative = _currentDir.substring(widget.repoPath.length);
      return relative.isEmpty ? '/' : relative;
    }
    return _currentDir;
  }

  String _fileExt(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot) : '';
  }

  Color _extColor(String ext) {
    switch (ext.toLowerCase()) {
      case '.dart':
        return const Color(0xFF54C5F8);
      case '.kt':
      case '.java':
        return const Color(0xFFEF6C00);
      case '.json':
        return const Color(0xFFD29922);
      case '.md':
        return const Color(0xFF8B949E);
      case '.yaml':
      case '.yml':
        return const Color(0xFFBC8CFF);
      case '.swift':
        return const Color(0xFFFF6C37);
      case '.py':
        return const Color(0xFF3FB950);
      case '.js':
      case '.ts':
        return const Color(0xFFF7DF1E);
      default:
        return AppTheme.textSecondary;
    }
  }

  // ── Dialogs / Actions ─────────────────────────────────────────────────────────
  Future<void> _showCommitDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit Changes'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'feat: describe your changes…',
            prefixIcon: Icon(Icons.commit_rounded, size: 18),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Commit'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      final code = await GitService.commitAll(
        widget.repoPath,
        controller.text.trim(),
      );
      if (mounted) {
        _showSnack(
          code == 0 ? '✓ Commit successful' : 'Commit failed (code: $code)',
          code == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
        );
        if (code == 0) {
          _fetchData();
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showBranchDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.account_tree_rounded,
                size: 18,
                color: AppTheme.accentGreen,
              ),
              const SizedBox(width: 8),
              const Text('Git Branches'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branches',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _branches.length,
                    itemBuilder: (context, idx) {
                      final b = _branches[idx];
                      final isCurrent = b == _currentBranch;
                      final color = (b == 'main' || b == 'master')
                          ? AppTheme.accentGreen
                          : AppTheme.accentBlue;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? color.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent
                              ? Border.all(color: color.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          leading: Icon(
                            isCurrent
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 16,
                            color: isCurrent ? color : AppTheme.textMuted,
                          ),
                          title: Text(
                            b,
                            style: GoogleFonts.firaMono(
                              color: isCurrent
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'current',
                                    style: GoogleFonts.inter(
                                      color: color,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _branchAction(
                                      'Checkout',
                                      AppTheme.accentCyan,
                                      () async {
                                        Navigator.pop(context);
                                        setState(() => _isLoading = true);
                                        final code =
                                            await GitService.checkoutBranch(
                                              widget.repoPath,
                                              b,
                                            );
                                        if (mounted) {
                                          _showSnack(
                                            code == 0
                                                ? "Checked out '$b'"
                                                : "Checkout failed ($code)",
                                            code == 0
                                                ? AppTheme.accentGreen
                                                : AppTheme.accentRed,
                                          );
                                          _fetchData();
                                          _listRepoFiles();
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _branchAction(
                                      'Merge',
                                      AppTheme.accentOrange,
                                      () async {
                                        Navigator.pop(context);
                                        setState(() => _isLoading = true);
                                        final code =
                                            await GitService.mergeBranch(
                                              widget.repoPath,
                                              b,
                                            );
                                        if (!mounted) return;
                                        if (code == -100) {
                                          final conflicts =
                                              await GitService.getConflicts(
                                                widget.repoPath,
                                              );
                                          if (!mounted) return;
                                          final resolved =
                                              await Navigator.push<bool>(
                                                this.context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      MergeConflictScreen(
                                                        repoPath:
                                                            widget.repoPath,
                                                        conflictingFiles:
                                                            conflicts,
                                                      ),
                                                ),
                                              );
                                          if (!mounted) return;
                                          if (resolved == true) {
                                            await GitService.commitAll(
                                              widget.repoPath,
                                              "Merge branch '$b'",
                                            );
                                            _fetchData();
                                          } else {
                                            setState(() => _isLoading = false);
                                          }
                                        } else {
                                          _showSnack(
                                            code >= 0
                                                ? "Merged '$b'"
                                                : "Merge failed ($code)",
                                            code >= 0
                                                ? AppTheme.accentGreen
                                                : AppTheme.accentRed,
                                          );
                                          _fetchData();
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: AppTheme.accentRed,
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () async {
                                        final ok = await _confirmDelete(b);
                                        if (ok == true) {
                                          if (!mounted) return;
                                          Navigator.of(this.context).pop();
                                          setState(() => _isLoading = true);
                                          final code =
                                              await GitService.deleteBranch(
                                                widget.repoPath,
                                                b,
                                              );
                                          if (!mounted) return;
                                          _showSnack(
                                            code == 0
                                                ? "Deleted '$b'"
                                                : "Delete failed ($code)",
                                            code == 0
                                                ? AppTheme.accentGreen
                                                : AppTheme.accentRed,
                                          );
                                          _updateBranchInfo();
                                          setState(() => _isLoading = false);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  style: GoogleFonts.firaMono(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'New branch name',
                    prefixIcon: Icon(Icons.add_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final code = await GitService.createBranch(
                  widget.repoPath,
                  name,
                );
                if (mounted) {
                  _showSnack(
                    code == 0
                        ? "Branch '$name' created!"
                        : "Failed (code: $code)",
                    code == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                  );
                  _fetchData();
                }
              },
              child: const Text('Create Branch'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchAction(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Future<bool?> _confirmDelete(String branch) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Branch'),
      content: Text("Delete '$branch'? This cannot be undone if unmerged."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: AppTheme.accentRed),
          ),
        ),
      ],
    ),
  );

  Future<void> _showStashSaveDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: AppTheme.accentOrange,
            ),
            SizedBox(width: 8),
            Text('Stash Changes'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Message (optional)',
            hintText: 'WIP: work in progress…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final code = await GitService.stashSave(
                widget.repoPath,
                controller.text.trim(),
              );
              if (mounted) {
                _showSnack(
                  code == 0 ? '✓ Changes stashed' : 'Stash failed ($code)',
                  code == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                );
                _fetchData();
                _listRepoFiles();
              }
            },
            child: const Text('Stash'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewFileDialog() async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.add_comment_outlined,
              size: 18,
              color: AppTheme.accentCyan,
            ),
            SizedBox(width: 8),
            Text('Create New File'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'File Name',
                hintText: 'example.dart',
                prefixIcon: Icon(Icons.description_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: contentController,
              maxLines: 5,
              style: GoogleFonts.firaMono(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: '// your code here',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final file = File('$_currentDir${Platform.pathSeparator}$name');
              await file.writeAsString(contentController.text);
              if (!mounted) return;
              Navigator.of(this.context).pop();
              _showSnack('Created $name', AppTheme.accentGreen);
              _fetchData();
              _listRepoFiles();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCredentialDialog({
    required Function(String token) onConfirm,
  }) async {
    final controller = TextEditingController(text: _personalAccessToken);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, size: 18, color: AppTheme.accentCyan),
            SizedBox(width: 8),
            Text('Git Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Access Token (PAT)',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: GoogleFonts.firaMono(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                hintText: 'ghp_xxxxxxxxxxxx',
                prefixIcon: Icon(Icons.token_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Token is stored for this session only.',
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final token = controller.text.trim();
              if (token.isNotEmpty) {
                _personalAccessToken = token;
                Navigator.pop(context);
                onConfirm(token);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _pullRepo() => _showCredentialDialog(
    onConfirm: (token) async {
      setState(() => _isLoading = true);
      final code = await GitService.pullRepository(widget.repoPath, token);
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(
          code == 0 ? '⬇ Pull successful' : 'Pull failed ($code)',
          code == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
        );
        _fetchData();
        _listRepoFiles();
      }
    },
  );

  Future<void> _pushRepo() => _showCredentialDialog(
    onConfirm: (token) async {
      setState(() => _isLoading = true);
      final code = await GitService.pushRepository(widget.repoPath, token);
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(
          code == 0 ? '⬆ Push successful' : 'Push failed ($code)',
          code == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
        );
        _fetchData();
      }
    },
  );

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.bg2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stageFile(String path) async {
    HapticFeedback.lightImpact();
    await GitService.gitAddFile(widget.repoPath, path);
    _fetchData();
  }

  Future<void> _discardFile(String path) async {
    HapticFeedback.mediumImpact();
    // git checkout -- <path> via bridge — fallback: show snack
    _showSnack('Discard not yet supported via bridge', AppTheme.accentYellow);
  }

  Future<void> _unstageFile(String path) async {
    HapticFeedback.mediumImpact();
    // git reset HEAD -- <path> via bridge — fallback: show snack
    _showSnack('Unstage not yet supported via bridge', AppTheme.accentYellow);
  }

  Future<void> _shareRepo() async {
    final url = await GitService.getRemoteUrl(widget.repoPath);
    if (!mounted) return;
    if (url.startsWith('http') || url.startsWith('git@')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ShareRepoScreen(repoName: widget.repoName, remoteUrl: url),
        ),
      );
    } else {
      _showSnack('No remote origin set', AppTheme.accentYellow);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      for (var file in result.files) {
        if (file.path != null) {
          final targetPath =
              "$_currentDir${Platform.pathSeparator}${file.name}";
          await File(file.path!).copy(targetPath);
          await GitService.gitAddFile(widget.repoPath, file.name);
        }
      }
      _fetchData();
      _listRepoFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Uploaded ${result.count} files")),
        );
      }
    }
  }

  // ── Overflow menu ─────────────────────────────────────────────────────────────
  void _showOverflowMenu(BuildContext anchorContext) async {
    final buttonObject = anchorContext.findRenderObject();
    if (buttonObject is! RenderBox) return;
    final overlayState = Navigator.of(context).overlay;
    if (overlayState == null) return;
    final overlayObject = overlayState.context.findRenderObject();
    if (overlayObject is! RenderBox) return;
    final RenderBox button = buttonObject;
    final RenderBox overlay = overlayObject;
    final offset = Offset(0, button.size.height);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + offset,
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      color: AppTheme.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      items: [
        _menuItem('pull', Icons.download_rounded, 'Pull', AppTheme.accentBlue),
        _menuItem('push', Icons.upload_rounded, 'Push', AppTheme.accentBlue),
        const PopupMenuDivider(height: 1),
        _menuItem(
          'stash_save',
          Icons.save_outlined,
          'Stash Changes',
          AppTheme.accentOrange,
        ),
        _menuItem(
          'stash_list',
          Icons.inventory_2_outlined,
          'View Stashes',
          AppTheme.accentOrange,
        ),
        const PopupMenuDivider(height: 1),
        _menuItem(
          'graph',
          Icons.timeline_rounded,
          'Commit Graph',
          AppTheme.accentPurple,
        ),
        _menuItem(
          'reflog',
          Icons.history_edu_rounded,
          'Action History',
          AppTheme.textSecondary,
        ),
        _menuItem(
          'share',
          Icons.qr_code_2_rounded,
          'Share (QR)',
          AppTheme.textSecondary,
        ),
        _menuItem(
          'upload',
          Icons.upload_file_rounded,
          'Import File',
          AppTheme.accentCyan,
        ),
      ],
    );

    if (!mounted) return;
    switch (result) {
      case 'pull':
        _pullRepo();
        break;
      case 'push':
        _pushRepo();
        break;
      case 'stash_save':
        _showStashSaveDialog();
        break;
      case 'stash_list':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StashScreen(repoPath: widget.repoPath),
          ),
        );
        break;
      case 'graph':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommitGraphScreen(
              commits: _graphNodesFromCommits(),
              title: '${widget.repoName} Graph',
            ),
          ),
        );
        break;
      case 'reflog':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReflogScreen(repoPath: widget.repoPath),
          ),
        );
        break;
      case 'share':
        _shareRepo();
        break;
      case 'upload':
        _uploadFile();
        break;
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) => PopupMenuItem(
    value: value,
    height: 44,
    child: Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
        ),
      ],
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final branchColor = (_currentBranch == 'main' || _currentBranch == 'master')
        ? AppTheme.accentGreen
        : AppTheme.accentBlue;
    final statusCount = _statusFiles.length;

    return PopScope(
      canPop: _currentDir == widget.repoPath,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentDir != widget.repoPath) {
          setState(() {
            _currentDir = Directory(_currentDir).parent.path;
            _listRepoFiles();
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg0,
        appBar: AppBar(
          backgroundColor: AppTheme.bg0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          leading: _currentDir != widget.repoPath
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => setState(() {
                    _currentDir = Directory(_currentDir).parent.path;
                    _listRepoFiles();
                  }),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrowTitle = constraints.maxWidth < 220;
                  final branchChip = GestureDetector(
                    onTap: _showBranchDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: branchColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: branchColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree_rounded,
                            size: 10,
                            color: branchColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentBranch,
                            style: GoogleFonts.firaMono(
                              color: branchColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (narrowTitle) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.repoName,
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        branchChip,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.repoName,
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      branchChip,
                    ],
                  );
                },
              ),
              if (_currentDir != widget.repoPath)
                Text(
                  _currentRelativePathLabel(),
                  style: GoogleFonts.firaMono(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh',
              onPressed: () {
                _fetchData();
                _listRepoFiles();
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_tree_rounded, size: 20),
              tooltip: 'Branches',
              onPressed: _showBranchDialog,
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                tooltip: 'More actions',
                onPressed: () => _showOverflowMenu(ctx),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentCyan),
              )
            : _isNotGitRepo
            ? _buildNotGitRepoView()
            : IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildExplorerView(),
                  _buildHistoryView(),
                  _buildStatusView(),
                ],
              ),
        bottomNavigationBar: _isNotGitRepo
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder_rounded),
                    label: 'Explorer',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: statusCount > 0,
                      label: Text('$statusCount'),
                      child: const Icon(Icons.adjust_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: statusCount > 0,
                      label: Text('$statusCount'),
                      child: const Icon(Icons.adjust_rounded),
                    ),
                    label: 'Status',
                  ),
                ],
              ),
        floatingActionButton: _isNotGitRepo || _isLoading
            ? null
            : _selectedIndex == 0
            ? FloatingActionButton(
                onPressed: _showNewFileDialog,
                tooltip: 'New File',
                child: const Icon(Icons.add_rounded),
              )
            : _selectedIndex == 2 && _statusFiles.isNotEmpty
            ? compact
                  ? FloatingActionButton(
                      onPressed: _showCommitDialog,
                      tooltip: 'Commit',
                      child: const Icon(Icons.check_rounded),
                    )
                  : FloatingActionButton.extended(
                      onPressed: _showCommitDialog,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        'Commit ${_statusFiles.length} files',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    )
            : null,
      ),
    );
  }

  // ── Explorer Tab ───────────────────────────────────────────────────────────────
  Widget _buildExplorerView() {
    if (_currentFiles.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'Empty directory',
        subtitle: 'Create a new file to get started',
        action: ElevatedButton.icon(
          onPressed: _showNewFileDialog,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('New File'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _currentFiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
      itemBuilder: (context, index) {
        final entity = _currentFiles[index];
        final name = entity.path.split(Platform.pathSeparator).last;
        final isDir = entity is Directory;
        final ext = isDir ? '' : _fileExt(name);
        final extColor = isDir ? AppTheme.accentCyan : _extColor(ext);

        return PopupMenuButton<String>(
          color: AppTheme.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.border),
          ),
          onSelected: (value) async {
            if (value == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete'),
                  content: Text("Delete '$name'? This cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: AppTheme.accentRed),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await entity.delete(recursive: isDir);
                _fetchData();
                _listRepoFiles();
              }
            } else if (value == 'rename') {
              final ctrl = TextEditingController(text: name);
              final newName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Rename'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'New Name'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                      child: const Text('Rename'),
                    ),
                  ],
                ),
              );
              if (newName != null && newName.isNotEmpty && newName != name) {
                final newPath =
                    '${entity.parent.path}${Platform.pathSeparator}$newName';
                await entity.rename(newPath);
                _listRepoFiles();
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'rename',
              height: 40,
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rename',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              height: 40,
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppTheme.accentRed,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Delete',
                    style: GoogleFonts.inter(
                      color: AppTheme.accentRed,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: ListTile(
            onTap: () {
              if (isDir) {
                setState(() {
                  _currentDir = entity.path;
                  _listRepoFiles();
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileEditorScreen(
                      filePath: entity.path,
                      fileName: name,
                      repoPath: widget.repoPath,
                    ),
                  ),
                ).then((value) {
                  if (value == true) {
                    _fetchData();
                    _listRepoFiles();
                  }
                });
              }
            },
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: extColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDir ? Icons.folder_rounded : Icons.description_outlined,
                size: 18,
                color: extColor,
              ),
            ),
            title: Text(
              name,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            subtitle: !isDir && ext.isNotEmpty
                ? Text(
                    ext,
                    style: GoogleFonts.firaMono(color: extColor, fontSize: 10),
                  )
                : null,
            trailing: isDir
                ? const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  )
                : null,
          ),
        );
      },
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────────
  Widget _buildHistoryView() {
    if (_commits.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: 'No commits yet',
        subtitle:
            'Make your first commit on the Status tab to start tracking history',
        action: ElevatedButton.icon(
          onPressed: () => setState(() => _selectedIndex = 2),
          icon: const Icon(Icons.adjust_rounded, size: 16),
          label: const Text('Go to Status'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _commits.length,
      itemBuilder: (context, index) => _buildCommitRow(index),
    );
  }

  Widget _buildCommitRow(int index) {
    final rawCommit = _commits[index];
    if (rawCommit is! Map) {
      return const SizedBox.shrink();
    }
    final commit = Map<String, dynamic>.from(rawCommit);
    final hash = (commit['hash'] ?? '0000000').toString();
    final msg = (commit['message'] ?? 'No message').toString();
    final author = (commit['author'] ?? 'Unknown').toString();
    final timeAgo = _relativeTime(commit['time']);
    final isLast = index == _commits.length - 1;

    // avatar letter + color from author hash
    final avatarColor = _authorColor(author);
    final initial = author.isNotEmpty ? author[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommitDetailScreen(
            commitHash: hash,
            message: msg,
            author: author,
            date: timeAgo,
            repoPath: widget.repoPath,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lane column
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.bg0,
                      border: Border.all(color: AppTheme.accentCyan, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(width: 2, height: 52, color: AppTheme.border),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 290;

                        final authorChip = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                author,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );

                        final hashChip = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            hash.length >= 7 ? hash.substring(0, 7) : hash,
                            style: GoogleFonts.firaMono(
                              color: AppTheme.accentCyan,
                              fontSize: 10,
                            ),
                          ),
                        );

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              authorChip,
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  hashChip,
                                  Text(
                                    timeAgo,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: authorChip),
                            const SizedBox(width: 8),
                            hashChip,
                            const SizedBox(width: 8),
                            Text(
                              timeAgo,
                              style: GoogleFonts.inter(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      },
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

  Color _authorColor(String author) {
    final hash = author.codeUnits.fold(0, (a, b) => a + b);
    const colors = [
      AppTheme.accentCyan,
      AppTheme.accentGreen,
      AppTheme.accentPurple,
      AppTheme.accentOrange,
      AppTheme.accentBlue,
    ];
    return colors[hash % colors.length];
  }

  // ── Status Tab ────────────────────────────────────────────────────────────────
  Widget _buildStatusView() {
    if (_statusFiles.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Working tree clean',
        subtitle: 'Nothing to commit — your changes are up to date',
        iconColor: AppTheme.accentGreen,
        action: OutlinedButton.icon(
          onPressed: _pushRepo,
          icon: const Icon(
            Icons.upload_rounded,
            size: 16,
            color: AppTheme.accentBlue,
          ),
          label: Text(
            'Push to remote',
            style: GoogleFonts.inter(
              color: AppTheme.accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.accentBlue),
          ),
        ),
      );
    }

    final staged = _statusFiles
        .where(
          (f) =>
              (f['status'] ?? '').toString().toLowerCase().contains('staged'),
        )
        .toList();
    final unstaged = _statusFiles
        .where(
          (f) =>
              !(f['status'] ?? '').toString().toLowerCase().contains('staged'),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (staged.isNotEmpty) ...[
          _sectionHeader('Staged', staged.length, AppTheme.accentGreen),
          ...staged.map((f) => _buildStatusRow(f, isStaged: true)),
          const SizedBox(height: 4),
        ],
        if (unstaged.isNotEmpty) ...[
          _sectionHeader('Unstaged', unstaged.length, AppTheme.accentYellow),
          ...unstaged.map((f) => _buildStatusRow(f, isStaged: false)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionHeader(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(dynamic file, {required bool isStaged}) {
    final fileName = (file['path'] ?? 'Unknown').toString();
    final status = (file['status'] ?? 'unknown').toString();
    final statusColor = AppTheme.statusColor(status);
    final statusLabel = AppTheme.statusLabel(status);
    final parts = fileName.split('/');
    final baseName = parts.last;
    final dirName = parts.length > 1
        ? '${parts.sublist(0, parts.length - 1).join('/')}/'
        : '';

    return Slidable(
      key: ValueKey(fileName),
      startActionPane: isStaged
          ? ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (_) => _unstageFile(fileName),
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  icon: Icons.remove_circle_outline_rounded,
                  label: 'Unstage',
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ],
            )
          : ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (_) => _stageFile(fileName),
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Stage',
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ],
            ),
      endActionPane: isStaged
          ? null // No end action for staged (already handled by start pane)
          : ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (_) => _discardFile(fileName),
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  icon: Icons.restore_rounded,
                  label: 'Discard',
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ],
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: GlassCard(
          borderRadius: 12,
          padding: EdgeInsets.zero,
          accentBorder: statusColor,
          child: ListTile(
            dense: true,
            leading: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  statusLabel,
                  style: GoogleFonts.firaMono(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            title: RichText(
              text: TextSpan(
                children: [
                  if (dirName.isNotEmpty)
                    TextSpan(
                      text: dirName,
                      style: GoogleFonts.firaMono(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  TextSpan(
                    text: baseName,
                    style: GoogleFonts.firaMono(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              status,
              style: GoogleFonts.inter(color: statusColor, fontSize: 10),
            ),
            trailing: isStaged
                ? IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: AppTheme.accentOrange,
                    ),
                    tooltip: 'Unstage file',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _unstageFile(fileName),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: AppTheme.accentGreen,
                    ),
                    tooltip: 'Stage file',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _stageFile(fileName),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Not git repo ───────────────────────────────────────────────────────────────
  Widget _buildNotGitRepoView() {
    return EmptyState(
      icon: Icons.warning_amber_rounded,
      title: 'Not a Git Repository',
      subtitle:
          'This directory has no .git folder.\nInitialize it to start tracking.',
      iconColor: AppTheme.accentYellow,
      action: ElevatedButton.icon(
        onPressed: () async {
          setState(() => _isLoading = true);
          final result = await GitService.initRepository(widget.repoPath);
          if (result == 0) {
            _fetchData();
          } else {
            setState(() => _isLoading = false);
            _showSnack(
              'Failed to initialize (code: $result)',
              AppTheme.accentRed,
            );
          }
        },
        icon: const Icon(Icons.rocket_launch_rounded, size: 16),
        label: const Text('Initialize Repository'),
      ),
    );
  }
}
