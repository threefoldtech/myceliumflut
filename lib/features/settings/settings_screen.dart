import 'package:flutter/material.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../app/widgets/app_card.dart';
import '../../app/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.themeMode == ThemeMode.dark;
    return AppScaffold(
      title: 'Settings',
      currentIndex: 2,
      onTabSelected: null,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version Information', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                _InfoRow(title: 'Mycelium Core', value: 'v2.1.4'),
                const SizedBox(height: AppSpacing.lg),
                _InfoRow(title: 'Mobile App', value: 'v1.0.12'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dark Mode', style: Theme.of(context).textTheme.titleMedium),
                Switch(value: isDark, onChanged: (v) => settings.toggleDark(v)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(value, style: Theme.of(context).textTheme.labelMedium),
        ),
      ],
    );
  }
}


