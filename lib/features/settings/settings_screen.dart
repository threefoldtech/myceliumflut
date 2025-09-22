import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myceliumflut/app/theme/tokens.dart';
import 'package:myceliumflut/app/widgets/app_card.dart';
import 'package:myceliumflut/app/widgets/app_scaffold.dart';
import 'package:myceliumflut/state/app_settings.dart';
import 'package:myceliumflut/state/app_info_providers.dart';
import 'package:myceliumflut/state/node_address_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.themeMode == ThemeMode.dark;
    final appVersionAsync = ref.watch(fullAppVersionProvider);
    final nodeAddressAsync = ref.watch(nodeAddressProvider);

    return AppScaffold(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
              const Text(
                'Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context)
                .dividerColor, // You can use Theme.of(context).dividerColor for theme-aware color
          ),
        ],
      ),
      currentIndex: 2,
      onTabSelected: null,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Version Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _InfoRowWithSubtitle(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: const Text('M',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: 'Mycelium Core',
                  subtitle: 'Network Protocol Version',
                  value: 'v0.6.2',
                ),
                const SizedBox(height: AppSpacing.lg),
                Consumer(
                  builder: (context, ref, child) {
                    return appVersionAsync.when(
                      data: (version) => _InfoRowWithSubtitle(
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.phone_android, size: 16),
                        ),
                        title: 'Mobile App',
                        subtitle: 'Application Build Version',
                        value: version,
                      ),
                      loading: () => _InfoRowWithSubtitle(
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.phone_android, size: 16),
                        ),
                        title: 'Mobile App',
                        subtitle: 'Application Build Version',
                        value: 'Loading...',
                      ),
                      error: (error, stack) => _InfoRowWithSubtitle(
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.phone_android, size: 16),
                        ),
                        title: 'Mobile App',
                        subtitle: 'Application Build Version',
                        value: 'Error',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Network Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Consumer(
                  builder: (context, ref, child) {
                    return nodeAddressAsync.when(
                      data: (nodeAddress) => _InfoRowWithCopy(
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.public, size: 16),
                        ),
                        title: 'IP Address',
                        subtitle: 'Your Mycelium Node Address',
                        value: nodeAddress.isNotEmpty
                            ? nodeAddress
                            : 'Not Available',
                        copyEnabled: nodeAddress.isNotEmpty,
                      ),
                      loading: () => _InfoRowWithCopy(
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.public, size: 16),
                        ),
                        title: 'IP Address',
                        subtitle: 'Your Mycelium Node Address',
                        value: 'Loading...',
                        copyEnabled: false,
                      ),
                      error: (error, stack) => _InfoRowWithCopy(
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.public, size: 16),
                        ),
                        title: 'IP Address',
                        subtitle: 'Your Mycelium Node Address',
                        value: 'Error',
                        copyEnabled: false,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: const Icon(Icons.color_lens, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dark Mode',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          isDark
                              ? 'Dark theme is enabled'
                              : 'Light theme is enabled',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6)),
                        ),
                      ],
                    ),
                    Switch(
                      value: isDark,
                      onChanged: (v) => settings.toggleDark(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ' 2024 Mycelium Network',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Decentralized networking for everyone',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRowWithSubtitle extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final String value;

  const _InfoRowWithSubtitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.bodyMedium),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(value, style: textTheme.labelMedium),
        ),
      ],
    );
  }
}

class _InfoRowWithCopy extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final String value;
  final bool copyEnabled;

  const _InfoRowWithCopy({
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
        content: Text('IP Address copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyMedium),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  value,
                  style: textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (copyEnabled) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copyToClipboard(context, value),
                tooltip: 'Copy IP Address',
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
