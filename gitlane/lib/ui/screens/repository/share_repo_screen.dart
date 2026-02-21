import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';

import '../../../services/git_service.dart';
import '../../widgets/glass_card.dart';

class ShareRepoScreen extends StatefulWidget {
  final String repoName;
  final String repoPath;
  final String remoteUrl;

  const ShareRepoScreen({
    super.key,
    required this.repoName,
    required this.repoPath,
    required this.remoteUrl,
  });

  @override
  State<ShareRepoScreen> createState() => _ShareRepoScreenState();
}

class _ShareRepoScreenState extends State<ShareRepoScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 360;
    final qrSize = (screenWidth * 0.6).clamp(160.0, 240.0);

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: Text(
          'Share Repository',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 32,
              vertical: 32,
            ),
            child: Column(
              children: [
                // Repo name card
                _buildRepoInfo(compact),
                const SizedBox(height: 28),

                // QR code
                _buildQrCode(qrSize, compact),
                const SizedBox(height: 24),

                // URL Display
                _buildUrlDisplay(compact),
                const SizedBox(height: 32),

                // Actions
                _buildActionButtons(compact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepoInfo(bool compact) {
    return GlassCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      accentBorder: AppTheme.accentCyan,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_rounded, color: AppTheme.accentCyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.repoName, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: compact ? 16 : 18, fontWeight: FontWeight.bold)),
                Text('Scan QR or export bundle for P2P', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCode(double size, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppTheme.accentCyan.withValues(alpha: 0.2), blurRadius: 24),
        ],
      ),
      child: QrImageView(
        data: widget.remoteUrl,
        version: QrVersions.auto,
        size: size,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
      ),
    );
  }

  Widget _buildUrlDisplay(bool compact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        widget.remoteUrl,
        style: GoogleFonts.firaMono(color: AppTheme.accentCyan, fontSize: compact ? 10 : 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons(bool compact) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.remoteUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ URL copied to clipboard')));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Remote URL'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : _exportBundle,
            icon: _isExporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentOrange))
                : const Icon(Icons.archive_rounded, size: 16, color: AppTheme.accentOrange),
            label: Text(_isExporting ? 'Exporting...' : 'Export Offline Bundle (.bundle)', style: const TextStyle(color: AppTheme.accentOrange)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.accentOrange),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportBundle() async {
    setState(() => _isExporting = true);
    final bundlePath = '${widget.repoPath}/../${widget.repoName}.bundle';
    final result = await GitService.createBundle(widget.repoPath, bundlePath);
    setState(() => _isExporting = false);

    if (result == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentGreen, content: Text('✓ Bundle exported to: ${widget.repoName}.bundle')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRed, content: Text('Error creating bundle: $result')),
      );
    }
  }
}
