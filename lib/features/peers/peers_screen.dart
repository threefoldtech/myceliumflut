import 'package:flutter/material.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../app/widgets/app_card.dart';
import '../../app/theme/tokens.dart';
import 'widgets/peer_details_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/mycelium_providers.dart';
import 'package:go_router/go_router.dart';

class PeersScreen extends ConsumerStatefulWidget {
  const PeersScreen({super.key});

  @override
  ConsumerState<PeersScreen> createState() => _PeersScreenState();
}

class _PeersScreenState extends ConsumerState<PeersScreen> {
  String query = '';

  @override
  void initState() {
    super.initState();
    ref.read(peersProvider.notifier).startUpdates();
  }

  @override
  void dispose() {
    ref.read(peersProvider.notifier).stopUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(peersProvider);
    print("Hello ya peers");
    print(peers);
    final filtered = query.isEmpty
        ? peers
        : peers
            .where((p) => p.toLowerCase().contains(query.toLowerCase()))
            .toList();
    return AppScaffold(
      title: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
            ),
            const Spacer(),
            const Text(
              'Peers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
          ],
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context)
              .dividerColor, // You can use Theme.of(context).dividerColor for theme-aware color
        ),
      ]),
      currentIndex: 1,
      onTabSelected: null,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.lg),
          _SearchAddBar(
              onChanged: (v) => setState(() => query = v), onAdd: () {}),
          const SizedBox(height: AppSpacing.xxl),
          if (filtered.isEmpty)
            _PeersEmptyState()
          else
            ...filtered.map((p) => _PeerTile.sample(index: p.hashCode)),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.public,
                        size: 24, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Peer Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _SummaryItem(
                        label: '5', subtitle: 'Usable', color: Colors.green),
                    _SummaryItem(
                        label: '2', subtitle: 'Slow', color: Colors.orange),
                    _SummaryItem(
                        label: '1', subtitle: 'Down', color: Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.podcasts,
                        size: 24, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Network Traffic',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _SummaryItem(label: '10.5 MB/s', subtitle: 'Total Upload'),
                    _SummaryItem(
                        label: '20.5 MB/s', subtitle: 'Total Download'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _SearchAddBar extends StatelessWidget {
  final VoidCallback onAdd;
  final ValueChanged<String>? onChanged;
  const _SearchAddBar({required this.onAdd, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search peers',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => _showAddPeerDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Peer'),
        ),
      ],
    );
  }
}

class _PeerTile extends StatelessWidget {
  final String country;
  final String city;
  final String status;
  final String latency;
  final double health;

  const _PeerTile(
      {required this.country,
      required this.city,
      required this.status,
      required this.latency,
      required this.health});

  factory _PeerTile.sample({required int index}) {
    final samples = [
      ('United States', 'New York', 'Connected', '45ms', 0.9),
      ('Germany', 'Berlin', 'Connected', '78ms', 0.85),
      ('Japan', 'Tokyo', 'Connecting', '156ms', 0.5),
      ('United Kingdom', 'London', 'Usable', '92ms', 0.8),
      ('Canada', 'Toronto', 'Disconnected', '—', 0.2),
      ('Australia', 'Sydney', 'Connected', '203ms', 0.75),
    ];
    final s = samples[index % samples.length];
    return _PeerTile(
        country: s.$1, city: s.$2, status: s.$3, latency: s.$4, health: s.$5);
  }

  Color _statusColor(BuildContext context) {
    switch (status) {
      case 'Connected':
      case 'Usable':
        return Colors.green;
      case 'Connecting':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 16, child: Text('US')),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(country,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            decoration: BoxDecoration(
                                color: _statusColor(context).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            child: Text(status,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: _statusColor(context))),
                          ),
                          const Spacer(),
                          Text(latency,
                              style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(city,
                          style: Theme.of(context).textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => PeerDetailsSheet(
                            country: country,
                            city: city,
                            latency: latency,
                            status: status),
                      );
                    }),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  minHeight: 6,
                  value: health,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_statusColor(context))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeersEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          onPressed: () => _showAddPeerDialog(context),
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

void _showAddPeerDialog(BuildContext context) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Peer'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter peer IP',
        ),
        keyboardType: TextInputType.url,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final ip = controller.text.trim();
            if (ip.isNotEmpty) {
              print('Add peer: $ip');
            }
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
