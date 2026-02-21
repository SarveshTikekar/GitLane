import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

const int _maxLanes = 3;
const double _lanePadding = 12;

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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final lanePanelWidth = width < 360 ? 74.0 : (width < 420 ? 84.0 : 96.0);
    final rowHeight = compact ? 82.0 : 88.0;
    final laneCount = commits.isEmpty
        ? _maxLanes
        : math.max(_maxLanes, commits.map((c) => c.lane).fold(0, math.max) + 1);

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: commits.isEmpty
          ? const EmptyState(
              icon: Icons.timeline_outlined,
              title: 'No commits to display',
              subtitle: 'Commit history will appear here once commits exist',
            )
          : ListView.builder(
              itemCount: commits.length,
              itemBuilder: (context, index) {
                final commit = commits[index];
                final row = rows[index];

                return SizedBox(
                  height: rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: lanePanelWidth,
                        child: CustomPaint(
                          painter: _CommitGraphPainter(
                            row: row,
                            laneCount: laneCount,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 14, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                commit.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCyan.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _shortHash(commit.id),
                                      style: GoogleFonts.firaMono(
                                        color: AppTheme.accentCyan,
                                        fontSize: compact ? 9.5 : 10,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(commit.timestamp),
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: compact ? 10 : 11,
                                    ),
                                  ),
                                ],
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
    AppTheme.accentCyan,
    AppTheme.accentPurple,
    AppTheme.accentGreen,
    AppTheme.accentOrange,
    AppTheme.accentBlue,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    for (var lane = 0; lane < laneCount; lane++) {
      final x = _xForLane(lane, size.width);
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

    final nodeX = _xForLane(row.nodeLane, size.width);
    final nodeColor = _laneColors[row.nodeLane % _laneColors.length];
    final edgePaint = Paint()
      ..color = nodeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final targetLane in row.mergeToLanes) {
      final targetX = _xForLane(targetLane, size.width);
      canvas.drawLine(
        Offset(nodeX, centerY),
        Offset(targetX, size.height),
        edgePaint,
      );
    }

    canvas.drawCircle(Offset(nodeX, centerY), 6, Paint()..color = AppTheme.bg0);
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

  double _xForLane(int lane, double width) {
    if (laneCount <= 1) return width / 2;
    final usableWidth = width - (_lanePadding * 2);
    final safeWidth = usableWidth < 1 ? 1.0 : usableWidth;
    final spacing = safeWidth / (laneCount - 1);
    return _lanePadding + (lane * spacing);
  }

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
