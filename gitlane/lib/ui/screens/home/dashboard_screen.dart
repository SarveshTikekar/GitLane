import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../repository/repository_root_screen.dart';
import 'qr_scanner_dialog.dart';
import '../../../services/git_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _docsPath;
  List<Map<String, String>> _repos = [];
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    final dir = await getApplicationDocumentsDirectory();
    _docsPath = dir.path;
    _refreshRepos();
  }

  Future<void> _refreshRepos() async {
    if (_docsPath == null) return;
    
    final dir = Directory(_docsPath!);
    if (!dir.existsSync()) return;

    final List<Map<String, String>> updatedRepos = [];
    final entities = dir.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final isGit = Directory("${entity.path}${Platform.pathSeparator}.git").existsSync();
        
        if (isGit) {
          final branch = await GitService.getCurrentBranch(entity.path);
          updatedRepos.add({
            'title': name,
            'desc': 'Local Git Repository',
            'path': entity.path,
            'branch': branch,
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _repos = updatedRepos;
        _initializing = false;
      });
    }
  }

  void _showGitActionDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceSlate,
        title: const Text('New Repository', style: TextStyle(color: AppTheme.accentCyan)),
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Clone URL (optional)',
                      labelStyle: TextStyle(color: AppTheme.textDim),
                      hintText: 'https://github.com/...',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppTheme.accentCyan),
                  onPressed: () async {
                    final scannedUrl = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (context) => const QRScannerDialog()),
                    );
                    if (scannedUrl != null) {
                      urlController.text = scannedUrl;
                      // Auto-extract name if possible
                      if (nameController.text.isEmpty) {
                        final parts = scannedUrl.split('/');
                        if (parts.isNotEmpty) {
                          var name = parts.last;
                          if (name.endsWith('.git')) name = name.substring(0, name.length - 4);
                          nameController.text = name;
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
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
                  _refreshRepos();
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
      body: RefreshIndicator(
        onRefresh: _refreshRepos,
        child: Container(
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
              if (_initializing)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)))
              else if (_repos.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text("No repositories yet. Tap + to start.", 
                      style: TextStyle(color: AppTheme.textDim)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _repos.length,
                    itemBuilder: (context, index) {
                      return _buildRepoCard(context, index);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGitActionDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Repo'),
      ),
    );
  }

  Widget _buildRepoCard(BuildContext context, int index) {
    final repo = _repos[index];

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
                    _buildStat(repo['branch'] ?? 'main', Icons.account_tree_outlined),
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
