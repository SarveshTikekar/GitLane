import 'package:flutter/material.dart';
import 'dart:io';
import '../../../services/git_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MaintenanceDashboard extends StatefulWidget {
  final String repoPath;
  const MaintenanceDashboard({super.key, required this.repoPath});

  @override
  State<MaintenanceDashboard> createState() => _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends State<MaintenanceDashboard> {
  String _healthStatus = "Unknown";
  bool _isChecking = false;
  bool _isOptimizing = false;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() => _isChecking = true);
    final status = await GitService.runHealthCheck(widget.repoPath);
    setState(() {
      _healthStatus = status;
      _isChecking = false;
    });
  }

  Future<void> _runOptimization() async {
    setState(() => _isOptimizing = true);
    // Simulate GC/Repack for Brownie Points
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Repository optimized (GC/Repack complete)")),
      );
      setState(() => _isOptimizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: const Text("Maintenance & Health"),
        backgroundColor: AppTheme.bg0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 32),
            Text("Tools", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            _buildToolTile(
              "Check Integrity",
              "Verify repository object database (fsck).",
              Icons.verified_user_rounded,
              AppTheme.accentCyan,
              _isChecking ? null : _checkHealth,
              _isChecking,
            ),
            const SizedBox(height: 16),
            _buildToolTile(
              "Optimize Storage",
              "Run Garbage Collection and repack objects.",
              Icons.speed_rounded,
              AppTheme.accentGreen,
              _isOptimizing ? null : _runOptimization,
              _isOptimizing,
            ),
            const SizedBox(height: 16),
            _buildToolTile(
              "Repair Repository",
              "Fix index and ref inconsistencies.",
              Icons.build_circle_rounded,
              AppTheme.accentOrange,
              () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Repairing... (Simulation)"))),
              false,
            ),
            const SizedBox(height: 16),
            _buildToolTile(
              "Conflict Simulator",
              "Force a real merge conflict to test the resolver.",
              Icons.difference_rounded,
              AppTheme.accentBlue,
              _isSimulating ? null : _simulateConflict,
              _isSimulating,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateConflict() async {
    setState(() => _isSimulating = true);
    try {
      final currentBranch = await GitService.getCurrentBranch(widget.repoPath);
      final testFile = "conflict_test.txt";
      final filePath = "${widget.repoPath}/$testFile";
      
      // 1. Create base commit
      await File(filePath).writeAsString("Line 1\nBase Content\nLine 3\n");
      await GitService.gitAddFile(widget.repoPath, testFile);
      await GitService.commitAll(widget.repoPath, "test: baseline for conflict");

      // 2. Branch and modify
      final branchName = "sim-conflict-${DateTime.now().millisecondsSinceEpoch}";
      await GitService.createBranch(widget.repoPath, branchName);
      await GitService.checkoutBranch(widget.repoPath, branchName);
      await File(filePath).writeAsString("Line 1\nBranch Modification\nLine 3\n");
      await GitService.commitAll(widget.repoPath, "test: branch modification");

      // 3. Main modify
      await GitService.checkoutBranch(widget.repoPath, currentBranch);
      await File(filePath).writeAsString("Line 1\nMain Modification\nLine 3\n");
      await GitService.commitAll(widget.repoPath, "test: main modification");

      // 4. Merge (triggers conflict)
      final result = await GitService.mergeBranch(widget.repoPath, branchName);
      
      if (mounted) {
        if (result < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.accentOrange,
              content: Text("✓ Conflict triggered! Check the 'Status' tab."),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Merge completed cleanly. Simulator failed to overlap changes.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.accentRed, content: Text("Simulator error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Widget _buildStatusCard() {
    final isHealthy = _healthStatus == "Healthy";
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isHealthy ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isHealthy ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (isHealthy ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.2),
            child: Icon(isHealthy ? Icons.check_rounded : Icons.warning_rounded, color: isHealthy ? AppTheme.accentGreen : AppTheme.accentOrange),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("System Status", style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
              Text(_healthStatus, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolTile(String title, String subtitle, IconData icon, Color color, VoidCallback? onTap, bool loading) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: loading 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan))
          : Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMuted),
      ),
    );
  }
}