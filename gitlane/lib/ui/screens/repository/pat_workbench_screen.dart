import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_theme.dart';
import '../../../services/pat_service.dart';
import '../../widgets/empty_state.dart';
import 'package:flutter/services.dart';

class PATWorkbenchScreen extends StatefulWidget {
  const PATWorkbenchScreen({super.key});

  @override
  State<PATWorkbenchScreen> createState() => _PATWorkbenchScreenState();
}

class _PATWorkbenchScreenState extends State<PATWorkbenchScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tokens = [];

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _isLoading = true);
    await PATService.cleanupExpiredTokens();
    final tokens = await PATService.getTokens();
    
    if (mounted) {
      setState(() {
        _tokens = tokens;
        _isLoading = false;
      });
    }
  }

  void _showAddTokenDialog() {
    final labelCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    int expiresInDays = 30; // Default 30 days
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.bg1,
          title: Text(
            'Add Access Token',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Label (e.g., Work Laptop)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Personal Access Token',
                  hintText: 'ghp_xxxxxxxxxxx',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Expires in (Days):',
                style: GoogleFonts.inter(color: context.textSecondary, fontSize: 13),
              ),
              Slider(
                value: expiresInDays.toDouble(),
                min: 1,
                max: 365,
                divisions: 364,
                activeColor: context.accentGreen,
                label: '$expiresInDays Days',
                onChanged: (val) {
                  setDialogState(() => expiresInDays = val.toInt());
                },
              ),
              Center(
                child: Text(
                  '$expiresInDays Days',
                  style: GoogleFonts.firaMono(color: context.accentGreen, fontSize: 13),
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: context.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.accentGreen),
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final t = tokenCtrl.text.trim();
                if (label.isNotEmpty && t.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  await PATService.addToken(label, t, expiresInDays);
                  _loadTokens();
                }
              },
              child: const Text('Save Token', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteToken(String id) async {
    setState(() => _isLoading = true);
    await PATService.deleteToken(id);
    _loadTokens();
  }

  Future<void> _makeActive(String id) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    await PATService.setActiveToken(id);
    _loadTokens();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg0,
      appBar: AppBar(
        backgroundColor: context.bg1,
        title: Text(
          'PAT Manager',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accentGreen))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _tokens.isEmpty ? _buildEmptyState() : _buildTokenList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTokenDialog,
        backgroundColor: context.accentGreen,
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.black),
        label: const Text("Add PAT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.bg1,
        border: Border(bottom: BorderSide(color: context.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: context.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Access Tokens',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Manage GitHub Personal Access Tokens. Select an active token for pushing/pulling. Expired tokens are automatically purged.',
            style: GoogleFonts.inter(color: context.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.key_off_rounded,
      title: 'No Tokens Configured',
      subtitle: 'Add a Personal Access Token to authenticate with remote repositories.',
    );
  }

  Widget _buildTokenList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100), // padding for fab
      itemCount: _tokens.length,
      itemBuilder: (context, index) {
        final t = _tokens[index];
        final id = t['id'];
        final label = t['label'];
        final isActive = t['isActive'] == true;
        
        final addedDate = DateTime.parse(t['addedAt']);
        final expiresDays = t['expiresInDays'] as int;
        final expiryDate = addedDate.add(Duration(days: expiresDays));
        final formatExp = "\${expiryDate.year}-\${expiryDate.month.toString().padLeft(2, '0')}-\${expiryDate.day.toString().padLeft(2, '0')}";

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Slidable(
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _deleteToken(id),
                  backgroundColor: context.accentRed,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline_rounded,
                  label: 'Revoke',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _makeActive(id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: context.bg1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? context.accentGreen : context.border,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: isActive ? context.accentGreen : context.textMuted,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: context.accentOrange),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Expires: $formatExp',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.firaMono(
                                      color: context.accentOrange,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.accentGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              color: context.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}