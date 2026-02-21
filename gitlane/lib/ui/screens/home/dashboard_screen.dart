import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/git_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../commit/commit_graph_screen.dart';
import '../repository/repository_root_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _docsPath;
  String? _reposRootPath;
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
    final reposRoot = Directory('${dir.path}/gitlane_repositories');
    if (!reposRoot.existsSync()) {
      reposRoot.createSync(recursive: true);
    }

    if (!mounted) return;
    setState(() {
      _docsPath = dir.path;
      _reposRootPath = reposRoot.path;
    });

    await _loadReposFromDisk();
  }

  Future<void> _loadReposFromDisk() async {
    final rootPath = _reposRootPath;
    if (rootPath == null) return;

    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }

    final repos = <Map<String, String>>[];
    for (final entity in rootDir.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final gitDir = Directory('${entity.path}/.git');
      if (!gitDir.existsSync()) continue;

      final name = _basename(entity.path);
      repos.add({
        'title': name,
        'desc': 'Local repository',
        'path': entity.path,
      });
    }

    repos.sort(
      (a, b) => a['title']!.toLowerCase().compareTo(b['title']!.toLowerCase()),
    );

    if (!mounted) return;
    setState(() {
      _repos = repos;
      _initializing = false;
    });
  }

  String _basename(String path) {
    final parts = path.split(Platform.pathSeparator).where((p) => p.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  Future<void> _showGitActionDialog() async {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    await showDialog<void>(
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

              final path = '${_reposRootPath}/$name';
              int result;

              if (url.isNotEmpty) {
                result = await GitService.cloneRepository(url, path);
              } else {
                await Directory(path).create(recursive: true);
                result = await GitService.initRepository(path);
              }

              if (mounted) {
                if (result == 0) {
                  await _loadReposFromDisk();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed: code $result")),
                  );
                  setState(() => _initializing = false);
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _openGraphPicker() async {
    if (_repos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No repositories found')));
      return;
    }

    if (_repos.length == 1) {
      await _openGraphForRepo(_repos.first);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceSlate,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _repos.length,
            itemBuilder: (context, index) {
              final repo = _repos[index];
              return ListTile(
                leading: const Icon(Icons.folder, color: AppTheme.accentCyan),
                title: Text(repo['title']!),
                subtitle: Text(
                  repo['path']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openGraphForRepo(repo);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openGraphForRepo(Map<String, String> repo) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      ),
    );

    final logJson = await GitService.getCommitLog(repo['path']!);
    final nodes = _nodesFromLog(logJson);

    if (!mounted) return;
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CommitGraphScreen(commits: nodes, title: '${repo['title']} Graph'),
      ),
    );
  }

  List<CommitNode> _nodesFromLog(String? logJson) {
    if (logJson == null) return [];

    try {
      final decoded = jsonDecode(logJson);
      if (decoded is! List) return [];

      final nodes = <CommitNode>[];
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map<String, dynamic>) continue;

        final hash = (item['hash'] ?? '').toString();
        if (hash.isEmpty) continue;

        final nextHash = i + 1 < decoded.length
            ? ((decoded[i + 1] as Map<String, dynamic>)['hash'] ?? '')
                  .toString()
            : '';

        final unix = (item['time'] is num) ? (item['time'] as num).toInt() : 0;

        nodes.add(
          CommitNode(
            id: hash,
            parentIds: nextHash.isEmpty ? [] : [nextHash],
            message: (item['message'] ?? 'No message').toString(),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              unix * 1000,
              isUtc: true,
            ).toLocal(),
            lane: 0,
          ),
        );
      }

      return nodes;
    } catch (_) {
      return [];
    }
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
            onPressed: _openGraphPicker,
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
              padding: const EdgeInsets.all(16),
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
            else if (filteredRepos.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No repositories yet. Tap + to start.',
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
      padding: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 8),
                Text(
                  repo['path']!,
                  style: const TextStyle(
                    color: AppTheme.textDim,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
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
                title: const Text('Documents Storage'),
                subtitle: Text(_docsPath ?? 'Loading...'),
              ),
              ListTile(
                leading: const Icon(Icons.storage, color: AppTheme.accentCyan),
                title: const Text('Repositories Root'),
                subtitle: Text(_reposRootPath ?? 'Loading...'),
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: AppTheme.textDim),
                title: const Text('Refresh Repositories'),
                onTap: () {
                  Navigator.pop(context);
                  _loadReposFromDisk();
                },
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
