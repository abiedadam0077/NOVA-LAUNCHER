import 'package:go_router/go_router.dart';

import '../presentation/shell.dart';
import '../presentation/dashboard_screen.dart';
import '../presentation/versions_screen.dart';
import '../presentation/content_screen.dart';
import '../presentation/account_screen.dart';
import '../presentation/settings_screen.dart';
import '../presentation/splash_screen.dart';
import '../presentation/file_manager_screen.dart';
import '../presentation/servers_screen.dart';
import '../presentation/game_settings_screen.dart';
import '../presentation/about_screen.dart';

final GoRouter novaRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/versions', builder: (c, s) => const VersionsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/content', builder: (c, s) => const ContentScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/settings/files', builder: (c, s) => const FileManagerScreen()),
    GoRoute(path: '/settings/servers', builder: (c, s) => const ServersScreen()),
    GoRoute(
        path: '/settings/game', builder: (c, s) => const GameSettingsScreen()),
    GoRoute(path: '/settings/about', builder: (c, s) => const AboutScreen()),
  ],
);
