import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/app_card.dart';
import '../../../app/widgets/app_button.dart';
import '../../../models/peer_models.dart' as peer_models;
import '../../../services/peers_service.dart';
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
                'Dashboard',
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
          width: 300,
          child: Column(
            children: [
              _DesktopStatsCards(),
              const SizedBox(height: AppSpacing.xl),
              _NetworkInfoCard(),
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
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isSocks5Enabled = false;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

  void _updateAnimations() {
    final isConnected = widget.status == NodeStatus.connected;
    final isConnecting = _isLoading || widget.status == NodeStatus.connecting;

    if (isConnecting) {
      _rotationController.repeat();
      _pulseController.stop();
    } else if (isConnected) {
      _rotationController.stop();
      _pulseController.repeat(reverse: true);
    } else {
      _rotationController.stop();
      _pulseController.stop();
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
                  Listenable.merge([_pulseController, _rotationController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnected ? _pulseAnimation.value : 1.0,
                  child: Transform.rotate(
                    angle: isConnecting
                        ? _rotationAnimation.value * 2 * 3.14159
                        : 0.0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.neutral200,
                        border: Border.all(
                          color: isConnected
                              ? AppColors.success
                              : AppColors.neutral400,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        isConnected ? Icons.wifi : Icons.wifi_off,
                        size: 48,
                        color: isConnected
                            ? AppColors.success
                            : AppColors.neutral600,
                      ),
                    ),
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
                label: isConnected ? 'Disconnect' : 'Connect',
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
                  label: const Text('Restart'),
                ),
              ),
            ],

            // Advanced options for desktop
            if (isConnected) ...[
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

  @override
  void initState() {
    super.initState();
    _fetchPeerStatus();
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
    final nodeStatusAsync = ref.watch(nodeStatusProvider);
    final uptimeNotifier = ref.watch(uptimeProvider.notifier);
    final connectedCount = _getConnectedPeersCount();

    return Column(
      children: [
        // Connected Peers Card
        AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.hub,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Connected Peers',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$connectedCount',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),

        // Bandwidth Card
        AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: AppColors.brandAccent,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Bandwidth',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '2.4 MB/s',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandAccent,
                    ),
              ),
            ],
          ),
        ),

        // Uptime Card
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Uptime',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                uptimeNotifier.formattedUptime,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Network Info',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            label: 'Protocol',
            value: 'Mycelium v0.6.2',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: 'Network',
            value: 'MainNet',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: 'Status',
            value: 'Healthy',
            valueColor: AppColors.success,
          ),
        ],
      ),
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
