import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../repository/repository_root_screen.dart';
import '../commit/commit_graph_screen.dart';
import '../../../services/git_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _docsPath;
  List<Map<String, String>> _repos = [];
  String _searchQuery = '';
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _docsPath = dir.path;
      _repos = []; // Start fresh, no hardcoded entries
      _initializing = false;
    });
  }

  void _showGitActionDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceSlate,
        title: const Text(
          'New Repository',
          style: TextStyle(color: AppTheme.accentCyan),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Local Name',
                labelStyle: TextStyle(color: AppTheme.textDim),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Clone URL (optional)',
                labelStyle: TextStyle(color: AppTheme.textDim),
                hintText: 'https://github.com/user/repo.git',
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textDim),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              setState(() => _initializing = true);

              final path = '$_docsPath/$name';
              int result;

              if (url.isNotEmpty) {
                result = await GitService.cloneRepository(url, path);
              } else {
                await Directory(path).create(recursive: true);
                result = await GitService.initRepository(path);
              }

              if (mounted) {
                if (result == 0) {
                  setState(() {
                    _repos.add({
                      'title': name,
                      'desc': url.isNotEmpty
                          ? 'Cloned from $url'
                          : 'Local Git Repository',
                      'path': path,
                    });
                  });
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result == 0
                          ? "Success: $name established"
                          : "Failed: code $result",
                    ),
                  ),
                );
                setState(() => _initializing = false);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRepos = _repos.where((repo) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return repo['title']!.toLowerCase().contains(query) ||
          repo['desc']!.toLowerCase().contains(query) ||
          repo['path']!.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitLane'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Commit Graph',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommitGraphScreen(commits: demoCommits),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsSheet,
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
              AppTheme.primaryNavy.withValues(alpha: 0.8),
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
                  fillColor: AppTheme.surfaceSlate.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: AppTheme.textDim),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              ),
            ),
            if (_initializing)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                ),
              )
            else if (_repos.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "No repositories yet. Tap + to start.",
                    style: TextStyle(color: AppTheme.textDim),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredRepos.length,
                  itemBuilder: (context, index) {
                    return _buildRepoCard(context, filteredRepos[index]);
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGitActionDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Repo'),
      ),
    );
  }

  Widget _buildRepoCard(BuildContext context, Map<String, String> repo) {
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
                  repoName: repo['title']!,
                  repoPath: repo['path']!,
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
                      repo['title']!,
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
                  repo['desc']!,
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

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceSlate,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.folder_open,
                  color: AppTheme.accentCyan,
                ),
                title: const Text('Storage Location'),
                subtitle: Text(_docsPath ?? 'Loading...'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: AppTheme.textDim,
                ),
                title: const Text('About GitLane'),
                subtitle: const Text('Flutter + libgit2 client'),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: this.context,
                    applicationName: 'GitLane',
                    applicationVersion: '0.1.0',
                    applicationLegalese: 'GitLane Hackathon Build',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
