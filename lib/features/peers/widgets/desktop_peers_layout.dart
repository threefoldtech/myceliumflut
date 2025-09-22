import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/app_card.dart';
import '../../../state/mycelium_providers.dart';
import '../../../services/ffi/mycelium_service.dart';
import '../../../models/peer_models.dart' as peer_models;
import '../../../services/ping_service.dart';
import '../../../state/geolocation_providers.dart';

class DesktopPeersLayout extends ConsumerStatefulWidget {
  final List<String> peers;

  const DesktopPeersLayout({super.key, required this.peers});

  @override
  ConsumerState<DesktopPeersLayout> createState() => _DesktopPeersLayoutState();
}

class _DesktopPeersLayoutState extends ConsumerState<DesktopPeersLayout> {
  String query = '';
  List<peer_models.PeerStats> peerStatus = [];
  String? peerStatusError;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startConditionalPolling();
  }

  void _startConditionalPolling() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final nodeStatusAsync = ref.read(nodeStatusProvider);
      nodeStatusAsync.whenData((status) {
        if (mounted && status == NodeStatus.connected) {
          _fetchPeerStatus();
          _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
            if (mounted) _fetchPeerStatus();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPeerStatus() async {
    if (!mounted) return;

    try {
      final service = MyceliumService();
      final status = await service.getPeerStatus();
      if (mounted) {
        setState(() {
          peerStatus = status;
          peerStatusError = null;
        });
      }
    } catch (e) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      if (mounted) {
        setState(() {
          peerStatus = [];
          peerStatusError = null;
        });
      }
    }
  }

  Map<String, int> _calculatePeerSummary() {
    int connected = 0;
    int slow = 0;
    int down = 0;

    for (final peer in peerStatus) {
      switch (peer.connectionState) {
        case peer_models.ConnectionState.connected:
          connected++;
          break;
        case peer_models.ConnectionState.connecting:
          slow++;
          break;
        case peer_models.ConnectionState.disconnected:
        case peer_models.ConnectionState.failed:
        case peer_models.ConnectionState.unknown:
          down++;
          break;
      }
    }

    return {
      'connected': connected,
      'slow': slow,
      'down': down,
    };
  }

  Map<String, String> _calculateNetworkTraffic() {
    int totalRx = 0;
    int totalTx = 0;

    for (final peer in peerStatus) {
      totalRx += peer.rxBytes;
      totalTx += peer.txBytes;
    }
    return {
      'rx': peer_models.PeerStats.formatBytes(totalRx),
      'tx': peer_models.PeerStats.formatBytes(totalTx),
    };
  }

  peer_models.PeerStats? _findPeerStatus(String peerAddress) {
    for (final peer in peerStatus) {
      final peerIp = peerAddress.replaceAll('tcp://', '').split(':')[0];

      String statusIp = peer.endpoint;
      if (statusIp.contains('://')) {
        statusIp = statusIp.split('://')[1].split(':')[0];
      } else if (statusIp.contains(':')) {
        statusIp = statusIp.split(':')[0];
      }

      if (peerIp == statusIp || peerAddress == peer.endpoint) {
        return peer;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final peersNotifier = ref.read(peersProvider.notifier);
    final userPeers = peersNotifier.userPeers;
    final nodeStatusAsync = ref.watch(nodeStatusProvider);
    final isMyceliumRunning = nodeStatusAsync.when(
      data: (status) => status == NodeStatus.connected,
      loading: () => false,
      error: (_, __) => false,
    );

    final filtered = query.isEmpty
        ? widget.peers
        : widget.peers
            .where((p) => p.toLowerCase().contains(query.toLowerCase()))
            .toList();

    final peerSummary = _calculatePeerSummary();
    final networkTraffic = _calculateNetworkTraffic();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main peers list
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title and search
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Peers Management',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Search and add bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search peers...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      onChanged: isMyceliumRunning
                          ? null
                          : (v) => setState(() => query = v),
                      enabled: !isMyceliumRunning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: isMyceliumRunning
                        ? null
                        : () => _showAddPeerDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(
                        isMyceliumRunning ? 'Mycelium Running' : 'Add Peer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Peers grid
              if (filtered.isEmpty)
                _PeersEmptyState()
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final isUserPeer = userPeers.contains(p);
                      final peerStat = _findPeerStatus(p);
                      return _DesktopPeerCard(
                        ip: p,
                        country: "Unknown",
                        isUserPeer: isUserPeer,
                        peerStats: peerStat,
                        isDisabled: isMyceliumRunning,
                      );
                    },
                  ),
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
              // Peer Summary Card
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('Peer Summary',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SummaryItem(
                            label: '${peerSummary['connected']}',
                            subtitle: 'Connected',
                            color: Colors.green),
                        _SummaryItem(
                            label: '${peerSummary['slow']}',
                            subtitle: 'Connecting',
                            color: Colors.orange),
                        _SummaryItem(
                            label: '${peerSummary['down']}',
                            subtitle: 'Down',
                            color: Colors.red),
                      ],
                    ),
                  ],
                ),
              ),

              // Network Traffic Card
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.podcasts,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('Network Traffic',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SummaryItem(
                            label: networkTraffic['rx'] ?? '0 B',
                            subtitle: 'Download'),
                        _SummaryItem(
                            label: networkTraffic['tx'] ?? '0 B',
                            subtitle: 'Upload'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopPeerCard extends ConsumerStatefulWidget {
  final String ip;
  final String country;
  final bool isUserPeer;
  final peer_models.PeerStats? peerStats;
  final bool isDisabled;

  const _DesktopPeerCard({
    required this.ip,
    required this.country,
    required this.isUserPeer,
    this.peerStats,
    this.isDisabled = false,
  });

  @override
  ConsumerState<_DesktopPeerCard> createState() => _DesktopPeerCardState();
}

class _DesktopPeerCardState extends ConsumerState<_DesktopPeerCard> {
  PingResult? _pingResult;
  bool _isPinging = false;

  Future<void> _performPingTest() async {
    if (!mounted) return;

    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    try {
      final pingService = ref.read(pingServiceProvider);
      final pingResult = await pingService.ping(widget.ip);

      if (mounted) {
        setState(() {
          _pingResult = pingResult;
          _isPinging = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pingResult = PingResult(
            host: widget.ip,
            latencyMs: null,
            success: false,
            timestamp: DateTime.now(),
          );
          _isPinging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color connectionColor = Colors.grey;
    String connectionStatus = 'Unknown';

    if (widget.peerStats != null) {
      switch (widget.peerStats!.connectionState) {
        case peer_models.ConnectionState.connected:
          connectionColor = Colors.green;
          connectionStatus = 'Connected';
          break;
        case peer_models.ConnectionState.connecting:
          connectionColor = Colors.orange;
          connectionStatus = 'Connecting';
          break;
        case peer_models.ConnectionState.disconnected:
          connectionColor = Colors.red;
          connectionStatus = 'Disconnected';
          break;
        case peer_models.ConnectionState.failed:
          connectionColor = Colors.red;
          connectionStatus = 'Failed';
          break;
        case peer_models.ConnectionState.unknown:
          connectionColor = Colors.grey;
          connectionStatus = 'Unknown';
          break;
      }
    }

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with flag and IP
          Row(
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final locationAsync =
                      ref.watch(peerLocationProvider(widget.ip));

                  if (locationAsync != null &&
                      locationAsync.country != 'Unknown') {
                    final geoService = ref.read(geolocationServiceProvider);
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child:
                            geoService.getFlagWidget(locationAsync.countryCode),
                      ),
                    );
                  }

                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.public,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ip
                          .replaceAll('tcp://', '')
                          .replaceAll(':9651', ''),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Consumer(
                      builder: (context, ref, child) {
                        final locationAsync =
                            ref.watch(peerLocationProvider(widget.ip));

                        if (locationAsync != null &&
                            locationAsync.country != 'Unknown') {
                          return Text(
                            locationAsync.city.isNotEmpty
                                ? '${locationAsync.country} • ${locationAsync.city}'
                                : locationAsync.country,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                    ),
                            overflow: TextOverflow.ellipsis,
                          );
                        }

                        return Text(
                          'Loading location...',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Action buttons
              if (widget.isUserPeer)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: widget.isDisabled
                      ? null
                      : () => _showDeleteDialog(context),
                  tooltip: 'Delete peer',
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Status and ping
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: connectionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  connectionStatus,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: connectionColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              const Spacer(),
              if (widget.peerStats != null &&
                  (widget.peerStats!.connectionState ==
                          peer_models.ConnectionState.connected ||
                      widget.peerStats!.connectionState ==
                          peer_models.ConnectionState.connecting))
                TextButton.icon(
                  onPressed: _isPinging ? null : _performPingTest,
                  icon: _isPinging
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : const Icon(Icons.speed, size: 16),
                  label: Text(
                    _pingResult?.success == true
                        ? '${_pingResult!.latencyMs}ms'
                        : 'Ping',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),

          // Traffic stats
          if (widget.peerStats != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'RX: ${widget.peerStats!.formattedRxBytes}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    'TX: ${widget.peerStats!.formattedTxBytes}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Peer'),
        content: Text(
          'Are you sure you want to delete this peer?\n\n${widget.ip.replaceAll('tcp://', '').replaceAll(':9651', '')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final peersNotifier = ref.read(peersProvider.notifier);
      await peersNotifier.removePeer(widget.ip);
    }
  }
}

class _PeersEmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.lg),
          Text('No peers yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Add peers to start Mycelium or load saved peers.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6))),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton.icon(
            onPressed: () => _showAddPeerDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Peer'),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color? color;

  const _SummaryItem({
    required this.label,
    required this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).textTheme.titleLarge?.color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}

void _showAddPeerDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  final peersNotifier = ref.read(peersProvider.notifier);

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        bool isValidIP = _isValidIP(controller.text.trim());
        String? errorText = controller.text.trim().isNotEmpty && !isValidIP
            ? 'Please enter a valid IP address'
            : null;

        return AlertDialog(
          title: const Text('Add Peer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter peer IP (e.g. 185.69.166.7)',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                onChanged: (value) => setState(() {}),
              ),
              if (errorText == null && controller.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Valid IP address',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isValidIP && controller.text.trim().isNotEmpty
                  ? () async {
                      final ip = controller.text.trim();
                      final formattedPeer =
                          ip.startsWith('tcp://') ? ip : 'tcp://$ip:9651';

                      await peersNotifier.addPeer(formattedPeer);
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );
}

bool _isValidIP(String ip) {
  if (ip.isEmpty) return false;

  final ipv4Regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');

  final ipv6Regex =
      RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$');

  return ipv4Regex.hasMatch(ip) || ipv6Regex.hasMatch(ip);
}
