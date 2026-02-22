import 'dart:io';

void main() {
  var text = File('analyze2.txt').readAsStringSync();
  var regex = RegExp(r' (lib[/\\][^:]+):(\d+):(\d+)');
  
  Map<String, Set<int>> issues = {};
  for (var match in regex.allMatches(text)) {
    var filePath = match.group(1)!;
    var lineNum = int.parse(match.group(2)!) - 1;
    issues.putIfAbsent(filePath, () => {}).add(lineNum);
  }
  
  int fixedCount = 0;

  for (var file in issues.keys) {
    var f = File(file);
    if (!f.existsSync()) continue;
    var lines = f.readAsLinesSync();
    
    // Process in reverse order so line numbers don't shift (though we aren't adding/removing lines)
    var sortedLines = issues[file]!.toList()..sort((a, b) => b.compareTo(a));

    for (var lineNum in sortedLines) {
       if (lineNum >= lines.length) continue;
       
       // Search upwards from lineNum for 'const ' and remove the closest one
       for (var i = lineNum; i >= 0 && i > lineNum - 15; i--) {
         if (lines[i].contains('const ')) {
           var idx = lines[i].lastIndexOf('const ');
           lines[i] = lines[i].substring(0, idx) + lines[i].substring(idx + 6);
           fixedCount++;
           break;
         }
       }
    }
    f.writeAsStringSync(lines.join('\n'));
  }
  
  print('Removed \'const\' from $fixedCount locations.');
}
