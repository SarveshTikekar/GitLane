import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/ssh_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SSHWorkbenchScreen extends StatefulWidget {
  const SSHWorkbenchScreen({super.key});

  @override
  State<SSHWorkbenchScreen> createState() => _SSHWorkbenchScreenState();
}

class _SSHWorkbenchScreenState extends State<SSHWorkbenchScreen> {
  List<SSHKey> _keys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshKeys();
  }

  Future<void> _refreshKeys() async {
    setState(() => _isLoading = true);
    final keys = await SSHService.listKeys();
    setState(() {
      _keys = keys;
      _isLoading = false;
    });
  }

  Future<void> _generateNewKey() async {
    final labelController = TextEditingController();
    int bits = 2048;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bg2,
          title: Text("Generate SSH Key", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Key Label",
                  hintText: "e.g. My Phone Pro",
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: bits,
                dropdownColor: AppTheme.bg1,
                decoration: const InputDecoration(labelText: "Key Strength (RSA)"),
                items: const [
                  DropdownMenuItem(value: 2048, child: Text("2048-bit", style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 4096, child: Text("4096-bit", style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) => setDialogState(() => bits = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPurple),
              child: const Text("Generate", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );

    if (result == true && labelController.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      final pubKey = await SSHService.generateKey(labelController.text.trim(), bits: bits);
      if (pubKey.startsWith("ssh-rsa")) {
        if (mounted) {
          _refreshKeys();
          _showPublicKey(labelController.text.trim(), pubKey);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $pubKey")));
        }
      }
    }
  }

  void _showPublicKey(String label, String pubKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.key_rounded, color: AppTheme.accentPurple),
                const SizedBox(width: 12),
                Text("Public Key: $label", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSlate.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                pubKey,
                style: GoogleFonts.firaCode(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pubKey));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text("Copy Public Key"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteKey(String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        title: const Text("Delete SSH Key?"),
        content: Text("This will permanently remove '$label'. You cannot undo this action."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SSHService.deleteKey(label);
      _refreshKeys();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _keys.isEmpty ? _buildEmptyState() : _buildKeyList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateNewKey,
        backgroundColor: AppTheme.accentPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text("Generate New Key", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Secure Authentication", style: GoogleFonts.inter(color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Manage your on-device cryptographic keys for secure Git operations over SSH.", 
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
          Icon(Icons.vpn_key_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text("No SSH Keys Found", style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text("Generate your first key to get started.", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
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
              child: Icon(Icons.key_rounded, color: AppTheme.accentPurple, size: 20),
            ),
            title: Text(key.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("${key.type} • Created ${key.created.toLocal().toString().split(' ')[0]}", 
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'copy') SSHService.getPublicKey(key.label).then((k) => _showPublicKey(key.label, k));
                if (val == 'delete') _deleteKey(key.label);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18), SizedBox(width: 8), Text("Copy Public Key")])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent), SizedBox(width: 8), Text("Delete Key", style: TextStyle(color: Colors.redAccent))])),
              ],
            ),
          ),
        );
      },
    );
  }
}
