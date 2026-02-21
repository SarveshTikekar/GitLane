import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import '../commit/commit_detail_screen.dart';
import 'merge_conflict_screen.dart';

class RepositoryRootScreen extends StatefulWidget {
  final String repoName;
  final String repoPath;
  const RepositoryRootScreen({super.key, required this.repoName, required this.repoPath});

  @override
  State<RepositoryRootScreen> createState() => _RepositoryRootScreenState();
}

class _RepositoryRootScreenState extends State<RepositoryRootScreen> {
  int _selectedIndex = 0;
  List<dynamic> _commits = [];
  String? _repoStatus;
  bool _isLoading = false;
  bool _isNotGitRepo = false;

  List<dynamic> _statusFiles = [];
  bool _isStatusLoading = false;
  
  String _currentBranch = "HEAD";
  List<String> _branches = [];

  List<FileSystemEntity> _currentFiles = [];
  String _currentDir = "";

  @override
  void initState() {
    super.initState();
    _currentDir = widget.repoPath;
    _fetchData();
    _listRepoFiles();
  }

  void _listRepoFiles() {
    try {
      final dir = Directory(_currentDir);
      if (dir.existsSync()) {
        setState(() {
          // List files and directories, excluding the .git folder
          _currentFiles = dir.listSync().where((entity) {
            final name = entity.path.split(Platform.pathSeparator).last;
            return name != ".git";
          }).toList();
          
          // Sort: Directories first, then alphabetical
          _currentFiles.sort((a, b) {
            if (a is Directory && b is File) return -1;
            if (a is File && b is Directory) return 1;
            return a.path.split(Platform.pathSeparator).last.toLowerCase()
                .compareTo(b.path.split(Platform.pathSeparator).last.toLowerCase());
          });
        });
      }
    } catch (e) {
      debugPrint("Error listing files: $e");
    }
  }

  void _onItemTapped(FileSystemEntity entity) {
    if (entity is Directory) {
      setState(() {
        _currentDir = entity.path;
        _listRepoFiles();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selected: ${entity.path.split(Platform.pathSeparator).last}")),
      );
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    final logJson = await GitService.getCommitLog(widget.repoPath);
    final statusJson = await GitService.getRepositoryStatus(widget.repoPath);

    if (mounted) {
      setState(() {
        if (logJson == null && statusJson == null) {
          _isNotGitRepo = true;
        } else {
          _isNotGitRepo = false;
          
          if (logJson != null) {
            try {
              final decodedLog = jsonDecode(logJson);
              if (decodedLog is List) {
                _commits = decodedLog;
              } else if (decodedLog is Map && decodedLog.containsKey('error')) {
                debugPrint("Bridge error: ${decodedLog['error']}");
                _commits = [];
              }
            } catch (e) {
              debugPrint("Parsing log error: $e");
            }
          }

          if (statusJson != null) {
            try {
              final decodedStatus = jsonDecode(statusJson);
              if (decodedStatus is List) {
                _statusFiles = decodedStatus;
              }
            } catch (e) {
              debugPrint("Parsing status error: $e");
            }
          }
        }
        
        // Fetch branch metadata
        _updateBranchInfo();
        
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBranchInfo() async {
    final current = await GitService.getCurrentBranch(widget.repoPath);
    final list = await GitService.getBranches(widget.repoPath);
    if (mounted) {
      setState(() {
        _currentBranch = current;
        _branches = list;
      });
    }
  }

  Future<void> _showCommitDialog() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceSlate,
        title: const Text("Commit Changes", style: TextStyle(color: AppTheme.accentCyan)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textLight),
          decoration: const InputDecoration(
            hintText: "Commit message",
            hintStyle: TextStyle(color: AppTheme.textDim),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textDim)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textDim)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
            child: const Text("Commit"),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);
      final code = await GitService.commitAll(widget.repoPath, controller.text.trim());
      if (mounted) {
        if (code == 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commit successful!")));
          _fetchData(); // Refresh history and status
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Commit failed (code: $code)")));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showBranchDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceSlate,
          title: const Text("Git Branches", style: TextStyle(color: AppTheme.accentCyan)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Available Branches:", style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final b = _branches[index];
                    final isCurrent = b == _currentBranch;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: isCurrent ? AppTheme.accentCyan : AppTheme.textDim,
                      ),
                      title: Text(
                        b,
                        style: TextStyle(
                          color: isCurrent ? AppTheme.textLight : AppTheme.textDim,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isCurrent 
                        ? null 
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                child: const Text("Checkout", style: TextStyle(fontSize: 10)),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  setState(() => _isLoading = true);
                                  final code = await GitService.checkoutBranch(widget.repoPath, b);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(code == 0 ? "Checked out '$b'" : "Checkout failed (code: $code)"))
                                    );
                                    _fetchData();
                                    _listRepoFiles();
                                  }
                                },
                              ),
                              TextButton(
                                child: const Text("Merge", style: TextStyle(fontSize: 10, color: Colors.orange)),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  setState(() => _isLoading = true);
                                  final code = await GitService.mergeBranch(widget.repoPath, b);
                                  if (mounted) {
                                    if (code == -100) {
                                      // Conflict!
                                      final conflicts = await GitService.getConflicts(widget.repoPath);
                                      if (mounted) {
                                        final resolved = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(builder: (context) => MergeConflictScreen(
                                            repoPath: widget.repoPath,
                                            conflictingFiles: conflicts,
                                          )),
                                        );
                                        if (resolved == true) {
                                          await GitService.commitAll(widget.repoPath, "Merge branch '$b' (resolved conflicts)");
                                          _fetchData();
                                        } else {
                                          setState(() => _isLoading = false);
                                        }
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(code >= 0 ? "Merged '$b'!" : "Merge failed (code: $code)"))
                                      );
                                      _fetchData();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ),
              const Divider(color: AppTheme.textDim, height: 24),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textLight),
                decoration: const InputDecoration(
                  hintText: "New branch name",
                  hintStyle: TextStyle(color: AppTheme.textDim),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final code = await GitService.createBranch(widget.repoPath, name);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(code == 0 ? "Branch '$name' created!" : "Failed to create branch (code: $code)"))
                  );
                  _fetchData();
                }
              },
              child: const Text("Create", style: TextStyle(color: AppTheme.accentCyan)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: AppTheme.textDim)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewFileDialog() async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceSlate,
        title: const Text("Create New File", style: TextStyle(color: AppTheme.accentCyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textLight),
              decoration: const InputDecoration(
                hintText: "example.txt",
                hintStyle: TextStyle(color: AppTheme.textDim),
                labelText: "File Name",
                labelStyle: TextStyle(color: AppTheme.textDim),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textLight),
              decoration: const InputDecoration(
                hintText: "File content here...",
                hintStyle: TextStyle(color: AppTheme.textDim),
                labelText: "Content",
                labelStyle: TextStyle(color: AppTheme.textDim),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textDim)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              
              final file = File("${_currentDir}${Platform.pathSeparator}$name");
              await file.writeAsString(contentController.text);
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Created $name")));
                _fetchData();
                _listRepoFiles();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relativePath = _currentDir.length > widget.repoPath.length 
        ? _currentDir.substring(widget.repoPath.length) 
        : "";

    return Scaffold(
      appBar: AppBar(
        leading: _currentDir != widget.repoPath 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _currentDir = Directory(_currentDir).parent.path;
                  _listRepoFiles();
                });
              },
            )
          : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.repoName),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.5)),
                  ),
                  child: Text(
                    _currentBranch,
                    style: const TextStyle(fontSize: 10, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (relativePath.isNotEmpty)
              Text(
                relativePath,
                style: const TextStyle(fontSize: 10, color: AppTheme.textDim),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchData();
              _listRepoFiles();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: _showBranchDialog,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
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
      floatingActionButton: _isNotGitRepo || _isLoading 
          ? null 
          : _selectedIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: _showNewFileDialog,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text("New File"),
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                )
              : _selectedIndex == 2 && _statusFiles.isNotEmpty
                  ? FloatingActionButton.extended(
                      onPressed: _showCommitDialog,
                      icon: const Icon(Icons.check),
                      label: const Text("Commit"),
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                    )
                  : null,
    );
  }

  Widget _buildExplorerView() {
    if (_currentFiles.isEmpty) {
      return const Center(
        child: Text("Empty directory", style: TextStyle(color: AppTheme.textDim)),
      );
    }

    return ListView.builder(
      itemCount: _currentFiles.length,
      itemBuilder: (context, index) {
        final entity = _currentFiles[index];
        final name = entity.path.split(Platform.pathSeparator).last;
        final isDir = entity is Directory;

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder : Icons.description_outlined,
            color: isDir ? AppTheme.accentCyan : AppTheme.textDim,
          ),
          title: Text(name),
          trailing: const Icon(Icons.chevron_right, size: 16, color: AppTheme.textDim),
          onTap: () => _onItemTapped(entity),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan));
    }
    if (_commits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppTheme.textDim),
            SizedBox(height: 16),
            Text("No commits found", style: TextStyle(color: AppTheme.textDim)),
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
    final commit = _commits[index];
    final hash = commit['hash'] ?? '0000000';
    final msg = commit['message'] ?? 'No message';
    final author = commit['author'] ?? 'Unknown';
    final date = commit['date'] ?? 'N/A';

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
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
                    color: AppTheme.textDim.withOpacity(0.3),
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
                      Text(author, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(
                        hash.substring(0, 7),
                        style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan));
    }
    if (_statusFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: AppTheme.accentCyan),
            SizedBox(height: 16),
            Text("Worktree clean", style: TextStyle(color: AppTheme.textDim)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _statusFiles.length,
      itemBuilder: (context, index) {
        final file = _statusFiles[index];
        final fileName = file['path'] ?? 'Unknown';
        final status = file['status'] ?? 'unknown';
        
        return ListTile(
          leading: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
          ),
          title: Text(fileName),
          subtitle: Text(status, style: const TextStyle(fontSize: 10, color: AppTheme.textDim)),
          trailing: status.contains('untracked') || status.contains('modified') 
            ? IconButton(
                icon: const Icon(Icons.add, color: AppTheme.accentCyan, size: 20),
                onPressed: () async {
                   await GitService.gitAddFile(widget.repoPath, fileName);
                   _fetchData();
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
          const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Not a Git Repository',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight),
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
                // Success, fetch fresh data
                _fetchData();
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to initialize repository (code: $result)')),
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
            label: const Text('Initialize Repository', style: TextStyle(fontWeight: FontWeight.bold)),
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
