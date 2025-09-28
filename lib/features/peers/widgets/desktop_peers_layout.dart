import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/widgets/app_card.dart';
import '../../../app/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/mycelium_providers.dart';
import '../../../services/ffi/mycelium_service.dart';
import '../../../models/peer_models.dart' as peer_models;
import '../../../services/ping_service.dart';
import '../../../state/geolocation_providers.dart';

class DesktopPeersLayout extends ConsumerStatefulWidget {
  final List<String> peers;

  const DesktopPeersLayout({required this.peers});

  @override
  ConsumerState<DesktopPeersLayout> createState() => DesktopPeersLayoutState();
}

class DesktopPeersLayoutState extends ConsumerState<DesktopPeersLayout> {
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
          _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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

      if (peerIp == statusIp) {
        return peer;
      }

      if (peerAddress == peer.endpoint) {
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
        // Left side - Peers list
        Expanded(
          flex: 2,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              _SearchAddBar(
                onChanged: (v) => setState(() => query = v),
                onAdd: () => _showAddPeerDialog(context, ref),
                isDisabled: isMyceliumRunning,
              ),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                _PeersEmptyState()
              else
                ...filtered.map((p) {
                  final isUserPeer = userPeers.contains(p);
                  final peerStat = _findPeerStatus(p);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PeerTile(
                      ip: p,
                      country: "Unknown",
                      isUserPeer: isUserPeer,
                      peerStats: peerStat,
                      isDisabled: isMyceliumRunning,
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        
        const SizedBox(width: AppSpacing.lg),
        
        // Right side - Summary cards
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public,
                            size: 20, color: AppColors.dataPeers),
                        const SizedBox(width: 6),
                        Text('Peer Summary',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SummaryItem(
                              label: '${peerSummary['connected']}',
                              subtitle: 'Connected',
                              color: AppColors.success),
                          const SizedBox(height: AppSpacing.sm),
                          _SummaryItem(
                              label: '${peerSummary['slow']}',
                              subtitle: 'Connecting',
                              color: AppColors.warning),
                          const SizedBox(height: AppSpacing.sm),
                          _SummaryItem(
                              label: '${peerSummary['down']}',
                              subtitle: 'Down',
                              color: AppColors.error),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.podcasts,
                            size: 20, color: AppColors.dataTraffic),
                        const SizedBox(width: 6),
                        Text('Network Traffic',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SummaryItem(
                              label: networkTraffic['rx'] ?? '0 B',
                              subtitle: 'Total Download',
                              color: AppColors.dataDownload),
                          const SizedBox(height: AppSpacing.sm),
                          _SummaryItem(
                              label: networkTraffic['tx'] ?? '0 B',
                              subtitle: 'Total Upload',
                              color: AppColors.dataUpload),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (peerStatusError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Error getting peer status: $peerStatusError',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchAddBar extends ConsumerWidget {
  final VoidCallback onAdd;
  final ValueChanged<String>? onChanged;
  final bool isDisabled;
  const _SearchAddBar(
      {required this.onAdd, this.onChanged, this.isDisabled = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search peers',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: isDisabled ? null : onChanged,
            enabled: !isDisabled,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        FilledButton.icon(
          onPressed: isDisabled ? null : () => _showAddPeerDialog(context, ref),
          icon: const Icon(Icons.add),
          label: Text(isDisabled ? 'Mycelium Running' : 'Add Peer'),
        ),
      ],
    );
  }
}

class _PeerTile extends ConsumerStatefulWidget {
  final String ip;
  final String country;
  final bool isUserPeer;
  final peer_models.PeerStats? peerStats;
  final bool isDisabled;

  const _PeerTile(
      {required this.ip,
      required this.country,
      required this.isUserPeer,
      this.peerStats,
      this.isDisabled = false});

  @override
  ConsumerState<_PeerTile> createState() => _PeerTileState();
}

class _PeerTileState extends ConsumerState<_PeerTile> {
  PingResult? _pingResult;
  bool _isPinging = false;
  Timer? _periodicPingTimer;

  @override
  void initState() {
    super.initState();
    // Start periodic ping for connected/connecting peers after a short delay
    // to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPeriodicPing();
    });
  }

  @override
  void didUpdateWidget(_PeerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart periodic ping if peer status changed
    if (oldWidget.peerStats?.connectionState !=
        widget.peerStats?.connectionState) {
      _periodicPingTimer?.cancel();
      _startPeriodicPing();
    }
  }

  @override
  void dispose() {
    _periodicPingTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicPing() {
    // Only start periodic ping if peer is connected or connecting
    if (widget.peerStats != null &&
        (widget.peerStats!.connectionState ==
                peer_models.ConnectionState.connected ||
            widget.peerStats!.connectionState ==
                peer_models.ConnectionState.connecting)) {
      // Initial ping after 2 seconds
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _performPingTest(isAutomatic: true);
        }
      });

      // Then ping every 5 seconds
      _periodicPingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          _performPingTest(isAutomatic: true);
        }
      });
    } else {}
  }

  Future<void> _performPingTest({bool isAutomatic = false}) async {
    if (!mounted) return;

    // Don't show loading indicator for automatic pings
    if (!isAutomatic) {
      setState(() {
        _isPinging = true;
        _pingResult = null;
      });
    }

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
    // Determine connection status and color
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Country flag circle or globe for unknown countries
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

                  // Show globe icon for unknown countries or while loading
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.ip
                                .replaceAll('tcp://', '')
                                .replaceAll(':9651', ''),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Location info row
                    Consumer(
                      builder: (context, ref, child) {
                        final locationAsync =
                            ref.watch(peerLocationProvider(widget.ip));

                        if (locationAsync != null &&
                            locationAsync.country != 'Unknown') {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              locationAsync.city.isNotEmpty
                                  ? '${locationAsync.country} • ${locationAsync.city}'
                                  : locationAsync.country,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }

                        // Show loading indicator while fetching
                        if (locationAsync == null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Loading location...',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5),
                                      ),
                                ),
                              ],
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          connectionStatus,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: connectionColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Add ping button when Mycelium is running (enabled for connecting and connected peers)
              if (widget.peerStats != null &&
                  (widget.peerStats!.connectionState ==
                          peer_models.ConnectionState.connected ||
                      widget.peerStats!.connectionState ==
                          peer_models.ConnectionState.connecting)) ...[
                IconButton(
                  icon: _isPinging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.speed,
                          size: 18,
                          color: AppColors.dataTraffic,
                        ),
                  onPressed: _isPinging ? null : _performPingTest,
                  tooltip: 'Test ping',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
              // Show delete icon only for user-added peers
              if (widget.isUserPeer && widget.peerStats == null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: widget.isDisabled
                      ? null
                      : () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Peer'),
                              content: Text(
                                'Are you sure you want to delete this peer?\n\n${widget.ip.replaceAll('tcp://', '').replaceAll(':9651', '')}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            final peersNotifier =
                                ref.read(peersProvider.notifier);
                            await peersNotifier.removePeer(widget.ip);
                          }
                        },
                  tooltip: 'Delete peer',
                ),
            ],
          ),
          if (widget.peerStats != null) ...[
            const SizedBox(height: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RX: ${widget.peerStats!.formattedRxBytes}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.dataDownload,
                            ),
                          ),
                          Text(
                            'TX: ${widget.peerStats!.formattedTxBytes}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.dataUpload,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discovered: ${widget.peerStats!.formattedDiscovered}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (widget.peerStats!.lastConnectedSeconds != null)
                            Text(
                              'Last Connected: ${widget.peerStats!.formattedLastConnected}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_pingResult != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _pingResult!.success
                          ? (_pingResult!.latencyMs! < 50
                              ? AppColors.success.withOpacity(0.1)
                              : _pingResult!.latencyMs! < 150
                                  ? Colors.orange.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1))
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _pingResult!.success
                            ? (_pingResult!.latencyMs! < 50
                                ? AppColors.success.withOpacity(0.3)
                                : _pingResult!.latencyMs! < 150
                                    ? Colors.orange.withOpacity(0.3)
                                    : AppColors.error.withOpacity(0.3))
                            : AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _pingResult!.success
                              ? Icons.check_circle
                              : Icons.error,
                          size: 14,
                          color: _pingResult!.success
                              ? (_pingResult!.latencyMs! < 50
                                  ? AppColors.success
                                  : _pingResult!.latencyMs! < 150
                                      ? Colors.orange
                                      : AppColors.error)
                              : AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _pingResult!.success
                              ? 'Ping: ${_pingResult!.latencyMs}ms'
                              : 'Ping: Failed',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _pingResult!.success
                                        ? (_pingResult!.latencyMs! < 50
                                            ? AppColors.success
                                            : _pingResult!.latencyMs! < 150
                                                ? Colors.orange
                                                : AppColors.error)
                                        : AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PeersEmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Icon(Icons.hub_outlined,
            size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: AppSpacing.lg),
        Text('No peers yet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('Add peers to start Mycelium or load saved peers.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton.icon(
          onPressed: () => _showAddPeerDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add Peer'),
        ),
      ],
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
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Valid IP address',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isValidIP && controller.text.trim().isNotEmpty
                  ? () async {
                      final ip = controller.text.trim();
                      final formattedPeer =
                          ip.startsWith('tcp://') ? ip : 'tcp://$ip:9651';

                      await peersNotifier.addPeer(formattedPeer);
                      Navigator.of(context).pop();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Add'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ),
  );
}

bool _isValidIP(String ip) {
  if (ip.isEmpty) return false;

  // IPv4 regex
  final ipv4Regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');

  // IPv6 regex (simplified)
  final ipv6Regex =
      RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$');

  return ipv4Regex.hasMatch(ip) || ipv6Regex.hasMatch(ip);
}
