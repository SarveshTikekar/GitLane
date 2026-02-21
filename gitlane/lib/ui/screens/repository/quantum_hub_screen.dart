import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  String? _deviceId;
  Timer? _peerUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initDevice();
    _loadIP();
    _peerUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _syncService.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _peerUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDevice() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      _deviceId = android.id;
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      _deviceId = ios.identifierForVendor;
    }
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
      _syncFromHub(result);
    }
  }

  Future<void> _syncFromHub(String hubUrl) async {
    setState(() {
      _isSyncing = true;
      _hubInfo = "Performing Handshake...";
    });

    try {
      final handshakeBody = jsonEncode({
        'id': _deviceId ?? 'unknown-peer',
        'name': Platform.operatingSystem,
      });

      final handshakeResp = await http.post(
        Uri.parse('$hubUrl/handshake'),
        body: handshakeBody,
        headers: {'content-type': 'application/json'},
      );

      if (handshakeResp.statusCode == 200) {
        final peerData = jsonDecode(handshakeResp.body);
        if (peerData['status'] == PeerStatus.pending.index) {
          setState(() => _hubInfo = "Waiting for Host approval...");
          // In a real app, we might poll or use WebSockets.
          // For now, let's just wait a bit or try again.
          return;
        }

        final infoResp = await http.get(
          Uri.parse('$hubUrl/info'),
          headers: {'x-device-id': _deviceId ?? ''},
        );
        
        if (infoResp.statusCode == 200) {
          final info = jsonDecode(infoResp.body);
          setState(() => _hubInfo = "Syncing from ${info['repoName']}...");
          
          final syncResp = await http.get(
            Uri.parse('$hubUrl/sync'),
            headers: {'x-device-id': _deviceId ?? ''},
          );
          
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
            if (mounted) _snack('✓ Sync complete!', AppTheme.accentGreen);
          }
        } else {
          _snack('Access Denied: ${infoResp.body}', AppTheme.accentRed);
        }
      }
    } catch (e) {
      _snack('Sync failed: $e', AppTheme.accentRed);
    } finally {
      if (mounted) setState(() { _isSyncing = false; _hubInfo = null; });
    }
  }

  void _snack(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: color, content: Text(msg)));
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
            if (isHosting) ...[
              const SizedBox(height: 32),
              _buildPeerList(),
            ],
            const SizedBox(height: 32),
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
            const Icon(Icons.security_rounded, color: AppTheme.accentPurple, size: 20),
            const SizedBox(width: 12),
            Text(
              'Secure Collaboration Hub',
              style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage peer access and sync repositories locally with role-based permissions.',
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
                    Text(isHosting ? 'Hub Active' : 'Start Hosting', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(isHosting ? 'Approve peers to allow access' : 'Host a local collaboration session', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Switch(value: isHosting, onChanged: (_) => _toggleHub(), activeColor: AppTheme.accentGreen),
            ],
          ),
          if (isHosting && hubUrl != null) ...[
            const Divider(height: 32, color: AppTheme.border),
            QrImageView(data: hubUrl, version: QrVersions.auto, size: 160, backgroundColor: Colors.white, padding: const EdgeInsets.all(12)),
            const SizedBox(height: 12),
            Text(hubUrl, style: GoogleFonts.firaMono(color: AppTheme.accentCyan, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildPeerList() {
    final peers = _syncService.peers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MESH PEERS (${peers.length})', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (peers.isEmpty) 
          Text('No peers connected yet', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
        ...peers.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: p.status == PeerStatus.approved ? AppTheme.accentGreen : AppTheme.accentOrange, radius: 4),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(p.id, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ])),
              if (p.status == PeerStatus.pending) ...[
                IconButton(icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 20), onPressed: () => _updatePeer(p.id, PeerStatus.approved)),
                IconButton(icon: const Icon(Icons.cancel_rounded, color: AppTheme.accentRed, size: 20), onPressed: () => _updatePeer(p.id, PeerStatus.denied)),
              ] else ...[
                _roleChip(p),
                IconButton(icon: const Icon(Icons.delete_rounded, color: AppTheme.textMuted, size: 18), onPressed: () => _updatePeer(p.id, PeerStatus.pending)),
              ],
            ],
          ),
        )),
      ],
    );
  }

  Widget _roleChip(Peer p) {
    return PopupMenuButton<PeerRole>(
      onSelected: (r) => _updatePeer(p.id, PeerStatus.approved, r),
      itemBuilder: (context) => [
        const PopupMenuItem(value: PeerRole.read, child: Text('Read Only')),
        const PopupMenuItem(value: PeerRole.write, child: Text('Read & Write')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: p.role == PeerRole.write ? AppTheme.accentCyan.withOpacity(0.1) : AppTheme.border, borderRadius: BorderRadius.circular(4)),
        child: Text(p.role == PeerRole.write ? 'WRITE' : 'READ', style: TextStyle(color: p.role == PeerRole.write ? AppTheme.accentCyan : AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _updatePeer(String id, PeerStatus s, [PeerRole? r]) {
    _syncService.updatePeerStatus(id, s, r);
    setState(() {});
  }

  Widget _buildJoinCard() {
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _isSyncing ? null : _joinHub,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
      label: const Text('Scan Hub QR & Join Mesh'),
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
    ));
  }

  Widget _buildSyncProgress() {
    return Column(children: [
      const LinearProgressIndicator(color: AppTheme.accentCyan),
      const SizedBox(height: 12),
      Text(_hubInfo ?? "Syncing...", style: GoogleFonts.inter(color: AppTheme.accentCyan, fontSize: 12)),
    ]);
  }
}
