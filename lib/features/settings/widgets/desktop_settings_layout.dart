import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/app_card.dart';
import '../../../state/app_settings.dart';
import '../../../state/app_info_providers.dart';
import '../../../state/node_address_provider.dart';

class DesktopSettingsLayout extends ConsumerWidget {
  const DesktopSettingsLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.themeMode == ThemeMode.dark;
    final appVersionAsync = ref.watch(fullAppVersionProvider);
    final nodeAddressAsync = ref.watch(nodeAddressProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main settings content
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Appearance Settings Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.color_lens, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Appearance',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dark Mode',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  isDark
                                      ? 'Dark theme is enabled for better viewing in low light'
                                      : 'Light theme is enabled for daytime use',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            inactiveThumbColor:
                                Theme.of(context).colorScheme.primary,
                            value: isDark,
                            onChanged: (v) => settings.toggleDark(v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Network Information Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.language, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Network Information',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Consumer(
                      builder: (context, ref, child) {
                        return nodeAddressAsync.when(
                          data: (nodeAddress) => _NetworkInfoRow(
                            icon: Icons.public,
                            title: 'Mycelium Node Address',
                            subtitle: 'Your unique network identifier',
                            value: nodeAddress.isNotEmpty
                                ? nodeAddress
                                : 'Not Available',
                            copyEnabled: nodeAddress.isNotEmpty,
                          ),
                          loading: () => _NetworkInfoRow(
                            icon: Icons.public,
                            title: 'Mycelium Node Address',
                            subtitle: 'Your unique network identifier',
                            value: 'Loading...',
                            copyEnabled: false,
                          ),
                          error: (error, stack) => _NetworkInfoRow(
                            icon: Icons.public,
                            title: 'Mycelium Node Address',
                            subtitle: 'Your unique network identifier',
                            value: 'Error loading address',
                            copyEnabled: false,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.xxl),

        // Version info sidebar
        SizedBox(
          width: 320,
          child: Column(
            children: [
              // Version Information Card
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.info_outline, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Version Information',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _VersionInfoRow(
                      icon: CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: const Text('M',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: 'Mycelium Core',
                      subtitle: 'Network Protocol Version',
                      value: 'v0.6.2',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Consumer(
                      builder: (context, ref, child) {
                        return appVersionAsync.when(
                          data: (version) => _VersionInfoRow(
                            icon: CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              child:
                                  const Icon(Icons.desktop_windows, size: 14),
                            ),
                            title: 'Desktop App',
                            subtitle: 'Application Build Version',
                            value: version,
                          ),
                          loading: () => _VersionInfoRow(
                            icon: CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              child:
                                  const Icon(Icons.desktop_windows, size: 14),
                            ),
                            title: 'Desktop App',
                            subtitle: 'Application Build Version',
                            value: 'Loading...',
                          ),
                          error: (error, stack) => _VersionInfoRow(
                            icon: CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              child:
                                  const Icon(Icons.desktop_windows, size: 14),
                            ),
                            title: 'Desktop App',
                            subtitle: 'Application Build Version',
                            value: 'Error',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // About Card
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.favorite, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'About Mycelium',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '© 2024 Mycelium Network',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Decentralized networking for everyone. Mycelium creates secure, peer-to-peer connections for a truly distributed internet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () {
                        _openGitHubLink(context);
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Learn More'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openGitHubLink(BuildContext context) async {
    const gitHubUrl = 'https://github.com/threefoldtech/mycelium';

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', gitHubUrl]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [gitHubUrl]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [gitHubUrl]);
      }
    } catch (e) {
      // Fallback: copy to clipboard if opening fails
      Clipboard.setData(const ClipboardData(text: gitHubUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _VersionInfoRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final String value;

  const _VersionInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool copyEnabled;

  const _NetworkInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.copyEnabled,
  });

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Node address copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (copyEnabled) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyToClipboard(context, value),
                  tooltip: 'Copy Node Address',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(40, 40),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
