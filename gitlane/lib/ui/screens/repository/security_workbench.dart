import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'ssh_workbench_screen.dart';
import 'gpg_workbench.dart';

class SecurityWorkbench extends StatelessWidget {
  const SecurityWorkbench({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.bg0,
        appBar: AppBar(
          backgroundColor: AppTheme.bg0,
          title: Text(
            'Security Workbench',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.accentPurple,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: "SSH KEYS", icon: Icon(Icons.vpn_key_rounded, size: 20)),
              Tab(text: "GPG KEYS", icon: Icon(Icons.verified_user_rounded, size: 20)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SSHWorkbenchScreen(),
            GPGWorkbench(),
          ],
        ),
      ),
    );
  }
}
