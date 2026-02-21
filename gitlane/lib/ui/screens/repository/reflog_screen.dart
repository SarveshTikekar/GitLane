import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import '../../widgets/glass_card.dart';

class ReflogScreen extends StatefulWidget {
  final String repoPath;

  const ReflogScreen({super.key, required this.repoPath});

  @override
  State<ReflogScreen> createState() => _ReflogScreenState();
}

class _ReflogScreenState extends State<ReflogScreen> {
  List<dynamic> _reflogEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReflog();
  }

  Future<void> _fetchReflog() async {
    setState(() => _isLoading = true);
    final jsonStr = await GitService.getReflog(widget.repoPath);
    try {
      final data = json.decode(jsonStr);
      if (data is List) {
        setState(() {
          _reflogEntries = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Action History (Reflog)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReflog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _reflogEntries.isEmpty
              ? const Center(child: Text("No history found.", style: TextStyle(color: AppTheme.textDim)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reflogEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _reflogEntries[index];
                    final msg = entry['msg'] ?? 'no message';
                    final id = entry['id'] ?? 'unknown';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history_toggle_off, color: AppTheme.accentCyan, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg,
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Target: ${id.substring(0, 7)}",
                              style: const TextStyle(
                                color: AppTheme.textDim,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  // Implementation of 'Reset to this state'
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Recovery feature coming soon!")),
                                  );
                                },
                                icon: const Icon(Icons.restore_rounded, size: 16),
                                label: const Text("Recover to this state", style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
