import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/peers/peers_screen.dart';
import '../../features/vpn/vpn_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) => const MaterialPage(child: HomeScreen()),
    ),
    GoRoute(
      path: '/peers',
      name: 'peers',
      pageBuilder: (context, state) => const MaterialPage(child: PeersScreen()),
    ),
    GoRoute(
      path: '/vpn',
      name: 'vpn',
      pageBuilder: (context, state) => const MaterialPage(child: VpnScreen()),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) =>
          const MaterialPage(child: SettingsScreen()),
    ),
  ],
);
