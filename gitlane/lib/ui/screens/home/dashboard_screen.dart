import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/empty_state.dart';
import '../repository/repository_root_screen.dart';
import '../../../services/git_service.dart';
import 'qr_scanner_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _docsPath;
  List<Map<String, dynamic>> _repos = [];
  List<Map<String, dynamic>> _filteredRepos = [];
  bool _initializing = true;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _searchController.addListener(_onSearchChanged);
    _initStorage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRepos = query.isEmpty
          ? List.from(_repos)
          : _repos
                .where(
                  (r) => (r['title']?.toString() ?? '').toLowerCase().contains(
                    query,
                  ),
                )
                .toList();
    });
  }

  Future<void> _initStorage() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    _docsPath = dir.path;
    await _refreshRepos();
  }

  Future<void> _refreshRepos() async {
    final docsPath = _docsPath;
    if (docsPath == null) return;
    setState(() => _initializing = true);

    final dir = Directory(docsPath);
    if (!dir.existsSync()) {
      setState(() => _initializing = false);
      return;
    }

    final List<Map<String, dynamic>> updatedRepos = [];
    final entities = dir.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final isGit = Directory(
          '${entity.path}${Platform.pathSeparator}.git',
        ).existsSync();

        if (isGit) {
          final branch = await GitService.getCurrentBranch(entity.path);
          final statusJson = await GitService.getRepositoryStatus(entity.path);
          final logJson = await GitService.getCommitLog(entity.path);

          // Parse status
          int modifiedCount = 0;
          int untrackedCount = 0;
          if (statusJson != null) {
            try {
              final parsed = _tryDecode(statusJson);
              final decoded = parsed is List ? parsed : const <dynamic>[];
              for (final f in decoded) {
                if (f is! Map) continue;
                final s = (f['status'] ?? '').toString().toLowerCase();
                if (s.contains('modified')) modifiedCount++;
                if (s.contains('untracked')) untrackedCount++;
              }
            } catch (_) {}
          }

          // Parse last commit
          String lastCommitMsg = '';
          String lastCommitTime = '';
          if (logJson != null) {
            try {
              final decoded = _tryDecode(logJson);
              if (decoded is List && decoded.isNotEmpty) {
                final first = decoded.first;
                if (first is Map) {
                  lastCommitMsg = (first['message'] ?? '').toString();
                  final ts = first['time'];
                  if (ts is num) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      ts.toInt() * 1000,
                      isUtc: true,
                    ).toLocal();
                    lastCommitTime = _relativeTime(dt);
                  }
                }
              }
            } catch (_) {}
          }

          updatedRepos.add({
            'title': name,
            'path': entity.path,
            'branch': branch,
            'modified': modifiedCount,
            'untracked': untrackedCount,
            'lastCommit': lastCommitMsg,
            'lastCommitTime': lastCommitTime,
            'isDirty': modifiedCount > 0 || untrackedCount > 0,
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _repos = updatedRepos;
        _filteredRepos = List.from(updatedRepos);
        _initializing = false;
      });
      _animController.forward(from: 0);
    }
  }

  dynamic _tryDecode(String json) {
    try {
      return jsonDecode(json);
    } catch (_) {
      try {
        return jsonDecode(Uri.decodeComponent(json));
      } catch (_) {
        return null;
      }
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  void _showNewRepoSheet() {
    final docsPath = _docsPath;
    if (docsPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage not initialized yet')),
      );
      return;
    }
    final maxSheetWidth = Responsive.maxContentWidth(
      MediaQuery.sizeOf(context).width,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.border),
      ),
      isScrollControlled: true,
      builder: (context) => _NewRepoSheet(
        docsPath: docsPath,
        onComplete: _refreshRepos,
        maxSheetWidth: maxSheetWidth,
      ),
    );
  }

  void _showQrScanner() {
    showDialog(context: context, builder: (context) => const QRScannerDialog());
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  int get _cleanCount => _repos.where((r) => !(r['isDirty'] as bool)).length;
  int get _dirtyCount => _repos.where((r) => r['isDirty'] as bool).length;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = Responsive.horizontalPadding(width);
    final maxContentWidth = Responsive.maxContentWidth(width);
    final compact = Responsive.isCompact(context);

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: RefreshIndicator(
        color: AppTheme.accentCyan,
        backgroundColor: AppTheme.bg2,
        onRefresh: _refreshRepos,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(
              compact: compact,
              horizontalPadding: horizontalPadding,
              maxContentWidth: maxContentWidth,
            ),
            SliverToBoxAdapter(
              child: _buildSearchBar(
                horizontalPadding: horizontalPadding,
                maxContentWidth: maxContentWidth,
              ),
            ),
            if (_initializing)
              _buildShimmerList(
                horizontalPadding: horizontalPadding,
                maxContentWidth: maxContentWidth,
              )
            else if (_filteredRepos.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              _buildRepoList(
                horizontalPadding: horizontalPadding,
                maxContentWidth: maxContentWidth,
              ),
            SliverToBoxAdapter(child: SizedBox(height: compact ? 88 : 100)),
          ],
        ),
      ),
      floatingActionButton: _docsPath == null
          ? null
          : compact
          ? FloatingActionButton(
              onPressed: _showNewRepoSheet,
              tooltip: 'New Repository',
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              onPressed: _showNewRepoSheet,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'New Repo',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
    );
  }

  // ── Sliver App Bar (hero header) ───────────────────────────────────────────
  Widget _buildSliverAppBar({
    required bool compact,
    required double horizontalPadding,
    required double maxContentWidth,
  }) {
    return SliverAppBar(
      expandedHeight: compact ? 188 : 168,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.bg0,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan QR to Clone',
          onPressed: _showQrScanner,
          color: AppTheme.textSecondary,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: _refreshRepos,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1117), Color(0xFF161B22)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    compact ? 14 : 16,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo row
                      Row(
                        children: [
                          Container(
                            width: compact ? 30 : 32,
                            height: compact ? 30 : 32,
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.accentCyan.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.merge_type_rounded,
                              color: AppTheme.accentCyan,
                              size: compact ? 17 : 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'GitLane',
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: compact ? 20 : 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.accentGreen.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              'v1.0',
                              style: GoogleFonts.firaMono(
                                color: AppTheme.accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!_initializing)
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _buildStatChip(
                              '${_repos.length}',
                              'repos',
                              Icons.folder_rounded,
                              AppTheme.accentBlue,
                            ),
                            _buildStatChip(
                              '$_cleanCount',
                              'clean',
                              Icons.check_circle_rounded,
                              AppTheme.accentGreen,
                            ),
                            if (_dirtyCount > 0)
                              _buildStatChip(
                                '$_dirtyCount',
                                'dirty',
                                Icons.edit_rounded,
                                AppTheme.accentYellow,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    String count,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar({
    required double horizontalPadding,
    required double maxContentWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            4,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) {},
            style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search repositories…',
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppTheme.textSecondary,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filteredRepos = List.from(_repos));
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // ── Shimmer loading ────────────────────────────────────────────────────────
  Widget _buildShimmerList({
    required double horizontalPadding,
    required double maxContentWidth,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Shimmer.fromColors(
              baseColor: AppTheme.bg1,
              highlightColor: AppTheme.bg2,
              child: ShimmerCard(
                height: 130,
                margin: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  0,
                ),
              ),
            ),
          ),
        ),
        childCount: 4,
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'No repositories match "${_searchController.text}"',
        iconColor: AppTheme.textSecondary,
      );
    }
    return EmptyState(
      icon: Icons.folder_special_rounded,
      title: 'No repositories yet',
      subtitle:
          'Clone a remote repository or initialize a new one to get started.',
      action: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showNewRepoSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Clone or Init Repository'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showQrScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan QR Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Repo list ──────────────────────────────────────────────────────────────
  Widget _buildRepoList({
    required double horizontalPadding,
    required double maxContentWidth,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final repo = _filteredRepos[index];
          return AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final delay = index * 0.1;
              final animation = CurvedAnimation(
                parent: _animController,
                curve: Interval(
                  delay.clamp(0, 0.9),
                  (delay + 0.4).clamp(0, 1.0),
                  curve: Curves.easeOut,
                ),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    12,
                  ),
                  child: _RepoCard(
                    repo: repo,
                    onOpen: () => _openRepo(repo),
                    onPull: () => _quickPull(repo),
                  ),
                ),
              ),
            ),
          );
        }, childCount: _filteredRepos.length),
      ),
    );
  }

  void _openRepo(Map<String, dynamic> repo) {
    HapticFeedback.lightImpact();
    final repoName = (repo['title'] ?? 'Repository').toString();
    final repoPath = (repo['path'] ?? '').toString();
    if (repoPath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid repository path')));
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RepositoryRootScreen(repoName: repoName, repoPath: repoPath),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ).then((_) => _refreshRepos());
  }

  Future<void> _quickPull(Map<String, dynamic> repo) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pulling ${(repo['title'] ?? 'repository').toString()}…',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );
    // Pull without token shows credential dialog — just refresh for now
    await _refreshRepos();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open the repo to pull with credentials')),
      );
    }
  }
}

// ── Repo Card ────────────────────────────────────────────────────────────────
class _RepoCard extends StatelessWidget {
  final Map<String, dynamic> repo;
  final VoidCallback onOpen;
  final VoidCallback onPull;

  const _RepoCard({
    required this.repo,
    required this.onOpen,
    required this.onPull,
  });

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final branch = (repo['branch'] ?? 'main').toString();
    final modified = repo['modified'] as int? ?? 0;
    final untracked = repo['untracked'] as int? ?? 0;
    final isDirty = repo['isDirty'] as bool? ?? false;
    final lastCommit = (repo['lastCommit'] ?? '').toString();
    final lastCommitTime = (repo['lastCommitTime'] ?? '').toString();
    final title = (repo['title'] ?? 'Repository').toString();
    final dirtyLabel = [
      if (modified > 0) '${modified}M',
      if (untracked > 0) '${untracked}U',
    ].join(' ');

    final statusColor = isDirty ? AppTheme.accentYellow : AppTheme.accentGreen;
    final branchColor = (branch == 'main' || branch == 'master')
        ? AppTheme.accentGreen
        : AppTheme.accentBlue;

    return GlassCard(
      accentBorder: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: name + branch + status ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      size: compact ? 15 : 16,
                      color: branchColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      label: isDirty
                          ? (dirtyLabel.isEmpty ? 'dirty' : dirtyLabel)
                          : '✓ clean',
                      color: isDirty
                          ? AppTheme.accentYellow
                          : AppTheme.accentGreen,
                      icon: isDirty ? Icons.edit_rounded : Icons.check_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BranchChip(branch: branch, color: branchColor),
                      if (lastCommit.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          lastCommit,
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lastCommitTime.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              lastCommitTime,
                              style: GoogleFonts.inter(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ],
                  )
                else
                  Row(
                    children: [
                      _BranchChip(branch: branch, color: branchColor),
                      if (lastCommit.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lastCommit,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastCommitTime.isNotEmpty)
                          Text(
                            lastCommitTime,
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          const Divider(height: 1, color: AppTheme.border),

          // ── Action row: Open | Pull | status badge ────────────────────────
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Open',
                    color: AppTheme.accentCyan,
                    onTap: onOpen,
                  ),
                ),
                Container(width: 1, color: AppTheme.border),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.download_rounded,
                    label: 'Pull',
                    color: AppTheme.textSecondary,
                    onTap: onPull,
                  ),
                ),
                Container(width: 1, color: AppTheme.border),
                Expanded(
                  child: _ActionButton(
                    icon: isDirty
                        ? Icons.circle_notifications_rounded
                        : Icons.check_circle_rounded,
                    label: isDirty
                        ? compact
                              ? '${modified + untracked} chg'
                              : '${modified + untracked} changes'
                        : 'Clean',
                    color: statusColor,
                    onTap: onOpen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.branch, required this.color});

  final String branch;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_rounded, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            branch,
            style: GoogleFonts.firaMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.firaMono(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── New Repo Bottom Sheet ────────────────────────────────────────────────────
class _NewRepoSheet extends StatefulWidget {
  final String docsPath;
  final VoidCallback onComplete;
  final double maxSheetWidth;

  const _NewRepoSheet({
    required this.docsPath,
    required this.onComplete,
    required this.maxSheetWidth,
  });

  @override
  State<_NewRepoSheet> createState() => _NewRepoSheetState();
}

class _NewRepoSheetState extends State<_NewRepoSheet> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Repository name is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final path = '${widget.docsPath}/$name';
    int result;

    if (url.isNotEmpty) {
      result = await GitService.cloneRepository(url, path);
    } else {
      await Directory(path).create(recursive: true);
      result = await GitService.initRepository(path);
    }

    if (mounted) {
      if (result == 0) {
        Navigator.pop(context);
        widget.onComplete();
      } else {
        setState(() {
          _isLoading = false;
          _error = url.isNotEmpty
              ? 'Clone failed (code: $result). Check the URL and try again.'
              : 'Init failed (code: $result).';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final stackActions = width < 420;
    final horizontalPadding = Responsive.horizontalPadding(width);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 8,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxSheetWidth),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'New Repository',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: compact ? 17 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clone a remote repo or initialize an empty local one',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Repository Name',
                      prefixIcon: Icon(Icons.folder_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.firaMono(
                      color: AppTheme.textPrimary,
                      fontSize: compact ? 12 : 13,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Clone URL (optional)',
                      hintText: 'https://github.com/user/repo.git',
                      prefixIcon: Icon(Icons.link_rounded, size: 18),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: AppTheme.accentRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              color: AppTheme.accentRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (stackActions)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(
                                    Icons.rocket_launch_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              _urlController.text.trim().isNotEmpty
                                  ? 'Clone'
                                  : 'Initialize',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(
                                    Icons.rocket_launch_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              _urlController.text.trim().isNotEmpty
                                  ? 'Clone'
                                  : 'Initialize',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
