import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../../services/git_service.dart';

class StashScreen extends StatefulWidget {
  final String repoPath;
  const StashScreen({super.key, required this.repoPath});

  @override
  State<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends State<StashScreen> {
  List<Map<String, dynamic>> _stashes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStashes();
  }

  Future<void> _loadStashes() async {
    setState(() => _isLoading = true);
    final list = await GitService.getStashes(widget.repoPath);
    if (mounted) {
      setState(() {
        _stashes = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _applyStash(int index) async {
    setState(() => _isLoading = true);
    final result = await GitService.stashApply(widget.repoPath, index);
    if (mounted) {
      _showSnack(
        result == 0 ? '✓ Changes applied' : 'Failed to apply stash ($result)',
        result == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
      );
      _loadStashes();
    }
  }

  Future<void> _popStash(int index) async {
    setState(() => _isLoading = true);
    final result = await GitService.stashPop(widget.repoPath, index);
    if (mounted) {
      _showSnack(
        result == 0 ? '✓ Stash applied' : 'Failed to pop stash ($result)',
        result == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
      );
      _loadStashes();
    }
  }

  Future<void> _dropStash(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drop Stash'),
        content: const Text('Are you sure you want to delete this stash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Drop', style: TextStyle(color: AppTheme.accentRed))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isLoading = true);
    final result = await GitService.stashDrop(widget.repoPath, index);
    if (mounted) {
      _showSnack(
        result == 0 ? '✓ Stash dropped' : 'Failed to drop stash ($result)',
        result == 0 ? AppTheme.accentGreen : AppTheme.accentRed,
      );
      _loadStashes();
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: Text(
          'Stashes',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadStashes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            )
          : _stashes.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No stashes',
              subtitle:
                  'Stash allows you to save WIP changes\nwithout committing them.',
              iconColor: AppTheme.accentOrange,
            )
          : ListView.separated(
              padding: EdgeInsets.all(compact ? 12 : 16),
              itemCount: _stashes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = _stashes[index];
                final hash = (s['hash'] ?? '').toString();
                final msg = (s['message'] ?? 'No message').toString();
                final rawIndex = s['index'];
                final stashIndex = rawIndex is int
                    ? rawIndex
                    : int.tryParse(rawIndex?.toString() ?? '') ?? index;

                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.bg1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(compact ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentOrange.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: AppTheme.accentOrange.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'stash@{$stashIndex}',
                                    style: GoogleFonts.firaMono(
                                      color: AppTheme.accentOrange,
                                      fontSize: compact ? 10 : 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (hash.length >= 7)
                                  Text(
                                    hash.substring(0, 7),
                                    style: GoogleFonts.firaMono(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              msg,
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: compact ? 13 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _StashAction(
                                icon: Icons.playlist_add_check_rounded,
                                label: 'Apply',
                                color: AppTheme.accentCyan,
                                onTap: () => _applyStash(stashIndex),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: AppTheme.border),
                            Expanded(
                              child: _StashAction(
                                icon: Icons.unarchive_rounded,
                                label: 'Pop',
                                color: AppTheme.accentGreen,
                                onTap: () => _popStash(stashIndex),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: AppTheme.border),
                            Expanded(
                              child: _StashAction(
                                icon: Icons.delete_outline_rounded,
                                label: 'Drop',
                                color: AppTheme.accentRed,
                                onTap: () => _dropStash(stashIndex),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _StashAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StashAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
