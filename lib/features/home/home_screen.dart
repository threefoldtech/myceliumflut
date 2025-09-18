import 'package:flutter/material.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../app/widgets/app_button.dart';
import '../../app/widgets/app_card.dart';
import '../../app/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/mycelium_providers.dart';
import '../../services/ffi/mycelium_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(nodeStatusProvider);
    final service = ref.read(myceliumServiceProvider);
    final status = statusAsync.asData?.value ?? NodeStatus.disconnected;
    return AppScaffold(
      title: 'Home',
      currentIndex: 0,
      onTabSelected: null,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          _HeaderCard(
            status: status,
            onConnect: () async {
              await service.start(['tcp://185.69.166.7:9651']);
            },
            onDisconnect: () async {
              await service.stop();
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _ActionsRow(),
          const SizedBox(height: AppSpacing.xxl),
          const _StatsRow(),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final NodeStatus status;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _HeaderCard({required this.status, required this.onConnect, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(status == NodeStatus.connected ? Icons.wifi : Icons.wifi_off, size: 40),
          const SizedBox(height: AppSpacing.lg),
          Text(
            status == NodeStatus.connected
                ? 'Mycelium Started'
                : status == NodeStatus.connecting
                    ? 'Starting Mycelium...'
                    : status == NodeStatus.failed
                        ? 'Start Failed'
                        : 'Mycelium Stopped',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Tap to start the Mycelium node', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: status == NodeStatus.connected ? 'Stop Mycelium' : 'Start Mycelium',
            onPressed: status == NodeStatus.connected ? onDisconnect : onConnect,
            isLoading: status == NodeStatus.connecting,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow();

  @override
  Widget build(BuildContext context) {
    // Use a simple column to avoid Expanded in unbounded height (ListView context)
    return Column(
      children: [
        AppCard(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.restart_alt_rounded), SizedBox(width: AppSpacing.sm), Flexible(child: Text('Restart Mycelium', overflow: TextOverflow.ellipsis))])),
        const SizedBox(height: AppSpacing.lg),
        AppCard(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Flexible(child: Text('Advanced Options', overflow: TextOverflow.ellipsis)), Icon(Icons.chevron_right)])),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    Widget tileContent(IconData icon, String title, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        );

    return LayoutBuilder(builder: (context, constraints) {
      final double spacing = AppSpacing.lg;
      final int columns = constraints.maxWidth >= 800
          ? 3
          : constraints.maxWidth >= 500
              ? 2
              : 1;
      final double itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      final items = [
        SizedBox(
          width: itemWidth,
          child: AppCard(margin: EdgeInsets.zero, child: tileContent(Icons.people, 'Peers', '8')),
        ),
        SizedBox(
          width: itemWidth,
          child: AppCard(margin: EdgeInsets.zero, child: tileContent(Icons.podcasts, 'Bandwidth', '2.4 MB/s')),
        ),
        SizedBox(
          width: itemWidth,
          child: AppCard(margin: EdgeInsets.zero, child: tileContent(Icons.access_time, 'Uptime', '2h 34m')),
        ),
      ];
      return Wrap(spacing: spacing, runSpacing: spacing, children: items);
    });
  }
}


