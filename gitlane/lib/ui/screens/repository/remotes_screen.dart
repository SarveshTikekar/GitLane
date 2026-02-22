import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/git_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class RemotesScreen extends StatefulWidget {
  final String repoPath;

  const RemotesScreen({super.key, required this.repoPath});

  @override
  State<RemotesScreen> createState() => _RemotesScreenState();
}

class _RemotesScreenState extends State<RemotesScreen> {
  List<Map<String, dynamic>> _remotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRemotes();
  }

  Future<void> _loadRemotes() async {
    setState(() => _isLoading = true);
    final list = await GitService.getRemotes(widget.repoPath);
    if (mounted) {
      setState(() {
        _remotes = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _addRemote() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bg2,
        title: Text('Add Remote', style: GoogleFonts.inter(color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Remote Name (e.g. upstream)',
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Remote URL',
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.accentPurple),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
      final code = await GitService.addRemote(widget.repoPath, nameController.text, urlController.text);
      if (mounted) {
        _showSnack(
          code == 0 ? '✓ Remote added' : 'Failed to add remote: $code',
          code == 0 ? context.accentGreen : context.accentRed,
        );
        _loadRemotes();
      }
    }
  }

  Future<void> _editRemote(String name, String currentUrl) async {
    final urlController = TextEditingController(text: currentUrl);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bg2,
        title: Text('Edit Remote: $name', style: GoogleFonts.inter(color: context.textPrimary)),
        content: TextField(
          controller: urlController,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: 'New URL',
            labelStyle: TextStyle(color: context.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.accentCyan),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && urlController.text.isNotEmpty) {
      final code = await GitService.setRemoteUrl(widget.repoPath, name, urlController.text);
      if (mounted) {
        _showSnack(
          code == 0 ? '✓ Remote URL updated' : 'Failed to update: $code',
          code == 0 ? context.accentGreen : context.accentRed,
        );
        _loadRemotes();
      }
    }
  }

  Future<void> _deleteRemote(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bg2,
        title: Text('Delete Remote', style: TextStyle(color: context.textPrimary)),
        content: Text('Are you sure you want to remove remote "$name"?', style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: context.accentRed)),
          ),
        ],
      ),
    );

    if (ok == true) {
      final code = await GitService.deleteRemote(widget.repoPath, name);
      if (mounted) {
        _showSnack(
          code == 0 ? '✓ Remote removed' : 'Failed to remove: $code',
          code == 0 ? context.accentGreen : context.accentRed,
        );
        _loadRemotes();
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Remotes Management"),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.accentCyan),
            onPressed: _addRemote,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accentCyan))
          : _remotes.isEmpty
              ? const EmptyState(
                  icon: Icons.rss_feed_rounded,
                  title: "No Remotes Found",
                  subtitle: "Add a remote to push or pull changes.",
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _remotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final remote = _remotes[index];
                    final name = remote['name'] ?? 'unknown';
                    final url = remote['url'] ?? '';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.bg1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.accentPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: context.accentPurple.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  name,
                                  style: GoogleFonts.firaMono(
                                    color: context.accentPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, size: 20, color: context.accentCyan),
                                onPressed: () => _editRemote(name, url),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 20, color: context.accentRed),
                                onPressed: () => _deleteRemote(name),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            url,
                            style: GoogleFonts.inter(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}