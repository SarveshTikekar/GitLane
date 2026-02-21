import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const int _maxLanes = 3;
const double _laneSpacing = 24;
const double _laneStart = 16;

class CommitNode {
  const CommitNode({
    required this.id,
    required this.parentIds,
    required this.message,
    required this.timestamp,
    required this.lane,
  });

  final String id;
  final List<String> parentIds;
  final String message;
  final DateTime timestamp;
  final int lane;
}

class CommitGraphScreen extends StatelessWidget {
  const CommitGraphScreen({
    super.key,
    required this.commits,
    this.title = 'Git Commit Graph',
  });

  final List<CommitNode> commits;
  final String title;

  @override
  Widget build(BuildContext context) {
    final rows = _buildGraphRows(commits);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: commits.isEmpty
          ? const Center(
              child: Text(
                'No commits found',
                style: TextStyle(color: AppTheme.textDim),
              ),
            )
          : ListView.builder(
              itemCount: commits.length,
              itemBuilder: (context, index) {
                final commit = commits[index];
                final row = rows[index];

                return SizedBox(
                  height: 76,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 96,
                        child: CustomPaint(
                          painter: _CommitGraphPainter(
                            row: row,
                            laneCount: _maxLanes,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                commit.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_shortHash(commit.id)}  |  ${_formatTimestamp(commit.timestamp)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textDim,
                                      fontFamily: 'monospace',
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _RowGraphState {
  const _RowGraphState({
    required this.nodeLane,
    required this.topLanes,
    required this.bottomLanes,
    required this.mergeToLanes,
  });

  final int nodeLane;
  final Set<int> topLanes;
  final Set<int> bottomLanes;
  final Set<int> mergeToLanes;
}

List<_RowGraphState> _buildGraphRows(List<CommitNode> commits) {
  final idToLane = <String, int>{
    for (final commit in commits) commit.id: commit.lane,
  };

  final rows = <_RowGraphState>[];
  var activeLanes = <int>{};

  for (final commit in commits) {
    final parentLanes = commit.parentIds
        .map((id) => idToLane[id])
        .whereType<int>()
        .toSet();

    final topLanes = {...activeLanes};
    final bottomLanes = {...activeLanes}
      ..remove(commit.lane)
      ..addAll(parentLanes);

    rows.add(
      _RowGraphState(
        nodeLane: commit.lane,
        topLanes: topLanes,
        bottomLanes: bottomLanes,
        mergeToLanes: parentLanes.where((lane) => lane != commit.lane).toSet(),
      ),
    );

    activeLanes = bottomLanes;
  }

  return rows;
}

class _CommitGraphPainter extends CustomPainter {
  const _CommitGraphPainter({required this.row, required this.laneCount});

  final _RowGraphState row;
  final int laneCount;

  static const _laneColors = [
    Color(0xFF2F80ED),
    Color(0xFFEB5757),
    Color(0xFF27AE60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    for (var lane = 0; lane < laneCount; lane++) {
      final x = _xForLane(lane);
      final color = _laneColors[lane % _laneColors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      if (row.topLanes.contains(lane)) {
        canvas.drawLine(Offset(x, 0), Offset(x, centerY), paint);
      }

      if (row.bottomLanes.contains(lane)) {
        canvas.drawLine(Offset(x, centerY), Offset(x, size.height), paint);
      }
    }

    final nodeX = _xForLane(row.nodeLane);
    final nodeColor = _laneColors[row.nodeLane % _laneColors.length];
    final edgePaint = Paint()
      ..color = nodeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final targetLane in row.mergeToLanes) {
      final targetX = _xForLane(targetLane);
      canvas.drawLine(
        Offset(nodeX, centerY),
        Offset(targetX, size.height),
        edgePaint,
      );
    }

    canvas.drawCircle(Offset(nodeX, centerY), 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(nodeX, centerY),
      6,
      Paint()
        ..color = nodeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(nodeX, centerY), 2.8, Paint()..color = nodeColor);
  }

  double _xForLane(int lane) => _laneStart + (lane * _laneSpacing);

  @override
  bool shouldRepaint(covariant _CommitGraphPainter oldDelegate) {
    return oldDelegate.row != row || oldDelegate.laneCount != laneCount;
  }
}

String _formatTimestamp(DateTime timestamp) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)} '
      '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}';
}

String _shortHash(String hash) {
  if (hash.length <= 7) return hash;
  return hash.substring(0, 7);
}

final demoCommits = [
  CommitNode(
    id: 'd9e3aa7',
    parentIds: ['bc8e2a5', 'a3fd414'],
    message: 'Merge branch feature/auth into main',
    timestamp: DateTime(2026, 2, 21, 10, 42),
    lane: 0,
  ),
  CommitNode(
    id: 'bc8e2a5',
    parentIds: ['7f2aa11'],
    message: 'Refactor commit graph painter rendering',
    timestamp: DateTime(2026, 2, 21, 10, 10),
    lane: 0,
  ),
  CommitNode(
    id: 'a3fd414',
    parentIds: ['7f2aa11'],
    message: 'Add offline auth keychain support',
    timestamp: DateTime(2026, 2, 21, 9, 58),
    lane: 1,
  ),
  CommitNode(
    id: '7f2aa11',
    parentIds: ['94abef0'],
    message: 'Implement branch lane allocation',
    timestamp: DateTime(2026, 2, 21, 9, 17),
    lane: 0,
  ),
  CommitNode(
    id: '94abef0',
    parentIds: ['e27d0ab'],
    message: 'Add commit details card layout',
    timestamp: DateTime(2026, 2, 21, 8, 39),
    lane: 0,
  ),
  CommitNode(
    id: 'e27d0ab',
    parentIds: ['8b312de'],
    message: 'Wire ListView builder history rows',
    timestamp: DateTime(2026, 2, 21, 8, 02),
    lane: 0,
  ),
  CommitNode(
    id: '8b312de',
    parentIds: [],
    message: 'Initial repository bootstrap',
    timestamp: DateTime(2026, 2, 21, 7, 20),
    lane: 0,
  ),
];
