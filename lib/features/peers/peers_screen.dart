import 'package:flutter/material.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../app/widgets/app_card.dart';
import '../../app/theme/tokens.dart';
import 'widgets/peer_details_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/mycelium_providers.dart';
import 'package:go_router/go_router.dart';
import '../../services/ffi/mycelium_service.dart';

class PeersScreen extends ConsumerWidget {
  const PeersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(peersProvider);
    final title =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
        color: Theme.of(context).dividerColor,
      ),
    ]);
    return peersAsync.when(
      loading: () => AppScaffold(
        title: title,
        currentIndex: 1,
        onTabSelected: null,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => AppScaffold(
        title: title,
        currentIndex: 1,
        onTabSelected: null,
        child: Center(child: Text('Error loading peers: $error')),
      ),
      data: (peers) => _PeersDataScreen(peers: peers),
    );
  }
}

class _PeersDataScreen extends ConsumerStatefulWidget {
  final List<String> peers;

  const _PeersDataScreen({required this.peers});

  @override
  ConsumerState<_PeersDataScreen> createState() => _PeersDataScreenState();
}

class _PeersDataScreenState extends ConsumerState<_PeersDataScreen> {
  String query = '';
  List<String> peerStatus = [];
  String? peerStatusError;

  @override
  void initState() {
    super.initState();
    _fetchPeerStatus();
  }

  Future<void> _fetchPeerStatus() async {
    try {
      final service = MyceliumService();
      final status = await service.getPeerStatus();
      setState(() {
        peerStatus = status;
        peerStatusError = null;
      });
      print('Peer status: $status');
    } catch (e) {
      setState(() {
        peerStatusError = e.toString();
      });
      print('Error getting peer status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = query.isEmpty
        ? widget.peers
        : widget.peers
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _SearchAddBar(
            onChanged: (v) => setState(() => query = v),
            onAdd: () => _showAddPeerDialog(context, ref),
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            _PeersEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) {
                final p = filtered[index];
                return _PeerTile(
                  ip: p,
                  country: "Unknown",
                  health: 0.8,
                );
              },
            ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.public,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('Peer Summary',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
          if (peerStatusError != null)
            Text('Error getting peer status: $peerStatusError',
                style: TextStyle(color: Colors.red)),
          if (peerStatus.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Peer Status:',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...peerStatus.map((status) => Text(status)).toList(),
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
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('Network Traffic',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
        ],
      ),
    );
  }
}

class _SearchAddBar extends ConsumerWidget {
  final VoidCallback onAdd;
  final ValueChanged<String>? onChanged;
  const _SearchAddBar({required this.onAdd, this.onChanged});

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
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => _showAddPeerDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add Peer'),
        ),
      ],
    );
  }
}

class _PeerTile extends StatelessWidget {
  final String ip;
  final String country;
  final double health;

  const _PeerTile({
    required this.ip,
    required this.country,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(
                  country.isNotEmpty
                      ? country.substring(0, 2).toUpperCase()
                      : "??",
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ip,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      country,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      city: "",
                      latency: "",
                      status: "",
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: health,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                health > 0.7
                    ? Colors.green
                    : (health > 0.3 ? Colors.orange : Colors.red),
              ),
            ),
          ),
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
    builder: (context) => AlertDialog(
      title: const Text('Add Peer'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Enter peer IP'),
        keyboardType: TextInputType.url,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final ip = controller.text.trim();
            if (ip.isNotEmpty) {
              await peersNotifier.addPeer(ip);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
