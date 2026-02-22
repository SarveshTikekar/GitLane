import 'dart:io';
import 'dart:async';

class SymbolLocation {
  final String path;
  final int line;
  final String? documentation;

  SymbolLocation({required this.path, required this.line, this.documentation});
}

class SearchResult {
  final String filePath;
  final int line;
  final String content;
  final String? symbolName;
  final bool isSymbolMatch;

  SearchResult({
    required this.filePath,
    required this.line,
    required this.content,
    this.symbolName,
    this.isSymbolMatch = false,
  });
}

class IndexerService {
  static final Map<String, SymbolLocation> _index = {};
  // Full-text search: filePath -> lines
  static final Map<String, List<String>> _fileLines = {};
  static bool _isIndexing = false;

  static bool get isIndexing => _isIndexing;

  /// Recursively index the repository at [repoPath].
  static Future<void> indexRepository(String repoPath) async {
    if (_isIndexing) return;
    _isIndexing = true;
    _index.clear();

    final dir = Directory(repoPath);
    if (!await dir.exists()) {
      _isIndexing = false;
      return;
    }

    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final path = entity.path;
          
          // Skip common noise directories
          if (path.contains('.dart_tool') || 
              path.contains('build/') || 
              path.contains('.git/') ||
              path.contains('android/.gradle')) continue;

          final validExts = ['.dart', '.kt', '.java', '.c', '.cpp', '.h', '.py', '.js', '.ts', '.go', '.rs', '.md'];
          if (validExts.any((ext) => path.endsWith(ext))) {
            await _indexFile(entity);
          }
        }
      }
    } catch (e) {
      // Log indexing error
    } finally {
      _isIndexing = false;
    }
  } // end indexRepository

  static Future<void> _indexFile(File file) async {
    try {
      final lines = await file.readAsLines();
      final path = file.path;

      // Store lines for full-text search
      _fileLines[path] = lines;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // 1. Dart/Kotlin Class
        if (line.startsWith('class ') || line.startsWith('abstract class ')) {
          final match = RegExp(r'class\s+([a-zA-Z0-9_]+)').firstMatch(line);
          if (match != null) {
            final symbolName = match.group(1)!;
            _index[symbolName] = SymbolLocation(
              path: path,
              line: i + 1,
              documentation: _getDocs(lines, i),
            );
          }
        }
        
        // 2. Functions/Methods
        // Matches "void name() {", "String name(...) {", "Future<T> name() async {"
        final funcMatch = RegExp(r'([a-zA-Z0-9_<>]+\s+)?([a-zA-Z0-9_]+)\s*\(.*?\)\s*(\{)?').firstMatch(line);
        if (funcMatch != null && !line.startsWith('return ') && !line.startsWith('if ') && !line.startsWith('for ')) {
          final symbolName = funcMatch.group(2)!;
          // Simple heuristic: function names usually start with lowercase or are significant
          if (symbolName.length > 2 && !['if', 'for', 'while', 'switch', 'super', 'this'].contains(symbolName)) {
            if (!_index.containsKey(symbolName)) {
              _index[symbolName] = SymbolLocation(
                path: path,
                line: i + 1,
                documentation: _getDocs(lines, i),
              );
            }
          }
        }

        // 3. JNI Native Functions
        if (line.contains('Java_com_example_gitlane_GitBridge_')) {
          final match = RegExp(r'Java_com_example_gitlane_GitBridge_([a-zA-Z0-9_]+)').firstMatch(line);
          if (match != null) {
            final symbolName = match.group(1)!;
            _index[symbolName] = SymbolLocation(
              path: path,
              line: i + 1,
              documentation: _getDocs(lines, i),
            );
          }
        }

        // 4. Markdown Headers
        if (path.endsWith('.md') && line.startsWith('#')) {
          final mdMatch = RegExp(r'^#{1,6}\s+(.+)').firstMatch(line);
          if (mdMatch != null) {
            final symbolName = mdMatch.group(1)!.trim();
            if (symbolName.isNotEmpty) {
              _index[symbolName] = SymbolLocation(
                path: path,
                line: i + 1,
                documentation: 'Markdown Section',
              );
            }
          }
        }
      }
    } catch (e) {
      // Some files might be binary or have encoding issues, ignore
    }
  }

  static List<String> getSymbolsInText(String text) {
    final List<String> symbols = [];
    final lines = text.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('void ') ||
          trimmed.startsWith('Future<') ||
          (trimmed.contains('(') && trimmed.contains('{') && !trimmed.contains('if'))) {
        final parts = trimmed.split(RegExp(r'[\s\(]'));
        for (var part in parts) {
          if (part.length > 3 && !['class', 'void', 'Future', 'static', 'async'].contains(part)) {
            symbols.add(part);
            break;
          }
        }
      }
    }
    return symbols.toSet().toList();
  }

  static String? _getDocs(List<String> lines, int index) {
    List<String> docs = [];
    for (int i = index - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.startsWith('///') || line.startsWith('//') || line.startsWith('*')) {
        final clean = line
            .replaceFirst('///', '')
            .replaceFirst('//', '')
            .replaceFirst('*', '')
            .trim();
        if (clean.isNotEmpty) docs.insert(0, clean);
      } else if (line.isEmpty) {
        continue;
      } else {
        break;
      }
      if (docs.length > 8) break;
    }
    return docs.isEmpty ? null : docs.join('\n');
  }

  static SymbolLocation? findSymbol(String name) {
    return _index[name];
  }

  /// Searches all indexed symbols by prefix/name.
  static List<SearchResult> searchSymbols(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final results = <SearchResult>[];
    for (final entry in _index.entries) {
      if (entry.key.toLowerCase().contains(lower)) {
        results.add(SearchResult(
          filePath: entry.value.path,
          line: entry.value.line,
          content: entry.key,
          symbolName: entry.key,
          isSymbolMatch: true,
        ));
      }
    }
    results.sort((a, b) => a.symbolName!.length.compareTo(b.symbolName!.length));
    return results.take(50).toList();
  }

  /// Full-text search across all indexed file lines.
  static List<SearchResult> searchContent(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final results = <SearchResult>[];
    for (final entry in _fileLines.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].toLowerCase().contains(lower)) {
          results.add(SearchResult(
            filePath: entry.key,
            line: i + 1,
            content: entry.value[i].trim(),
          ));
          if (results.length >= 100) return results;
        }
      }
    }
    return results;
  }

  static int get symbolCount => _index.length;
  static int get fileCount => _fileLines.length;

  static String? getSymbolAt(String line, int offset) {
    if (offset < 0 || offset >= line.length) return null;

    // Expand selection around offset to find the full word
    int start = offset;
    while (start > 0 && _isWordChar(line[start - 1])) {
      start--;
    }

    int end = offset;
    while (end < line.length && _isWordChar(line[end])) {
      end++;
    }

    if (start == end) return null;
    return line.substring(start, end);
  }

  static bool _isWordChar(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }
}
