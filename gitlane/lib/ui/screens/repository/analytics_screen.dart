import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../../services/git_service.dart';

class ContributorAnalyticsScreen extends StatefulWidget {
  final String repoPath;
  const ContributorAnalyticsScreen({super.key, required this.repoPath});

  @override
  State<ContributorAnalyticsScreen> createState() => _ContributorAnalyticsScreenState();
}

class _ContributorAnalyticsScreenState extends State<ContributorAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, int> _counts = {};
  int _totalCommits = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final logJson = await GitService.getCommitLog(widget.repoPath);
      if (logJson == null) {
        setState(() => _isLoading = false);
        return;
      }

      final List<dynamic> commits = json.decode(logJson);
      final Map<String, int> counts = {};

      for (var c in commits) {
        final author = (c['author'] ?? 'Unknown').toString();
        counts[author] = (counts[author] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _counts = counts;
          _totalCommits = commits.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getAuthorColor(String name) {
    final colors = [
      AppTheme.accentCyan,
      AppTheme.accentGreen,
      AppTheme.accentPurple,
      AppTheme.accentOrange,
      AppTheme.accentYellow,
      AppTheme.accentBlue,
    ];
    return colors[name.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final sortedAuthors = _counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: Text(
          'Contributor Analytics',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _counts.isEmpty
              ? const EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No contributors found',
                  subtitle: 'Make some commits to see your contribution stats!',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildOverviewCard(),
                    const SizedBox(height: 24),
                    Text(
                      'CONTRIBUTORS',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...sortedAuthors.map((e) => _buildContributorRow(e.key, e.value)),
                  ],
                ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentCyan.withValues(alpha: 0.15),
            AppTheme.accentPurple.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Repository Pulse',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('Total Commits', _totalCommits.toString()),
              _buildStat('Authors', _counts.length.toString()),
              _buildStat('Health Status', 'Optimal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.firaMono(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildContributorRow(String name, int count) {
    final percent = _totalCommits > 0 ? count / _totalCommits : 0.0;
    final color = _getAuthorColor(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$count commits',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.firaMono(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppTheme.bg2,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
