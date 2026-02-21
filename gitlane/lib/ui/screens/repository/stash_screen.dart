import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import '../../widgets/glass_card.dart';

class StashScreen extends StatefulWidget {
  final String repoPath;

  const StashScreen({super.key, required this.repoPath});

  @override
  State<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends State<StashScreen> {
  List<Map<String, dynamic>> _stashes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStashes();
  }

  Future<void> _loadStashes() async {
    setState(() => _isLoading = true);
    final list = await GitService.getStashes(widget.repoPath);
    if (mounted) {
      setState(() {
        _stashes = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _popStash(int index) async {
    setState(() => _isLoading = true);
    final result = await GitService.stashPop(widget.repoPath, index);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result == 0 ? "Stash popped successfully!" : "Failed to pop stash: $result")),
      );
      _loadStashes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Stash Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStashes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _stashes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stashes.length,
                  itemBuilder: (context, index) {
                    final s = _stashes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: AppTheme.accentCyan, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Stash @{${s['index']}}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                                ),
                                const Spacer(),
                                Text(
                                  s['hash'].toString().substring(0, 7),
                                  style: const TextStyle(fontFamily: 'monospace', color: AppTheme.textDim, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s['message'] ?? "No message",
                              style: const TextStyle(color: AppTheme.textLight, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _popStash(s['index'] as int),
                                  icon: const Icon(Icons.unarchive_outlined, size: 16),
                                  label: const Text("Pop Stash"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentCyan,
                                    foregroundColor: Colors.black,
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.surfaceSlate),
          const SizedBox(height: 16),
          const Text(
            "No stashes found",
            style: TextStyle(color: AppTheme.textDim, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.0),
            child: Text(
              "Stash allows you to save work-in-progress changes without committing them.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textDim, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
