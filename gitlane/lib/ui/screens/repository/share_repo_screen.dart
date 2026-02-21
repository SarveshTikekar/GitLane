import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ShareRepoScreen extends StatelessWidget {
  final String repoName;
  final String remoteUrl;

  const ShareRepoScreen({
    super.key,
    required this.repoName,
    required this.remoteUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Share Repository"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share_rounded, color: AppTheme.accentCyan, size: 48),
                const SizedBox(height: 16),
                Text(
                  repoName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Scan this code to clone this repository",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textDim, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: remoteUrl,
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  remoteUrl,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppTheme.accentCyan,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Copy to clipboard or share via native share
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Link ready for sharing!")),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text("Copy Link"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
