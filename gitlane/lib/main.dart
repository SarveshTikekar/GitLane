import 'package:flutter/material.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home/dashboard_screen.dart';

void main() {
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
