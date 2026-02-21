import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../../services/local_sync_service.dart';
import '../home/qr_scanner_dialog.dart';

class QuantumHubScreen extends StatefulWidget {
  final String repoName;
  final String repoPath;

  const QuantumHubScreen({
    super.key,
    required this.repoName,
    required this.repoPath,
  });

  @override
  State<QuantumHubScreen> createState() => _QuantumHubScreenState();
}

class _QuantumHubScreenState extends State<QuantumHubScreen> {
  final LocalSyncService _syncService = LocalSyncService();
  String? _localIP;
  bool _isSyncing = false;
  String? _hubInfo;

  @override
  void initState() {
    super.initState();
    _loadIP();
  }

  Future<void> _loadIP() async {
    final ip = await _syncService.getLocalIP();
    setState(() => _localIP = ip);
  }

  Future<void> _toggleHub() async {
    if (_syncService.isRunning) {
      await _syncService.stopHub();
    } else {
      await _syncService.startHub(widget.repoPath, widget.repoName);
      await _loadIP();
    }
    setState(() {});
  }

  Future<void> _joinHub() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const QRScannerDialog(),
    );

    if (result != null && result.isNotEmpty) {
      // Result should be the Hub IP/URL
      _syncFromHub(result);
    }
  }

  Future<void> _syncFromHub(String hubUrl) async {
    setState(() {
      _isSyncing = true;
      _hubInfo = "Connecting to hub...";
    });

    try {
      final infoResp = await http.get(Uri.parse('$hubUrl/info'));
      if (infoResp.statusCode == 200) {
        final info = jsonDecode(infoResp.body);
        setState(() => _hubInfo = "Syncing from ${info['repoName']}...");
        
        final syncResp = await http.get(Uri.parse('$hubUrl/sync'));
        if (syncResp.statusCode == 200) {
          final archive = ZipDecoder().decodeBytes(syncResp.bodyBytes);
          
          for (final file in archive) {
            final filename = file.name;
            if (file.isFile) {
              final data = file.content as List<int>;
              File('${widget.repoPath}/../$filename')
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else {
              Directory('${widget.repoPath}/../$filename').createSync(recursive: true);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: AppTheme.accentGreen, content: Text('✓ Sync complete! Local files updated.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.accentRed, content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hubInfo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHosting = _syncService.isRunning;
    final hubUrl = _localIP != null ? 'http://$_localIP:8080' : null;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: Text('Quantum Mesh', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.bg0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildHostCard(isHosting, hubUrl),
            const SizedBox(height: 24),
            _buildJoinCard(),
            if (_isSyncing) ...[
              const SizedBox(height: 32),
              _buildSyncProgress(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: AppTheme.accentCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Collaboration Hub',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to a local hotspot to sync repositories directly between devices without internet.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHostCard(bool isHosting, String? hubUrl) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      accentBorder: isHosting ? AppTheme.accentGreen : AppTheme.accentCyan,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHosting ? 'Hub Active' : 'Start Hosting',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isHosting ? 'Peers can now discover you' : 'Begin a local sync session',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isHosting,
                onChanged: (_) => _toggleHub(),
                activeColor: AppTheme.accentGreen,
              ),
            ],
          ),
          if (isHosting && hubUrl != null) ...[
            const Divider(height: 32, color: AppTheme.border),
            QrImageView(
              data: hubUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            const SizedBox(height: 16),
            Text(hubUrl, style: GoogleFonts.firaMono(color: AppTheme.accentCyan, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Peers should scan this to join', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinCard() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _joinHub,
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
        label: const Text('Scan Hub QR & Join Mesh'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSyncProgress() {
    return Column(
      children: [
        const LinearProgressIndicator(color: AppTheme.accentCyan),
        const SizedBox(height: 12),
        Text(_hubInfo ?? "Syncing...", style: GoogleFonts.inter(color: AppTheme.accentCyan, fontSize: 12)),
      ],
    );
  }
}
