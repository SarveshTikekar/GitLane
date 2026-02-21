import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../repository/repository_root_screen.dart';
import '../../services/git_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitLane'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundBlack,
              AppTheme.primaryNavy.withOpacity(0.8),
              AppTheme.backgroundBlack,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search repositories...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textDim),
                  filled: true,
                  fillColor: AppTheme.surfaceSlate.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: AppTheme.textDim),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 1, // Let's show the current project as first repo
                itemBuilder: (context, index) {
                  return _buildRepoCard(context, index);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Placeholder for Init Repo
          final result = await GitService.initRepository('.');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result == 0 ? "Repo initialized!" : "Init failed")),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Repo'),
      ),
    );
  }

  Widget _buildRepoCard(BuildContext context, int index) {
    final titles = ['GitLane-Core'];
    final descs = ['Current native bridge and UI project'];
    final paths = ['.']; // Using current directory as sample

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RepositoryRootScreen(
                  repoName: titles[index],
                  repoPath: paths[index],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      titles[index],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textDim),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  descs[index],
                  style: const TextStyle(color: AppTheme.textDim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStat('main', Icons.account_tree_outlined),
                    const SizedBox(width: 16),
                    _buildStat('Active', Icons.bolt),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textDim),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textDim),
        ),
      ],
    );
  }
}
