import 'package:flutter/material.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home/dashboard_screen.dart';
import 'services/git_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GitSyncService.recoverPendingTxOnStartup(); // also starts connectivity watcher
  runApp(const GitLaneApp());
}

class GitLaneApp extends StatelessWidget {
  const GitLaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'GitLane',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const DashboardScreen(),
        );
      },
    );
  }
}
