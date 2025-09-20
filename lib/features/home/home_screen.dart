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
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          _HeaderCard(
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
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _StatsRow(),
          const SizedBox(height: AppSpacing.xxl),
          Consumer(
            builder: (context, ref, child) {
              final trafficStats = ref.watch(dynamicTrafficProvider);
              
              return TrafficSummary(
                totalUpload: trafficStats.totalUploadFormatted,
                totalDownload: trafficStats.totalDownloadFormatted,
                peakUpload: trafficStats.peakUploadFormatted,
                peakDownload: trafficStats.peakDownloadFormatted,
              );
            },
          ),
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

class _StatsRow extends ConsumerStatefulWidget {
  const _StatsRow();

  @override
  ConsumerState<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends ConsumerState<_StatsRow> {
  List<peer_models.PeerStats> peerStatus = [];
  Timer? _refreshTimer;
  Timer? _uptimeTimer;

  @override
  void initState() {
    super.initState();
    _fetchPeerStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchPeerStatus();
    });
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Trigger rebuild to update uptime display
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _uptimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPeerStatus() async {
    try {
      final service = MyceliumService();
      final status = await service.getPeerStatus();
      setState(() {
        peerStatus = status;
      });
    } catch (e) {
      // Handle error silently
    }
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

  int _getConnectedPeersCount() {
    return peerStatus.where((peer) => 
      peer.connectionState == peer_models.ConnectionState.connected
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final uptimeNotifier = ref.read(uptimeProvider.notifier);
    final connectedPeers = _getConnectedPeersCount();
    final networkTraffic = _calculateNetworkTraffic();
    final uptime = uptimeNotifier.formattedUptime;
    Widget tileContent(IconData icon, String title, String value) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title, 
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value, 
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
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
              child: tileContent(Icons.people, 'Connected Peers', '$connectedPeers'),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: tileContent(Icons.podcasts, 'Total Traffic', networkTraffic['total'] ?? '0 B'),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: tileContent(Icons.access_time, 'Uptime', uptime),
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
