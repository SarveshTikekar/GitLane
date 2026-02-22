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
    if (mounted) setState(() => _localIP = ip);
  }

  void _manualIP() {
    final controller = TextEditingController(text: _localIP ?? '');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manual IP Override', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 192.168.1.5',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _localIP = controller.text);
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleHub() async {
    if (_syncService.isRunning) {
      await _syncService.stopHub();
    } else {
      await _syncService.startHub();
      _syncService.registerRepo(widget.repoName, widget.repoPath);
      await _loadIP();
    }
    setState(() {});
  }

  Future<void> _joinHub() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const QRScannerDialog(),
    );

    if (result != null && result.startsWith('gitlane://hub/')) {
      _processScannedUrl(result);
    } else if (result != null && result.startsWith('http')) {
      _syncFromHub(result, widget.repoName);
    }
  }

  void _processScannedUrl(String url) {
    // gitlane://hub/<ip>:<port>/repo/<repoId>
    final uri = Uri.parse(url.replaceFirst('gitlane://hub/', 'http://'));
    final ipPort = "${uri.host}:${uri.port}";
    final hubUrl = "http://$ipPort";
    final repoId = uri.pathSegments.length >= 2 ? uri.pathSegments[1] : null;

    if (repoId != null) {
      _syncFromHub(hubUrl, repoId);
    }
  }

  Future<void> _syncFromHub(String hubUrl, String repoId) async {
    setState(() {
      _isSyncing = true;
      _hubInfo = "Handshake with Hub...";
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
          return;
        }

        final infoResp = await http.get(
          Uri.parse('$hubUrl/repo/$repoId/info'),
          headers: {'x-device-id': _deviceId ?? ''},
        );
        
        if (infoResp.statusCode == 200) {
          final info = jsonDecode(infoResp.body);
          setState(() => _hubInfo = "Syncing ${info['repoName']}...");
          
          final syncResp = await http.get(
            Uri.parse('$hubUrl/repo/$repoId/sync'),
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
            if (mounted) _snack('✓ Sync complete: $repoId', AppTheme.accentGreen);
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

  void _showRepoQR(String repoId) {
    if (_localIP == null || _localIP!.isEmpty) {
      _snack('⚠ Local IP not detected. Set it manually in the Host Card.', AppTheme.accentOrange);
      return;
    }
    final qrData = 'gitlane://hub/$_localIP:8080/repo/$repoId';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Share: $repoId', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                Text(qrData, style: GoogleFonts.firaMono(color: AppTheme.accentCyan, fontSize: 10), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHosting = _syncService.isRunning;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: Text('Quantum Mesh Hub', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.bg0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildHostCard(isHosting),
            if (isHosting) ...[
              const SizedBox(height: 32),
              _buildIPCard(),
              const SizedBox(height: 32),
              _buildSharedReposList(),
              const SizedBox(height: 32),
              _buildPeerManagement(),
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
            const Icon(Icons.hub_rounded, color: AppTheme.accentCyan, size: 24),
            const SizedBox(width: 12),
            Text(
              'Mesh Distribution Hub',
              style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Share multiple repositories over your local network with granular peer access.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHostCard(bool isHosting) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      accentBorder: isHosting ? AppTheme.accentGreen : AppTheme.accentCyan,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isHosting ? 'Hub Active' : 'Offline Hub', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  isHosting ? 'Serving ${_syncService.sharedRepos.length} repositories' : 'Start hosting to share repositories',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: isHosting, onChanged: (_) => _toggleHub(), activeColor: AppTheme.accentGreen),
        ],
      ),
    );
  }

  Widget _buildIPCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HUB ADDRESS', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: Row(
            children: [
              Icon(Icons.wifi_rounded, color: _localIP != null ? AppTheme.accentCyan : AppTheme.accentOrange, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _localIP != null ? '$_localIP:8080' : 'IP Not Detected',
                  style: GoogleFonts.firaMono(color: _localIP != null ? Colors.white : AppTheme.accentOrange, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 18),
                onPressed: _manualIP,
                tooltip: 'Manual IP Override',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted, size: 18),
                onPressed: _loadIP,
                tooltip: 'Refresh IP',
              ),
            ],
          ),
        ),
        if (_localIP == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text('⚠ Required for QR generation and peer discovery.', style: TextStyle(color: AppTheme.accentOrange, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _buildSharedReposList() {
    final shared = _syncService.sharedRepos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SHARED REPOSITORIES', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...shared.map((id) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded, color: AppTheme.accentBlue, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(id, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, color: AppTheme.accentCyan, size: 20),
                onPressed: () => _showRepoQR(id),
                tooltip: 'Show QR Code',
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            // Ideally a repo picker here, but for now we'll just re-register current if needed
            _syncService.registerRepo(widget.repoName, widget.repoPath);
            setState(() {});
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Current Repository'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
        ),
      ],
    );
  }

  Widget _buildPeerManagement() {
    final peers = _syncService.peers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MESH PEERS (${peers.length})', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (peers.isEmpty) 
          Text('No peers connected yet', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
        ...peers.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: p.status == PeerStatus.approved ? AppTheme.accentGreen : AppTheme.accentOrange, radius: 4),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(p.id, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ])),
                  if (p.status == PeerStatus.pending) ...[
                    IconButton(icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 20), onPressed: () => _updatePeerStatus(p.id, PeerStatus.approved)),
                    IconButton(icon: const Icon(Icons.cancel_rounded, color: AppTheme.accentRed, size: 20), onPressed: () => _updatePeerStatus(p.id, PeerStatus.denied)),
                  ] else ...[
                    TextButton(onPressed: () => _updatePeerStatus(p.id, PeerStatus.pending), child: const Text('Reset', style: TextStyle(fontSize: 10))),
                  ],
                ],
              ),
              if (p.status == PeerStatus.approved) ...[
                const Divider(height: 24, color: AppTheme.border),
                Text('GRANULAR ACCESS', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._syncService.sharedRepos.map((repoId) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(repoId, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      _roleChip(p, repoId),
                    ],
                  ),
                )),
              ],
            ],
          ),
        )),
      ],
    );
  }

  Widget _roleChip(Peer p, String repoId) {
    final role = p.repoRoles[repoId];
    return PopupMenuButton<PeerRole>(
      onSelected: (r) {
        _syncService.updatePeerRepoRole(p.id, repoId, r);
        setState(() {});
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: PeerRole.read, child: Text('Read Only')),
        const PopupMenuItem(value: PeerRole.write, child: Text('Read & Write')),
        const PopupMenuItem(value: PeerRole.admin, child: Text('Admin')),
        PopupMenuItem(
          onTap: () {
            _syncService.updatePeerRepoRole(p.id, repoId, PeerRole.read); // default back
            p.repoRoles.remove(repoId);
            setState(() {});
          },
          child: const Text('Revoke Access', style: TextStyle(color: AppTheme.accentRed)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: role != null ? _getRoleColor(role).withOpacity(0.1) : AppTheme.border.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: role != null ? _getRoleColor(role).withOpacity(0.3) : AppTheme.border),
        ),
        child: Text(
          role?.name.toUpperCase() ?? 'NO ACCESS',
          style: TextStyle(
            color: role != null ? _getRoleColor(role) : AppTheme.textMuted,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(PeerRole role) {
    switch (role) {
      case PeerRole.read: return AppTheme.textMuted;
      case PeerRole.write: return AppTheme.accentCyan;
      case PeerRole.admin: return AppTheme.accentPurple;
    }
  }

  void _updatePeerStatus(String id, PeerStatus s) {
    _syncService.updatePeerStatus(id, s);
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
