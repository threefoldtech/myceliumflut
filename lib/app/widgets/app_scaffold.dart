import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import '../theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'responsive_layout.dart';
import 'desktop_layout.dart';

class AppScaffold extends StatelessWidget {
  final Widget title;
  final Widget child;
  final int currentIndex;
  final ValueChanged<int>? onTabSelected;

  const AppScaffold(
      {super.key,
      required this.title,
      required this.child,
      this.currentIndex = 0,
      this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Image.asset(
          Theme.of(context).brightness == Brightness.light
              ? 'assets/images/mycelium_white.png'
              : 'assets/images/mycelium_color.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight -
                  80, // approximate bottom nav height
            ),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabSelected ??
            (index) {
              final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.windows;
              if (!isDesktop && index >= 2) {
                // Skip VPN tab on mobile platforms, adjust index
                index++;
              }
              switch (index) {
                case 0:
                  if (context.mounted) context.go('/');
                  break;
                case 1:
                  if (context.mounted) context.go('/peers');
                  break;
                case 2:
                  if (context.mounted) context.go('/vpn');
                  break;
                case 3:
                  if (context.mounted) context.go('/settings');
                  break;
              }
            },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'Peers'),
          if (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows)
            const NavigationDestination(
                icon: Icon(Icons.vpn_lock_outlined),
                selectedIcon: Icon(Icons.vpn_lock),
                label: 'VPN'),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return DesktopLayout(
      title: title,
      currentIndex: currentIndex,
      child: child,
    );
  }
}
