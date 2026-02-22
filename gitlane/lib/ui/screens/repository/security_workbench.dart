import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'ssh_workbench_screen.dart';
import 'gpg_workbench.dart';
import 'pat_workbench_screen.dart';

class SecurityWorkbench extends StatelessWidget {
  const SecurityWorkbench({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.bg0,
        appBar: AppBar(
          backgroundColor: context.bg0,
          title: Text(
            'Security Workbench',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            indicatorColor: context.accentPurple,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            labelColor: Colors.white,
            unselectedLabelColor: context.textMuted,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: "SSH KEYS", icon: Icon(Icons.vpn_key_rounded, size: 20)),
              Tab(text: "GPG KEYS", icon: Icon(Icons.verified_user_rounded, size: 20)),
              Tab(text: "PAT TOKENS", icon: Icon(Icons.token_rounded, size: 20)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SSHWorkbenchScreen(),
            GPGWorkbench(),
            PATWorkbenchScreen(),
          ],
        ),
      ),
    );
  }
}
