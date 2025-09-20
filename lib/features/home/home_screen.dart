import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../app/widgets/app_button.dart';
import '../../models/peer_models.dart' as peer_models;
import '../../services/peers_service.dart';
import '../../state/mycelium_providers.dart';
import '../../services/ffi/mycelium_service.dart';
import 'widgets/traffic_summary.dart';
import '../../state/dynamic_traffic_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(nodeStatusProvider);
    final service = ref.read(myceliumServiceProvider);
    final peersAsync = ref.watch(peersProvider);
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
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return const SizedBox(height: AppSpacing.xxl);
            case 1:
              return _HeaderCard(
                status: status,
                onConnect: () async {
                  final peers = peersAsync.asData?.value ?? [];
                  if (peers.isNotEmpty) {
                    await service.start(peers);
                  } else {
                    // Fallback to PeersService if no peers available
                    final peersService = PeersService();
                    final fallbackPeers = await peersService.fetchPeers();
                    await service.start(fallbackPeers);
                  }
                },
                onDisconnect: () async {
                  await service.stop();
                },
                service: service,
              );
            case 2:
              return Column(
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  const _StatsRow(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            case 3:
              return Consumer(
                builder: (context, ref, child) {
                  final trafficStats = ref.watch(dynamicTrafficProvider);

                  return TrafficSummary(
                    totalUpload: trafficStats.totalUploadFormatted,
                    totalDownload: trafficStats.totalDownloadFormatted,
                    peakUpload: trafficStats.peakUploadFormatted,
                    peakDownload: trafficStats.peakDownloadFormatted,
                  );
                },
              );
            case 4:
              return const SizedBox(height: AppSpacing.xxxl);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

class _HeaderCard extends StatefulWidget {
  final NodeStatus status;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final dynamic service;

  const _HeaderCard({
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
    required this.service,
  });

  @override
  State<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<_HeaderCard> {
  bool _isLoading = false;
  bool _isSocks5Enabled = false;

  bool get isRestartVisible =>
      widget.status == NodeStatus.connected && !_isLoading;

  Future<void> startMycelium() async {
    setState(() => _isLoading = true);
    await widget.onConnect();
    setState(() => _isLoading = false);
  }

  Future<void> stopMycelium() async {
    setState(() => _isLoading = true);

    // Stop proxy first if it's enabled
    if (_isSocks5Enabled) {
      try {
        await widget.service.proxyDisconnect();
        await widget.service.stopProxyProbe();
        setState(() => _isSocks5Enabled = false);
      } catch (e) {
        print('Error stopping proxy: $e');
      }
    }

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
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
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
          if (widget.status == NodeStatus.connected) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Flexible(
                      child: Text('Advanced Options',
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(Icons.expand_more),
                  ],
                ),
                children: [
                  ListTile(
                    title: const Text('Enable SOCKS5 tunneling as VPN'),
                    trailing: Switch(
                      value: _isSocks5Enabled,
                      onChanged: (value) async {
                        setState(() => _isSocks5Enabled = value);
                        if (value) {
                          // First start proxy probing to discover available proxies
                          await widget.service.startProxyProbe();
                          // Wait a bit for probes to discover proxies
                          await Future.delayed(Duration(seconds: 10));
                          // Then connect to best available proxy
                          final result = await widget.service.proxyConnect(
                              '[40a:152c:b85b:9646:5b71:d03a:eb27:2462]:1080');
                          debugPrint('Proxy connect result: $result');
                        } else {
                          final result = await widget.service.proxyDisconnect();
                          // Stop proxy probing when disabled
                          await widget.service.stopProxyProbe();
                          debugPrint('Proxy disconnect result: $result');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeStatusAsync = ref.watch(nodeStatusProvider);
    final uptimeNotifier = ref.watch(uptimeProvider.notifier);

    return nodeStatusAsync.when(
      loading: () => _buildStatsCards(context, [], uptimeNotifier),
      error: (error, stack) => _buildStatsCards(context, [], uptimeNotifier),
      data: (status) {
        if (status == NodeStatus.connected) {
          return _ConnectedStatsRow(uptimeNotifier: uptimeNotifier);
        } else {
          return _buildStatsCards(context, [], uptimeNotifier);
        }
      },
    );
  }

  Widget _buildStatsCards(BuildContext context,
      List<peer_models.PeerStats> peerStatus, UptimeNotifier uptimeNotifier) {
    final networkTraffic = _calculateNetworkTraffic(peerStatus);

    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Connected Peers',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${peerStatus.length}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Uptime',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  uptimeNotifier.formattedUptime,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Traffic',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  networkTraffic['total'] ?? '0 B',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _calculateNetworkTraffic(
      List<peer_models.PeerStats> peerStatus) {
    int totalRx = 0;
    int totalTx = 0;

    for (final peer in peerStatus) {
      totalRx += peer.rxBytes;
      totalTx += peer.txBytes;
    }
    final totalTraffic = totalRx + totalTx;
    return {
      'rx': peer_models.PeerStats.formatBytes(totalRx),
      'tx': peer_models.PeerStats.formatBytes(totalTx),
      'total': peer_models.PeerStats.formatBytes(totalTraffic),
    };
  }
}

class _ConnectedStatsRow extends ConsumerStatefulWidget {
  final UptimeNotifier uptimeNotifier;

  const _ConnectedStatsRow({required this.uptimeNotifier});

  @override
  ConsumerState<_ConnectedStatsRow> createState() => _ConnectedStatsRowState();
}

class _ConnectedStatsRowState extends ConsumerState<_ConnectedStatsRow> {
  List<peer_models.PeerStats> peerStatus = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchPeerStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchPeerStatus();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPeerStatus() async {
    try {
      final service = MyceliumService();
      final status = await service.getPeerStatus();
      if (mounted) {
        setState(() {
          peerStatus = status;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          peerStatus = [];
        });
      }
    }
  }

  int _getConnectedPeersCount() {
    return peerStatus
        .where((peer) =>
            peer.connectionState == peer_models.ConnectionState.connected)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final networkTraffic = _calculateNetworkTraffic();
    final connectedCount = _getConnectedPeersCount();

    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Connected Peers',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$connectedCount',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Uptime',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.uptimeNotifier.formattedUptime,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Traffic',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  networkTraffic['total'] ?? '0 B',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _calculateNetworkTraffic() {
    int totalRx = 0;
    int totalTx = 0;

    for (final peer in peerStatus) {
      totalRx += peer.rxBytes;
      totalTx += peer.txBytes;
    }

    final totalTraffic = totalRx + totalTx;
    return {
      'total': peer_models.PeerStats.formatBytes(totalTraffic),
      'rx': peer_models.PeerStats.formatBytes(totalRx),
      'tx': peer_models.PeerStats.formatBytes(totalTx),
    };
  }
}
