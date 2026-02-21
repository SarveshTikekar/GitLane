import 'ui/theme/app_theme.dart';
import 'ui/screens/home/dashboard_screen.dart';

void main() {
  runApp(const GitLaneApp());
}

class GitLaneApp extends StatelessWidget {
  const GitLaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitLane',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
