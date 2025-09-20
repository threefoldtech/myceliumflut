import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myceliumflut/app/theme/tokens.dart';
import 'package:myceliumflut/app/widgets/app_card.dart';
import 'package:myceliumflut/app/widgets/app_scaffold.dart';
import 'package:myceliumflut/state/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.themeMode == ThemeMode.dark;

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
              const Spacer(),
              const Text(
                'Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const SizedBox(width: 48),
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
                _InfoRowWithSubtitle(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: const Icon(Icons.phone_android, size: 16),
                  ),
                  title: 'Mobile App',
                  subtitle: 'Application Build Version',
                  value: 'v1.0.12',
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
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Decentralized networking for everyone',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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
                style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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
