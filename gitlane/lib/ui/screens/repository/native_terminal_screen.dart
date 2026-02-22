import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../../services/git_service.dart';
import 'dart:io';

class NativeTerminalScreen extends StatefulWidget {
  final String repoPath;

  const NativeTerminalScreen({super.key, required this.repoPath});

  @override
  State<NativeTerminalScreen> createState() => _NativeTerminalScreenState();
}

class _TerminalLine {
  final String text;
  final bool isCommand;
  _TerminalLine(this.text, {this.isCommand = false});
}

class _NativeTerminalScreenState extends State<NativeTerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  final List<_TerminalLine> _outputHistory = [];
  final List<String> _commandHistory = [];
  int _historyIndex = -1;
  bool _isLoading = false;

  late String _repoName;

  @override
  void initState() {
    super.initState();
    _repoName = widget.repoPath.split(Platform.pathSeparator).last;
    _outputHistory.add(_TerminalLine("GitLane Native Terminal v2.0 (Enhanced)", isCommand: false));
    _outputHistory.add(_TerminalLine("Type 'help' for available commands. Use ↑/↓ to navigate history.", isCommand: false));
  }

  @override
  void dispose() {
    _commandController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_commandHistory.isNotEmpty) {
          setState(() {
            _historyIndex = (_historyIndex + 1).clamp(0, _commandHistory.length - 1);
            _commandController.text = _commandHistory[_commandHistory.length - 1 - _historyIndex];
            _commandController.selection = TextSelection.collapsed(offset: _commandController.text.length);
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_historyIndex >= 0) {
          setState(() {
            _historyIndex--;
            if (_historyIndex < 0) {
              _commandController.clear();
            } else {
              _commandController.text = _commandHistory[_commandHistory.length - 1 - _historyIndex];
              _commandController.selection = TextSelection.collapsed(offset: _commandController.text.length);
            }
          });
        }
      }
    }
  }

  Future<void> _executeCommand() async {
    final cmd = _commandController.text.trim();
    if (cmd.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    setState(() {
      _outputHistory.add(_TerminalLine("user@$_repoName ~ \$ git $cmd", isCommand: true));
      _commandHistory.add(cmd);
      _historyIndex = -1;
      _commandController.clear();
    });

    if (cmd == "clear") {
      setState(() {
        _outputHistory.clear();
      });
      _scrollToBottom();
      _focusNode.requestFocus();
      return;
    }

    setState(() => _isLoading = true);
    _scrollToBottom();

    final output = await GitService.runGitCommand(widget.repoPath, cmd);

    setState(() {
      final lines = output.split('\n');
      for (var line in lines) {
        if (line.isNotEmpty || lines.length == 1) { // keep empty lines if it's the only one, otherwise trim trailing
           _outputHistory.add(_TerminalLine(line, isCommand: false));
        }
      }
      _isLoading = false;
    });

    _scrollToBottom();
    _focusNode.requestFocus();
  }

  TextSpan _parseTerminalLine(String text) {
    if (text.startsWith("fatal:") || text.startsWith("Error:")) {
      return TextSpan(text: text, style: const TextStyle(color: AppTheme.accentRed));
    }
    
    final List<TextSpan> spans = [];
    
    // Simple regex parser for git status and log outputs 
    // Match commit hashes (7+ hex chars), file status keywords, branch names
    final regex = RegExp(r"([0-9a-f]{7,40})|(new file:|modified:|deleted:|renamed:|typechange:)|(On branch) (.*)|(nothing to commit.*)|(Changes to be committed:)|(Changes not staged for commit:)|(Untracked files:)", caseSensitive: false);
    
    int lastMatchEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: TextStyle(color: AppTheme.textLight)));
      }
      
      final matchText = match.group(0)!;
      
      if (match.group(1) != null) {
        // Hash
        spans.add(TextSpan(text: matchText, style: TextStyle(color: AppTheme.accentYellow)));
      } else if (match.group(2) != null) {
        // Status keyword
        Color statusColor = AppTheme.textMuted;
        if (matchText.contains("new file")) statusColor = AppTheme.accentGreen;
        else if (matchText.contains("modified")) statusColor = AppTheme.accentCyan;
        else if (matchText.contains("deleted")) statusColor = AppTheme.accentRed;
        else if (matchText.contains("renamed")) statusColor = AppTheme.accentPurple;
        
        spans.add(TextSpan(text: matchText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)));
      } else if (match.group(3) != null) {
         // On branch X
         spans.add(TextSpan(text: "On branch ", style: TextStyle(color: AppTheme.textMuted)));
         spans.add(TextSpan(text: match.group(4) ?? "", style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)));
      } else if (match.group(5) != null) {
          // clean wd
         spans.add(TextSpan(text: matchText, style: const TextStyle(color: AppTheme.accentGreen)));
      } else if (match.group(6) != null || match.group(7) != null || match.group(8) != null) {
          // Headers
         spans.add(TextSpan(text: matchText, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: matchText, style: TextStyle(color: AppTheme.textLight)));
      }
      
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      // If it's a tabbed file path in status
      if (text.startsWith("\t") && !regex.hasMatch(text)) {
          spans.add(TextSpan(text: text.substring(lastMatchEnd), style: const TextStyle(color: AppTheme.accentRed))); // untracked usually
      } else {
          spans.add(TextSpan(text: text.substring(lastMatchEnd), style: TextStyle(color: AppTheme.textLight)));
      }
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // VSCode-like terminal background
      appBar: AppBar(
        title: Text("Native Terminal", style: GoogleFonts.firaMono(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF252526),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            tooltip: "Clear Terminal",
            onPressed: () {
               setState(() {
                 _outputHistory.clear();
                 _historyIndex = -1;
               });
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _outputHistory.length,
                itemBuilder: (context, index) {
                  final line = _outputHistory[index];
                  
                  if (line.isCommand) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 2.0),
                      child: Text(
                        line.text,
                        style: GoogleFonts.firaMono(
                          color: AppTheme.accentCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.0),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.firaMono(fontSize: 13, height: 1.3),
                        children: [_parseTerminalLine(line.text)],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(backgroundColor: Color(0xFF1E1E1E), color: AppTheme.accentCyan, minHeight: 2),
            
          Container(
            color: const Color(0xFF252526),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: KeyboardListener(
              focusNode: FocusNode(), // Dummy node so the KeyboardListener catches before TextField if needed, or we just use onKeyEvent mapped below
              onKeyEvent: _handleKeyEvent,
              child: Row(
                children: [
                  Text(
                    "user@$_repoName ~ \$ git ",
                    style: GoogleFonts.firaMono(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      focusNode: _focusNode,
                      style: GoogleFonts.firaMono(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        border: InputBorder.none,
                        hintText: "...",
                        hintStyle: GoogleFonts.firaMono(color: AppTheme.textDim, fontSize: 13),
                      ),
                      cursorColor: Colors.white,
                      cursorWidth: 8, // block cursor look
                      onSubmitted: (_) => _executeCommand(),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}