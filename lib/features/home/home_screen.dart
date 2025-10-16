import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../app/widgets/app_button.dart';
import '../../app/widgets/responsive_layout.dart';
import '../../models/peer_models.dart' as peer_models;
import '../../services/peers_service.dart';
import '../../state/mycelium_providers.dart';
import '../../services/ffi/mycelium_service.dart';
import 'widgets/traffic_summary.dart';
import 'widgets/desktop_home_layout.dart';
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
      title: _buildTitle(context, buttonColor, onButtonColor),
      currentIndex: 0,
      onTabSelected: null,
      child: ResponsiveLayout(
        mobile: _buildMobileLayout(context, ref, status, service, peersAsync),
        desktop: DesktopHomeLayout(
          status: status,
          onConnect: () async {
            final peers = peersAsync.asData?.value ?? [];
            if (peers.isNotEmpty) {
              await service.start(peers);
            } else {
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
      ),
    );
  }

  Widget _buildTitle(
      BuildContext context, Color buttonColor, Color onButtonColor) {
    return ResponsiveHelper.isDesktop(context)
        ? const Text('Home') // Simple title for desktop
        : Container(
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
          );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    NodeStatus status,
    dynamic service,
    AsyncValue<List<String>> peersAsync,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reduce spacing on very small screens
        final isVerySmall = constraints.maxHeight < 600;
        final spacing = isVerySmall ? AppSpacing.sm : AppSpacing.xxl;

        return Column(
          children: [
            SizedBox(height: isVerySmall ? AppSpacing.sm : AppSpacing.xxl),
            _HeaderCard(
              status: status,
              onConnect: () async {
                final peers = peersAsync.asData?.value ?? [];
                if (peers.isNotEmpty) {
                  await service.start(peers);
                } else {
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
            SizedBox(height: spacing),
            const _StatsRow(),
            SizedBox(height: spacing),
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
            SizedBox(height: isVerySmall ? AppSpacing.sm : AppSpacing.xxxl),
          ],
        );
      },
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

class _HeaderCardState extends State<_HeaderCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isSocks5Enabled = false;
  late AnimationController _fadeController;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
    _updateAnimations();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Restart animation when app comes back to foreground or when switching tabs
    if (state == AppLifecycleState.resumed) {
      _updateAnimations();
    }
  }

  @override
  void didUpdateWidget(_HeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    final isConnected = widget.status == NodeStatus.connected;
    final isConnecting = _isLoading || widget.status == NodeStatus.connecting;

    if (isConnecting) {
      _rotationController.repeat();
      _fadeController.stop();
    } else if (isConnected) {
      _rotationController.stop();
      _fadeController.repeat(reverse: true);
    } else {
      _rotationController.stop();
      _fadeController.stop();
    }
  }

  bool get isRestartVisible =>
      widget.status == NodeStatus.connected && !_isLoading;

  Future<void> startMycelium() async {
    setState(() => _isLoading = true);
    _updateAnimations();
    await widget.onConnect();
    setState(() => _isLoading = false);
    _updateAnimations();
  }

  Future<void> stopMycelium() async {
    setState(() => _isLoading = true);
    _updateAnimations();

    // Stop proxy first if it's enabled
    if (_isSocks5Enabled) {
      try {
        await widget.service.proxyDisconnect();
        await widget.service.stopProxyProbe();
        setState(() => _isSocks5Enabled = false);
      } catch (e) {
        debugPrint('Error stopping proxy: $e');
      }
    }

    await widget.onDisconnect();
    setState(() => _isLoading = false);
    _updateAnimations();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == NodeStatus.connected;
    final isConnecting = _isLoading || widget.status == NodeStatus.connecting;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_fadeController, _rotationController]),
            builder: (context, child) {
              return SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Wave animation (only when connected)
                    if (isConnected) ...[
                      // Wave 1 - starts completely outside main circle
                      Container(
                        width: 100 + (30 * _fadeAnimation.value),
                        height: 100 + (30 * _fadeAnimation.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Theme.of(context).colorScheme.primary.withValues(
                                    alpha: (1.0 - _fadeAnimation.value) * 0.3,
                                  ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Center(
                            child: Container(
                              width: 94, // Main circle size + border
                              height: 94,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Wave 2 - delayed wave
                      Container(
                        width: 100 +
                            (25 *
                                ((_fadeAnimation.value - 0.3).clamp(0.0, 1.0))),
                        height: 100 +
                            (25 *
                                ((_fadeAnimation.value - 0.3).clamp(0.0, 1.0))),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Theme.of(context).colorScheme.primary.withValues(
                                    alpha: (1.0 -
                                            (_fadeAnimation.value - 0.3)
                                                .clamp(0.0, 1.0)) *
                                        0.2,
                                  ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Center(
                            child: Container(
                              width: 94,
                              height: 94,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Wave 3 - most delayed wave
                      Container(
                        width: 100 +
                            (20 *
                                ((_fadeAnimation.value - 0.6).clamp(0.0, 1.0))),
                        height: 100 +
                            (20 *
                                ((_fadeAnimation.value - 0.6).clamp(0.0, 1.0))),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Theme.of(context).colorScheme.primary.withValues(
                                    alpha: (1.0 -
                                            (_fadeAnimation.value - 0.6)
                                                .clamp(0.0, 1.0)) *
                                        0.1,
                                  ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Center(
                            child: Container(
                              width: 94,
                              height: 94,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Fixed-size main icon
                    Transform.rotate(
                      angle: isConnecting
                          ? _rotationAnimation.value * 2 * 3.14159
                          : 0.0,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isConnected
                                ? Theme.of(context).colorScheme.primary
                                : isConnecting
                                    ? AppColors.warning
                                    : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.wifi
                              : isConnecting
                                  ? Icons.sync
                                  : Icons.wifi_off,
                          size: 45,
                          color: isConnected
                              ? Theme.of(context).colorScheme.primary
                              : isConnecting
                                  ? AppColors.warning
                                  : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap to start the Mycelium node',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: isConnected ? 'Stop Mycelium' : 'Start Mycelium',
            onPressed: isConnected ? stopMycelium : startMycelium,
            isLoading: isConnecting,
            backgroundColor: isConnected
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primary,
            foregroundColor: isConnected
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onPrimary,
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
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                  elevation: 0,
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
                    title: const Text(
                        'Route all device traffic through SOCKS5 proxy'),
                    subtitle: const Text(
                        'Forward all network traffic through Mycelium mesh'),
                    trailing: Switch(
                      value: _isSocks5Enabled,
                      onChanged: (value) async {
                        setState(() => _isSocks5Enabled = value);
                        if (value) {
                          // Enable device-wide proxy mode
                          final result =
                              await widget.service.startDeviceWideProxy();
                          if (!result) {
                            setState(() => _isSocks5Enabled = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Failed to enable device-wide proxy'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Device-wide proxy enabled successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          debugPrint('Device-wide proxy result: $result');
                        } else {
                          // Disable device-wide proxy mode
                          final result =
                              await widget.service.stopDeviceWideProxy();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result
                                  ? 'Device-wide proxy disabled successfully'
                                  : 'Failed to disable device-wide proxy'),
                              backgroundColor:
                                  result ? Colors.green : Colors.red,
                            ),
                          );
                          debugPrint(
                              'Device-wide proxy disable result: $result');
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Proxy Status'),
                    subtitle: FutureBuilder<Map<String, dynamic>>(
                      future: widget.service.getDeviceWideProxyStatus(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final status = snapshot.data!;
                          final enabled = status['enabled'] as bool? ?? false;
                          final error = status['error'] as String?;

                          if (error != null) {
                            return Text('Error: $error',
                                style: TextStyle(color: Colors.red));
                          }

                          return Text(
                            enabled
                                ? 'Active - All traffic routed through proxy'
                                : 'Inactive',
                            style: TextStyle(
                              color: enabled ? Colors.green : Colors.grey,
                              fontWeight:
                                  enabled ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}',
                              style: TextStyle(color: Colors.red));
                        } else {
                          return const Text('Checking status...');
                        }
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        setState(() {}); // Trigger rebuild to refresh status
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Available Proxies'),
                    subtitle: FutureBuilder<List<String>>(
                      future: widget.service.listProxies(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final proxies = snapshot.data!;
                          if (proxies.isEmpty ||
                              (proxies.length == 1 &&
                                  proxies[0].startsWith('Failed'))) {
                            return const Text('No proxies discovered yet');
                          }
                          return Text('${proxies.length} proxy(ies) available');
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else {
                          return const Text('Discovering proxies...');
                        }
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        // Start proxy probe
                        await widget.service.startProxyProbe();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Started proxy discovery...'),
                          ),
                        );
                        // Refresh the UI after a delay
                        await Future.delayed(Duration(seconds: 3));
                        setState(() {});
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use single column layout for very narrow screens
        if (constraints.maxWidth < 330) {
          return Column(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hub,
                      color: AppColors.dataPeers,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Peers',
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${peerStatus.length}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dataPeers,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.dataUptime,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Uptime',
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      uptimeNotifier.formattedUptime,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dataUptime,
                              ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.podcasts,
                      color: AppColors.dataTraffic,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Traffic',
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      networkTraffic['total'] ?? '0 B',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dataTraffic,
                              ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Use row layout for wider screens
        return Row(
          children: [
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hub,
                      color: AppColors.dataPeers,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Peers',
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${peerStatus.length}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dataPeers,
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
                    Icon(
                      Icons.access_time,
                      color: AppColors.dataUptime,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Uptime',
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      uptimeNotifier.formattedUptime,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dataUptime,
                              ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
                    Icon(
                      Icons.podcasts,
                      color: AppColors.dataTraffic,
                      size: 24,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Traffic',
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      networkTraffic['total'] ?? '0 B',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.dataTraffic,
                              ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
  Timer? _uptimeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchPeerStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchPeerStatus();
    });

    // Refresh uptime display every second (mobile)
    _uptimeRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to update the uptime display
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _uptimeRefreshTimer?.cancel();
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
                Icon(
                  Icons.hub,
                  color: AppColors.dataPeers,
                  size: 24,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Peers',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$connectedCount',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.dataPeers,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  color: AppColors.dataUptime,
                  size: 24,
                ),
                const SizedBox(height: AppSpacing.xs),
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
                        color: AppColors.dataUptime,
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
                Icon(
                  Icons.podcasts,
                  color: AppColors.dataTraffic,
                  size: 24,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Traffic',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  networkTraffic['total'] ?? '0 B',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.dataTraffic,
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
