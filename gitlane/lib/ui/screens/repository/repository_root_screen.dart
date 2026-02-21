import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/git_service.dart';
import '../../theme/app_theme.dart';
import '../commit/commit_detail_screen.dart';
import '../commit/commit_graph_screen.dart';

class RepositoryRootScreen extends StatefulWidget {
  final String repoName;
  final String repoPath;

  const RepositoryRootScreen({
    super.key,
    required this.repoName,
    required this.repoPath,
  });

  @override
  State<RepositoryRootScreen> createState() => _RepositoryRootScreenState();
}

class _RepositoryRootScreenState extends State<RepositoryRootScreen> {
  int _selectedIndex = 0;
  List<dynamic> _commits = [];
  bool _isLoading = false;
  bool _isNotGitRepo = false;

  List<dynamic> _statusFiles = [];

  String _currentRelativePath = '';
  final List<String> _pathStack = [];
  List<_ExplorerEntry> _entries = [];
  bool _isExplorerLoading = false;
  String _explorerQuery = '';
  String? _explorerError;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadCurrentDirectory();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final logJson = await GitService.getCommitLog(widget.repoPath);
    final statusJson = await GitService.getRepositoryStatus(widget.repoPath);

    if (!mounted) return;

    setState(() {
      if (logJson == null && statusJson == null) {
        _isNotGitRepo = true;
        _commits = [];
        _statusFiles = [];
      } else {
        _isNotGitRepo = false;

        if (logJson != null) {
          try {
            final decodedLog = jsonDecode(logJson);
            if (decodedLog is List) {
              _commits = decodedLog;
            } else {
              _commits = [];
            }
          } catch (_) {
            _commits = [];
          }
        }

        if (statusJson != null) {
          try {
            final decodedStatus = jsonDecode(statusJson);
            if (decodedStatus is List) {
              _statusFiles = decodedStatus;
            } else {
              _statusFiles = [];
            }
          } catch (_) {
            _statusFiles = [];
          }
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentDirectory() async {
    final targetPath = _absolutePathFor(_currentRelativePath);

    setState(() {
      _isExplorerLoading = true;
      _explorerError = null;
    });

    try {
      final dir = Directory(targetPath);
      if (!dir.existsSync()) {
        throw FileSystemException('Directory does not exist', targetPath);
      }

      final children = dir.listSync(followLinks: false);
      final entries = <_ExplorerEntry>[];

      for (final entity in children) {
        final lastSegment = entity.path.split(Platform.pathSeparator).last;
        if (lastSegment.isEmpty || lastSegment == '.git') {
          continue;
        }

        final isDirectory = entity is Directory;
        final relativePath = _currentRelativePath.isEmpty
            ? lastSegment
            : '$_currentRelativePath/$lastSegment';

        entries.add(
          _ExplorerEntry(
            name: lastSegment,
            relativePath: relativePath,
            isDirectory: isDirectory,
          ),
        );
      }

      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isExplorerLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExplorerLoading = false;
        _explorerError = e.toString();
      });
    }
  }

  String _absolutePathFor(String relativePath) {
    if (relativePath.isEmpty) return widget.repoPath;
    return '${widget.repoPath}/$relativePath';
  }

  Future<void> _openDirectory(_ExplorerEntry entry) async {
    _pathStack.add(_currentRelativePath);
    _currentRelativePath = entry.relativePath;
    await _loadCurrentDirectory();
  }

  Future<void> _goToParentDirectory() async {
    if (_pathStack.isEmpty) return;
    _currentRelativePath = _pathStack.removeLast();
    await _loadCurrentDirectory();
  }

  String _displayPath() {
    if (_currentRelativePath.isEmpty) return '/';
    return '/$_currentRelativePath';
  }

  String _formatCommitTime(dynamic unixSeconds) {
    if (unixSeconds is! num) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds.toInt() * 1000,
      isUtc: true,
    ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  List<CommitNode> _graphNodesFromCommits() {
    if (_commits.isEmpty) return demoCommits;

    final nodes = <CommitNode>[];
    for (var i = 0; i < _commits.length; i++) {
      final current = _commits[i] as Map<String, dynamic>;
      final hash = (current['hash'] ?? '').toString();
      if (hash.isEmpty) continue;

      final parent = i + 1 < _commits.length
          ? ((_commits[i + 1] as Map<String, dynamic>)['hash'] ?? '').toString()
          : '';

      nodes.add(
        CommitNode(
          id: hash,
          parentIds: parent.isEmpty ? [] : [parent],
          message: (current['message'] ?? 'No message').toString(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (((current['time'] as num?)?.toInt() ?? 0) * 1000),
            isUtc: true,
          ).toLocal(),
          lane: 0,
        ),
      );
    }

    return nodes.isEmpty ? demoCommits : nodes;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !(_selectedIndex == 0 && _pathStack.isNotEmpty),
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _selectedIndex == 0 && _pathStack.isNotEmpty) {
          await _goToParentDirectory();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.repoName),
              Text(
                widget.repoPath,
                style: const TextStyle(fontSize: 10, color: AppTheme.textDim),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _fetchData();
                await _loadCurrentDirectory();
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_tree_outlined),
              tooltip: 'Commit Graph',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommitGraphScreen(
                      commits: _graphNodesFromCommits(),
                      title: '${widget.repoName} Graph',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentCyan),
              )
            : _isNotGitRepo
            ? _buildNotGitRepoView()
            : IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildExplorerView(),
                  _buildHistoryView(),
                  _buildStatusView(),
                ],
              ),
        bottomNavigationBar: _isNotGitRepo
            ? null
            : BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) => setState(() => _selectedIndex = index),
                backgroundColor: AppTheme.surfaceSlate,
                selectedItemColor: AppTheme.accentCyan,
                unselectedItemColor: AppTheme.textDim,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.folder_outlined),
                    activeIcon: Icon(Icons.folder),
                    label: 'Explorer',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history_outlined),
                    activeIcon: Icon(Icons.history),
                    label: 'History',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.check_circle_outline),
                    activeIcon: Icon(Icons.check_circle),
                    label: 'Status',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildExplorerView() {
    final filteredEntries = _entries.where((entry) {
      if (_explorerQuery.isEmpty) return true;
      return entry.name.toLowerCase().contains(_explorerQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search files/folders in current directory',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textDim),
              filled: true,
              fillColor: AppTheme.surfaceSlate.withValues(alpha: 0.55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _explorerQuery = value.trim()),
          ),
        ),
        ListTile(
          dense: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: _pathStack.isEmpty ? AppTheme.textDim : AppTheme.accentCyan,
            onPressed: _pathStack.isEmpty ? null : _goToParentDirectory,
            tooltip: 'Go to parent directory',
          ),
          title: Text(
            _displayPath(),
            style: const TextStyle(
              color: AppTheme.textDim,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadCurrentDirectory,
          ),
        ),
        if (_isExplorerLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            ),
          )
        else if (_explorerError != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Explorer failed: $_explorerError',
                  style: const TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else if (filteredEntries.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No files or folders here',
                style: TextStyle(color: AppTheme.textDim),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: filteredEntries.length,
              itemBuilder: (context, index) {
                final item = filteredEntries[index];
                return ListTile(
                  leading: Icon(
                    item.isDirectory
                        ? Icons.folder
                        : Icons.description_outlined,
                    color: item.isDirectory
                        ? AppTheme.accentCyan
                        : AppTheme.textDim,
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    item.isDirectory ? 'Directory' : 'File',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textDim,
                    ),
                  ),
                  trailing: Icon(
                    item.isDirectory ? Icons.chevron_right : Icons.open_in_new,
                    size: 16,
                    color: AppTheme.textDim,
                  ),
                  onTap: () async {
                    if (item.isDirectory) {
                      await _openDirectory(item);
                      return;
                    }

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _FileViewerScreen(
                          filePath: _absolutePathFor(item.relativePath),
                          relativePath: item.relativePath,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }
    if (_commits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppTheme.textDim),
            SizedBox(height: 16),
            Text('No commits found', style: TextStyle(color: AppTheme.textDim)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _commits.length,
      itemBuilder: (context, index) {
        return _buildCommitItem(index);
      },
    );
  }

  Widget _buildCommitItem(int index) {
    final commit = _commits[index] as Map<String, dynamic>;
    final hash = (commit['hash'] ?? '0000000').toString();
    final msg = (commit['message'] ?? 'No message').toString();
    final author = (commit['author'] ?? 'Unknown').toString();
    final date = _formatCommitTime(commit['time']);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommitDetailScreen(
              commitHash: hash,
              message: msg,
              repoPath: widget.repoPath,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentCyan,
                    shape: BoxShape.circle,
                  ),
                ),
                if (index < _commits.length - 1)
                  Container(
                    width: 2,
                    height: 50,
                    color: AppTheme.textDim.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hash.length > 7 ? hash.substring(0, 7) : hash,
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }
    if (_statusFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppTheme.accentCyan,
            ),
            SizedBox(height: 16),
            Text('Worktree clean', style: TextStyle(color: AppTheme.textDim)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _statusFiles.length,
      itemBuilder: (context, index) {
        final file = _statusFiles[index] as Map<String, dynamic>;
        final fileName = (file['path'] ?? 'Unknown').toString();
        final status = (file['status'] ?? 'unknown').toString();

        return ListTile(
          leading: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
          title: Text(fileName),
          subtitle: Text(
            status,
            style: const TextStyle(fontSize: 10, color: AppTheme.textDim),
          ),
          trailing: status.contains('untracked') || status.contains('modified')
              ? IconButton(
                  icon: const Icon(
                    Icons.add,
                    color: AppTheme.accentCyan,
                    size: 20,
                  ),
                  onPressed: () async {
                    await GitService.gitAddFile(widget.repoPath, fileName);
                    await _fetchData();
                  },
                )
              : const Icon(Icons.check, color: Colors.green, size: 16),
        );
      },
    );
  }

  Widget _buildNotGitRepoView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Text(
            'Not a Git Repository',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This directory does not contain a valid .git folder.',
            style: TextStyle(color: AppTheme.textDim),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              setState(() => _isLoading = true);
              final result = await GitService.initRepository(widget.repoPath);
              if (result == 0) {
                await _fetchData();
                await _loadCurrentDirectory();
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to initialize repository (code: $result)',
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Initialize Repository',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('new')) return Icons.add_box_outlined;
    if (status.contains('modified')) return Icons.edit_note;
    if (status.contains('deleted')) return Icons.delete_outline;
    return Icons.help_outline;
  }

  Color _getStatusColor(String status) {
    if (status.contains('staged')) return Colors.green;
    if (status.contains('modified')) return Colors.orange;
    if (status.contains('untracked')) return AppTheme.accentCyan;
    return AppTheme.textDim;
  }
}

class _ExplorerEntry {
  const _ExplorerEntry({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
  });

  final String name;
  final String relativePath;
  final bool isDirectory;
}

class _FileViewerScreen extends StatefulWidget {
  const _FileViewerScreen({required this.filePath, required this.relativePath});

  final String filePath;
  final String relativePath;

  @override
  State<_FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<_FileViewerScreen> {
  String _content = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _readFile();
  }

  Future<void> _readFile() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open file: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.relativePath)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _content.isEmpty ? '(empty file)' : _content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppTheme.textLight,
                ),
              ),
            ),
    );
  }
}
