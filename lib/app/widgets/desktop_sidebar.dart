import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:go_router/go_router.dart';
import '../theme/tokens.dart';

class DesktopSidebar extends StatelessWidget {
  final int currentIndex;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo section
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Center(
              child: Image.asset(
                Theme.of(context).brightness == Brightness.light
                    ? 'assets/images/mycelium_white.png'
                    : 'assets/images/mycelium_color.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Navigation items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  _SidebarItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                    onTap: () => context.go('/'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SidebarItem(
                    icon: Icons.hub_outlined,
                    selectedIcon: Icons.hub,
                    label: 'Peers',
                    isSelected: currentIndex == 1,
                    onTap: () => context.go('/peers'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (defaultTargetPlatform == TargetPlatform.macOS) ...[
                    _SidebarItem(
                      icon: Icons.vpn_lock_outlined,
                      selectedIcon: Icons.vpn_lock,
                      label: 'VPN',
                      isSelected: currentIndex == 2,
                      onTap: () => context.go('/vpn'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    isSelected: currentIndex == 3,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ),

          // Footer with version info
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '© 2024 Mycelium Network',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'v0.10.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: isSelected
                ? Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
