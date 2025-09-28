import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/app_card.dart';
import '../../../app/widgets/app_button.dart';
import '../../../models/peer_models.dart' as peer_models;
import '../../../state/mycelium_providers.dart';
import '../../../services/ffi/mycelium_service.dart';
import 'traffic_summary.dart';
import '../../../state/dynamic_traffic_providers.dart';

class DesktopHomeLayout extends ConsumerWidget {
  final NodeStatus status;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final dynamic service;

  const DesktopHomeLayout({
    super.key,
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
    required this.service,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content area
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard title
              Text(
                'Home',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Main connection status card
              _DesktopConnectionCard(
                status: status,
                onConnect: onConnect,
                onDisconnect: onDisconnect,
                service: service,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Traffic summary for desktop
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
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.xxl),

        // Statistics sidebar
        SizedBox(
          width: 350,
          child: Column(
            children: [
              _DesktopStatsCards(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopConnectionCard extends StatefulWidget {
  final NodeStatus status;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final dynamic service;

  const _DesktopConnectionCard({
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
    required this.service,
  });

  @override
  State<_DesktopConnectionCard> createState() => _DesktopConnectionCardState();
}

class _DesktopConnectionCardState extends State<_DesktopConnectionCard>
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
  void didUpdateWidget(_DesktopConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimations();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Restart animation when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
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
    _updateAnimations();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == NodeStatus.connected;
    final isConnecting = _isLoading || widget.status == NodeStatus.connecting;

    return AppCard(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            // Large status icon
            AnimatedBuilder(
              animation:
                  Listenable.merge([_fadeController, _rotationController]),
              builder: (context, child) {
                return SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Wave animation (only when connected)
                      if (isConnected) ...[
                        // Wave 1 - starts completely outside main circle
                        Container(
                          width: 130 + (50 * _fadeAnimation.value),
                          height: 130 + (50 * _fadeAnimation.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(
                                  (1.0 - _fadeAnimation.value) * 0.3,
                                ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                            ),
                            child: Center(
                              child: Container(
                                width: 124, // Main circle size + border
                                height: 124,
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
                          width: 130 +
                              (35 *
                                  ((_fadeAnimation.value - 0.3)
                                      .clamp(0.0, 1.0))),
                          height: 130 +
                              (35 *
                                  ((_fadeAnimation.value - 0.3)
                                      .clamp(0.0, 1.0))),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(
                                  (1.0 -
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
                                width: 124,
                                height: 124,
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
                          width: 130 +
                              (25 *
                                  ((_fadeAnimation.value - 0.6)
                                      .clamp(0.0, 1.0))),
                          height: 130 +
                              (25 *
                                  ((_fadeAnimation.value - 0.6)
                                      .clamp(0.0, 1.0))),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(
                                  (1.0 -
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
                                width: 124,
                                height: 124,
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
                          width: 120,
                          height: 120,
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
                            size: 60,
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

            const SizedBox(height: AppSpacing.xl),

            // Status text
            Text(
              isConnected
                  ? 'Connected'
                  : isConnecting
                      ? 'Connecting...'
                      : widget.status == NodeStatus.failed
                          ? 'Connection Failed'
                          : 'Disconnected',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isConnected ? AppColors.success : null,
                  ),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              isConnected
                  ? 'Mycelium is running and connected to the network'
                  : 'Tap to connect to the Mycelium network',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Connect/Disconnect button
            SizedBox(
              width: 200,
              child: AppButton(
                label: isConnected ? 'Disconnect Mycelium' : 'Start Mycelium',
                onPressed: isConnected ? stopMycelium : startMycelium,
                isLoading: isConnecting,
                backgroundColor:
                    isConnected ? AppColors.error : AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
            ),

            if (isConnected) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 200,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await stopMycelium();
                    await startMycelium();
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restart Mycelium'),
                ),
              ),
            ],

            // Advanced options for desktop
            if (isConnected && false) ...[
              const SizedBox(height: AppSpacing.xxl),
              ExpansionTile(
                title: const Text('Advanced Options'),
                children: [
                  SwitchListTile(
                    title: const Text('Enable SOCKS5 tunneling'),
                    subtitle: const Text('Use Mycelium as VPN tunnel'),
                    value: _isSocks5Enabled,
                    onChanged: (value) async {
                      setState(() => _isSocks5Enabled = value);
                      if (value) {
                        await widget.service.startProxyProbe();
                        await Future.delayed(Duration(seconds: 10));
                        await widget.service.proxyConnect(
                            '[40a:152c:b85b:9646:5b71:d03a:eb27:2462]:1080');
                      } else {
                        await widget.service.proxyDisconnect();
                        await widget.service.stopProxyProbe();
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DesktopStatsCards extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DesktopStatsCards> createState() => _DesktopStatsCardsState();
}

class _DesktopStatsCardsState extends ConsumerState<_DesktopStatsCards> {
  List<peer_models.PeerStats> peerStatus = [];
  Timer? _peerStatusTimer;
  Timer? _uptimeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchPeerStatus();
    _startPeriodicUpdates();
  }

  @override
  void dispose() {
    _peerStatusTimer?.cancel();
    _uptimeRefreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicUpdates() {
    // Update peer status every 5 seconds
    _peerStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchPeerStatus();
    });

    // Refresh uptime display every second
    _uptimeRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to update the uptime display
        });
      }
    });
  }

  Future<void> _fetchPeerStatus() async {
    try {
      final nodeStatusAsync = ref.read(nodeStatusProvider);
      final nodeStatus = nodeStatusAsync.asData?.value;

      // Only fetch peer status if connected
      if (nodeStatus != NodeStatus.connected) {
        if (mounted) {
          setState(() {
            peerStatus = [];
          });
        }
        return;
      }

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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final nodeStatusAsync = ref.watch(nodeStatusProvider);
    final uptimeNotifier = ref.watch(uptimeProvider.notifier);
    final connectedCount = _getConnectedPeersCount();

    return Column(
      children: [
        // Connected Peers Card
        SizedBox(
          width: double.infinity,
          child: AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Icon(
                Icons.hub,
                size: 32,
                color: AppColors.dataPeers,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Connected Peers',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$connectedCount',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.dataPeers,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            ),
          ),
        ),

        // Traffic Card
        Consumer(
          builder: (context, ref, child) {
            final trafficStats = ref.watch(dynamicTrafficProvider);

            // Use total accumulated traffic instead of peak rates
            final totalUploadBytes = trafficStats.totalUploadBytes;
            final totalDownloadBytes = trafficStats.totalDownloadBytes;
            final totalTrafficBytes = totalUploadBytes + totalDownloadBytes;

            String trafficDisplay;
            if (totalTrafficBytes > 0) {
              trafficDisplay = _formatBytes(totalTrafficBytes);
            } else {
              trafficDisplay = '0 B';
            }

            return SizedBox(
              width: double.infinity,
              child: AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.podcasts,
                    size: 32,
                    color: AppColors.dataTraffic,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Network Traffic',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    trafficDisplay,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.dataTraffic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                ),
              ),
            );
          },
        ),

        // Uptime Card
        SizedBox(
          width: double.infinity,
          child: AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Icon(
                Icons.access_time,
                size: 32,
                color: AppColors.dataUptime,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Uptime',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                uptimeNotifier.formattedUptime,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.dataUptime,
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
