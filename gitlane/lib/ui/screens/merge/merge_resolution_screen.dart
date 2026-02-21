import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MergeResolutionScreen extends StatelessWidget {
  const MergeResolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Conflict'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('DONE', style: TextStyle(color: AppTheme.accentCyan)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMergeSource('LOCAL: main', Colors.blue),
          Expanded(
            child: _buildMergeMiddle(),
          ),
          _buildMergeSource('REMOTE: feature/branch', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildMergeSource(String label, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMergeMiddle() {
    return Container(
      color: AppTheme.backgroundBlack,
      child: ListView(
        children: [
          _buildMergeLine('class GitManager {', MergeState.none),
          _buildMergeLine('<<<<<<< HEAD', MergeState.conflictHeader),
          _buildMergeLine('  void sync() { print("Local Sync"); }', MergeState.local),
          _buildMergeLine('=======', MergeState.conflictDivider),
          _buildMergeLine('  void sync() { print("Remote Sync"); }', MergeState.remote),
          _buildMergeLine('>>>>>>> feature/branch', MergeState.conflictHeader),
          _buildMergeLine('}', MergeState.none),
        ],
      ),
    );
  }

  Widget _buildMergeLine(String content, MergeState state) {
    Color? bgColor;
    if (state == MergeState.local) bgColor = Colors.blue.withValues(alpha: 0.1);
    if (state == MergeState.remote) bgColor = Colors.purple.withValues(alpha: 0.1);
    if (state == MergeState.conflictHeader || state == MergeState.conflictDivider) {
      bgColor = Colors.orange.withValues(alpha: 0.2);
    }

    return InkWell(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: bgColor,
        child: Text(
          content,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
    );
  }
}

enum MergeState { local, remote, none, conflictHeader, conflictDivider }
