import 'package:flutter/material.dart';
import '../../../services/collaboration_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class CollaborationDashboard extends StatefulWidget {
  final String repoPath;
  const CollaborationDashboard({super.key, required this.repoPath});

  @override
  State<CollaborationDashboard> createState() => _CollaborationDashboardState();
}

class _CollaborationDashboardState extends State<CollaborationDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PullRequest> _prs = [];
  List<Issue> _issues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      CollaborationService.fetchPullRequests(widget.repoPath),
      CollaborationService.fetchIssues(widget.repoPath),
    ]);
    setState(() {
      _prs = results[0] as List<PullRequest>;
      _issues = results[1] as List<Issue>;
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg0,
      appBar: AppBar(
        title: const Text("Collaboration"),
        backgroundColor: context.bg0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.accentCyan,
          tabs: [
            Tab(text: "Pull Requests (${_prs.length})"),
            Tab(text: "Issues (${_issues.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accentCyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPRList(),
                _buildIssueList(),
              ],
            ),
    );
  }

  Widget _buildPRList() {
    if (_prs.isEmpty) return _buildEmpty("No Pull Requests found");
    return ListView.builder(
      itemCount: _prs.length,
      itemBuilder: (context, index) => _buildPRTile(_prs[index]),
    );
  }

  Widget _buildIssueList() {
    if (_issues.isEmpty) return _buildEmpty("No Issues found");
    return ListView.builder(
      itemCount: _issues.length,
      itemBuilder: (context, index) => _buildIssueTile(_issues[index]),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.social_distance_rounded, size: 48, color: context.textMuted),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.inter(color: context.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPRTile(PullRequest pr) {
    final statusColor = pr.state == 'open' ? context.accentGreen : context.accentPurple;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      accentBorder: statusColor,
      child: ListTile(
        onTap: () => _launchUrl(pr.url),
        title: Text(pr.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusBadge(pr.state),
                const SizedBox(width: 8),
                Text("#${pr.number} by ${pr.author}", style: GoogleFonts.inter(color: context.textSecondary, fontSize: 12)),
              ],
            ),
            if (pr.labels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: pr.labels.map((l) => _buildLabel(l)).toList(),
              ),
            ],
          ],
        ),
        trailing: Icon(Icons.open_in_new_rounded, size: 16, color: context.textMuted),
      ),
    );
  }

  Widget _buildIssueTile(Issue issue) {
    final statusColor = issue.state == 'open' ? context.accentGreen : context.accentPurple;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      accentBorder: statusColor,
      child: ListTile(
        onTap: () => _launchUrl(issue.url),
        title: Text(issue.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusBadge(issue.state),
                const SizedBox(width: 8),
                Text("#${issue.number} by ${issue.author}", style: GoogleFonts.inter(color: context.textSecondary, fontSize: 12)),
              ],
            ),
            if (issue.labels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: issue.labels.map((l) => _buildLabel(l)).toList(),
              ),
            ],
          ],
        ),
        trailing: Icon(Icons.open_in_new_rounded, size: 16, color: context.textMuted),
      ),
    );
  }

  Widget _buildStatusBadge(String state) {
    Color color = context.textMuted;
    if (state == 'open') color = context.accentGreen;
    if (state == 'closed' || state == 'merged') color = context.accentPurple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(state.toUpperCase(), style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.textMuted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: GoogleFonts.inter(color: context.textSecondary, fontSize: 10)),
    );
  }
}