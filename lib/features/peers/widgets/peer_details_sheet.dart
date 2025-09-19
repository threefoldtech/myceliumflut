import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../state/mycelium_providers.dart';

class PeerDetailsSheet extends ConsumerWidget {
  final String ip;
  final String country;
  final String city;
  final String latency;
  final String status;
  final bool isUserPeer;

  const PeerDetailsSheet(
      {super.key,
      required this.country,
      required this.city,
      required this.latency,
      required this.status,
      required this.ip,
      this.isUserPeer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersNotifier = ref.read(peersProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2))),
          Row(children: [
            const CircleAvatar(radius: 16, child: Text('US')),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
                child: Text(country,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: AppSpacing.lg),
            Text(latency, style: Theme.of(context).textTheme.labelMedium),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Ping Test'),
                ),
              ),
              if (isUserPeer) ...[
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await peersNotifier.removePeer(ip);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Remove Peer'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;
  const _Kpi({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.md)),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ]),
      ),
    );
  }
}
