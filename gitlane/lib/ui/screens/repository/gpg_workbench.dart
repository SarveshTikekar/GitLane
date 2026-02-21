import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/gpg_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GPGWorkbench extends StatefulWidget {
  const GPGWorkbench({super.key});

  @override
  State<GPGWorkbench> createState() => _GPGWorkbenchState();
}

class _GPGWorkbenchState extends State<GPGWorkbench> {
  List<String> _keys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshKeys();
  }

  Future<void> _refreshKeys() async {
    setState(() => _isLoading = true);
    final keys = await GPGService.listKeys();
    setState(() {
      _keys = keys;
      _isLoading = false;
    });
  }

  Future<void> _importKey() async {
    final keyController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        title: Text("Import GPG Key", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Paste your GPG private key block below.", style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              maxLines: 8,
              style: GoogleFonts.firaCode(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.bg1,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: "-----BEGIN PGP PRIVATE KEY BLOCK-----",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
            child: const Text("Import", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (result == true && keyController.text.trim().isNotEmpty) {
      // Logic for importing key would go here
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Importing GPG keys is a placeholder in this demo.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        title: const Text("GPG Workbench"),
        backgroundColor: AppTheme.bg0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refreshKeys),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _keys.isEmpty ? _buildEmptyState() : _buildKeyList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importKey,
        backgroundColor: AppTheme.accentCyan,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text("Import GPG Key", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Commit Security", style: GoogleFonts.inter(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Manage GPG keys to sign your commits and verify your identity on GitHub/GitLab.", 
            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text("No GPG Keys Configured", style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text("Import a PGP key to start signing commits.", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKeyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _keys.length,
      itemBuilder: (context, index) {
        final key = _keys[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.bg2,
              child: Icon(Icons.verified_rounded, color: AppTheme.accentCyan, size: 20),
            ),
            title: Text(key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text("GPG Key • Verified", style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ),
        );
      },
    );
  }
}
