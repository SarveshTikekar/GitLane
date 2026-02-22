import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../../services/git_service.dart';
import '../commit/commit_detail_screen.dart';

class ReflogScreen extends StatefulWidget {
  final String repoPath;
  const ReflogScreen({super.key, required this.repoPath});

  @override
  State<ReflogScreen> createState() => _ReflogScreenState();
}

class _ReflogScreenState extends State<ReflogScreen> {
  List<dynamic> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReflog();
  }

  Future<void> _fetchReflog() async {
    setState(() => _isLoading = true);
    try {
      final jsonStr = await GitService.getReflog(widget.repoPath);
      final data = json.decode(jsonStr);
      if (!mounted) return;
      if (data is List) {
        setState(() {
          _entries = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _entries = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Map reflog action → icon + color
  (IconData, Color) _actionStyle(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('commit')) {
      return (Icons.commit_rounded, context.accentGreen);
    }
    if (m.contains('merge')) {
      return (Icons.merge_rounded, context.accentOrange);
    }
    if (m.contains('checkout') || m.contains('branch')) {
      return (Icons.account_tree_rounded, context.accentBlue);
    }
    if (m.contains('reset')) {
      return (Icons.restart_alt_rounded, context.accentRed);
    }
    if (m.contains('stash')) {
      return (Icons.inventory_2_outlined, context.accentOrange);
    }
    if (m.contains('rebase')) {
      return (Icons.rebase_edit, context.accentPurple);
    }
    return (Icons.history_toggle_off_rounded, context.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: context.bg0,
      appBar: AppBar(
        title: Text(
          'Action History',
          style: GoogleFonts.inter(
            color: context.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _fetchReflog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.accentCyan),
            )
          : _entries.isEmpty
          ? const EmptyState(
              icon: Icons.history_edu_rounded,
              title: 'No history found',
              subtitle: 'Reflog tracks all HEAD movements in this repository',
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: 8,
              ),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                if (entry is! Map) {
                  return const SizedBox.shrink();
                }
                final msg = (entry['msg'] ?? 'no message').toString();
                final id = (entry['id'] ?? 'unknown').toString();
                final (icon, color) = _actionStyle(msg);
                final isLast = index == _entries.length - 1;

                return InkWell(
                  onTap: () {
                    if (id != 'unknown' && id.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommitDetailScreen(
                            commitHash: id,
                            message: msg,
                            author: 'Git History',
                            repoPath: widget.repoPath,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline column
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: [
                            const SizedBox(height: 14),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(icon, size: 13, color: color),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 32,
                                color: context.border,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg,
                                style: GoogleFonts.inter(
                                  color: context.textPrimary,
                                  fontSize: compact ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.accentCyan.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      id.length > 7 ? id.substring(0, 7) : id,
                                      style: GoogleFonts.firaMono(
                                        color: context.accentCyan,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View Details',
                                    style: GoogleFonts.inter(
                                      color: context.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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