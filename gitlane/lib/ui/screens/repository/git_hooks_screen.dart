import 'package:flutter/material.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'file_editor_screen.dart';

/* ─────────────────────────────────────────────────────────────────────────────
 * Git Hooks Management Dashboard
 * Lets the user view, enable/disable, create, and edit Git hooks directly
 * inside GitLane without leaving the app.
 * ───────────────────────────────────────────────────────────────────────────── */

// All standard Git hooks with helpful descriptions
const _kHooks = [
  {
    'name': 'pre-commit',
    'phase': 'Commit',
    'description': 'Runs before a commit is made. Ideal for lint / test checks.',
    'defaultScript': '#!/bin/sh\n# Run your checks here\n# Example: flutter analyze\n# exit 1 on failure to abort the commit\n',
  },
  {
    'name': 'commit-msg',
    'phase': 'Commit',
    'description': 'Validates the commit message. Receives message file as \$1.',
    'defaultScript': '#!/bin/sh\n# Validate the commit message\nMSG=\$(cat "\$1")\nif [ -z "\$MSG" ]; then\n  echo "Commit message must not be empty"\n  exit 1\nfi\n',
  },
  {
    'name': 'post-commit',
    'phase': 'Commit',
    'description': 'Runs after a commit. Good for notifications.',
    'defaultScript': '#!/bin/sh\n# Notify or trigger post-commit actions\necho "Committed successfully!"\n',
  },
  {
    'name': 'pre-push',
    'phase': 'Remote',
    'description': 'Runs before push. Block push on test failure.',
    'defaultScript': '#!/bin/sh\n# Block push if tests fail\necho "Running pre-push checks..."\n# exit 1 to abort push\n',
  },
  {
    'name': 'pre-rebase',
    'phase': 'Rebase',
    'description': 'Runs before a rebase. Can abort the rebase.',
    'defaultScript': '#!/bin/sh\necho "Starting rebase..."\n',
  },
  {
    'name': 'post-merge',
    'phase': 'Merge',
    'description': 'Runs after a successful merge.',
    'defaultScript': '#!/bin/sh\necho "Merge completed."\n',
  },
  {
    'name': 'post-checkout',
    'phase': 'Checkout',
    'description': 'Runs after checkout. Useful for environment setup.',
    'defaultScript': '#!/bin/sh\necho "Checked out to \$(git branch --show-current)"\n',
  },
  {
    'name': 'post-rewrite',
    'phase': 'Rebase',
    'description': 'Runs after commit amendments or rebases.',
    'defaultScript': '#!/bin/sh\necho "History rewritten."\n',
  },
];

class GitHooksScreen extends StatefulWidget {
  final String repoPath;
  const GitHooksScreen({super.key, required this.repoPath});

  @override
  State<GitHooksScreen> createState() => _GitHooksScreenState();
}

class _GitHooksScreenState extends State<GitHooksScreen> {
  final Map<String, bool> _hookStatus = {};
  bool _isLoading = true;

  String get _hooksDir => '${widget.repoPath}${Platform.pathSeparator}.git${Platform.pathSeparator}hooks';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    for (final hook in _kHooks) {
      final name = hook['name']!;
      final f = File('$_hooksDir${Platform.pathSeparator}$name');
      final disabled = File('$_hooksDir${Platform.pathSeparator}$name.disabled');
      _hookStatus[name] = f.existsSync(); // true = exists & active
      if (disabled.existsSync() && !f.existsSync()) _hookStatus[name] = false;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleHook(String name, bool enable) async {
    final active = File('$_hooksDir${Platform.pathSeparator}$name');
    final disabled = File('$_hooksDir${Platform.pathSeparator}$name.disabled');

    if (enable) {
      if (disabled.existsSync()) {
        await disabled.rename(active.path);
      } else {
        // Create a default hook
        final hook = _kHooks.firstWhere((h) => h['name'] == name);
        await active.writeAsString(hook['defaultScript']!);
      }
    } else {
      if (active.existsSync()) {
        await active.rename(disabled.path);
      }
    }
    _refresh();
  }

  Future<void> _createHook(String name) async {
    final hook = _kHooks.firstWhere((h) => h['name'] == name);
    final f = File('$_hooksDir${Platform.pathSeparator}$name');
    await f.writeAsString(hook['defaultScript']!);
    _refresh();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FileEditorScreen(
            filePath: f.path,
            fileName: name,
            repoPath: widget.repoPath,
          ),
        ),
      ).then((_) => _refresh());
    }
  }

  Future<void> _editHook(String name) async {
    final f = File('$_hooksDir${Platform.pathSeparator}$name');
    if (!f.existsSync()) {
      await _createHook(name);
      return;
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FileEditorScreen(
            filePath: f.path,
            fileName: name,
            repoPath: widget.repoPath,
          ),
        ),
      ).then((_) => _refresh());
    }
  }

  Future<void> _deleteHook(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        title: Text('Delete $name?', style: const TextStyle(color: Colors.white)),
        content: Text('This will permanently remove the $name hook script.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      File('$_hooksDir${Platform.pathSeparator}$name').deleteSync();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group hooks by phase
    final phases = _kHooks.map((h) => h['phase']!).toSet().toList();

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: const Text('Git Hooks'),
        backgroundColor: AppTheme.bg0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _buildHeader(),
                for (final phase in phases) ...[
                  _sectionHeader(phase),
                  ..._kHooks
                      .where((h) => h['phase'] == phase)
                      .map((h) => _buildHookTile(h)),
                ],
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.webhook_rounded, color: AppTheme.accentCyan, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Manage lifecycle scripts that run automatically during Git operations.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String phase) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        phase.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppTheme.accentCyan,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHookTile(Map<String, String> hook) {
    final name = hook['name']!;
    final active = _hookStatus[name] ?? false;
    final exists = File('$_hooksDir${Platform.pathSeparator}$name').existsSync();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (active ? AppTheme.accentGreen : AppTheme.textMuted).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            active ? Icons.webhook_rounded : Icons.code_off_rounded,
            size: 18,
            color: active ? AppTheme.accentGreen : AppTheme.textMuted,
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hook['description']!,
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
          maxLines: 2,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exists) ...[
              IconButton(
                icon: Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentCyan),
                tooltip: 'Edit',
                onPressed: () => _editHook(name),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'Delete',
                onPressed: () => _deleteHook(name),
              ),
            ],
            Switch(
              value: active,
              activeColor: AppTheme.accentGreen,
              onChanged: (val) {
                if (!exists && val) {
                  _createHook(name);
                } else {
                  _toggleHook(name, val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}