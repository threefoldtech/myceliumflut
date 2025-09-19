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

    final buttonColor = Theme.of(context).colorScheme.primary;
    final onButtonColor = Theme.of(context).colorScheme.onPrimary;

    return AppScaffold(
      title: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: buttonColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/mycelium_icon.png',
              height: 32,
            ),
            const SizedBox(width: 8),
            Text(
              'Mycelium',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: onButtonColor,
              ),
            ),
          ],
        ),
      ),
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
          const _StatsRow(),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatefulWidget {
  final NodeStatus status;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  const _HeaderCard({
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  State<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<_HeaderCard> {
  bool _isLoading = false;

  bool get isRestartVisible =>
      widget.status == NodeStatus.connected && !_isLoading;

  Future<void> startMycelium() async {
    setState(() => _isLoading = true);
    await widget.onConnect();
    setState(() => _isLoading = false);
  }

  Future<void> stopMycelium() async {
    setState(() => _isLoading = true);
    await widget.onDisconnect();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == NodeStatus.connected;
    final isConnecting = _isLoading || widget.status == NodeStatus.connecting;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              size: 32,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isConnected
                ? 'Mycelium Started'
                : isConnecting
                    ? 'Starting Mycelium...'
                    : widget.status == NodeStatus.failed
                        ? 'Start Failed'
                        : 'Mycelium Stopped',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap to start the Mycelium node',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: isConnected ? 'Stop Mycelium' : 'Start Mycelium',
            onPressed: isConnected ? stopMycelium : startMycelium,
            isLoading: isConnecting,
          ),
          const SizedBox(height: AppSpacing.lg),
          Visibility(
            visible: isRestartVisible,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).cardColor, 
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        child: Icon(Icons.restart_alt_rounded, size: 20),
                      ),
                      TextSpan(text: " Restart Mycelium"),
                    ],
                  ),
                ),
                onPressed: () async {
                  await stopMycelium();
                  await startMycelium();
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            margin: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Flexible(
                  child:
                      Text('Advanced Options', overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    Widget tileContent(IconData icon, String title, String value) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: tileContent(Icons.people, 'Peers', '8'),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: tileContent(Icons.podcasts, 'Bandwidth', '2 MB/s'),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: tileContent(Icons.access_time, 'Uptime', '2h 34m'),
            ),
          ),
        ],
      ),
    );
  }
}

// TODO: VPN implemented or not and if yes, how to get its data ?
//TODO: How to get num of peers, bandwidth, uptime ??
//TODO: How to get All data in peers screen ?
// TODO: what is the input to add a peer ?
