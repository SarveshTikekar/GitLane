import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';

class NativeTerminalScreen extends StatefulWidget {
  final String repoPath;

  const NativeTerminalScreen({super.key, required this.repoPath});

  @override
  State<NativeTerminalScreen> createState() => _NativeTerminalScreenState();
}

class _NativeTerminalScreenState extends State<NativeTerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _history = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _history.add("GitLane Native Terminal v1.0");
    _history.add("Type 'help' for available commands.");
  }

  Future<void> _executeCommand() async {
    final cmd = _commandController.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _history.add("\$ git $cmd");
      _commandController.clear();
      _isLoading = true;
    });

    final output = await GitService.runGitCommand(widget.repoPath, cmd);

    setState(() {
      _history.add(output);
      _isLoading = false;
    });

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Native Terminal", style: TextStyle(fontFamily: 'monospace')),
        backgroundColor: AppTheme.backgroundBlack,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final line = _history[index];
                final isCommand = line.startsWith("\$");
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isCommand ? AppTheme.accentCyan : AppTheme.textLight,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(backgroundColor: Colors.black, color: AppTheme.accentCyan),
          Container(
            color: AppTheme.surfaceSlate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("\$ git ", style: TextStyle(color: AppTheme.accentCyan, fontFamily: 'monospace')),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "enter command...",
                      hintStyle: TextStyle(color: AppTheme.textDim),
                    ),
                    onSubmitted: (_) => _executeCommand(),
                    autofocus: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.accentCyan, size: 20),
                  onPressed: _executeCommand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
