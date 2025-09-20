import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../state/mycelium_providers.dart';
import '../../../services/ping_service.dart';

class PeerDetailsSheet extends ConsumerStatefulWidget {
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
  ConsumerState<PeerDetailsSheet> createState() => _PeerDetailsSheetState();
}

class _PeerDetailsSheetState extends ConsumerState<PeerDetailsSheet> {
  PingResult? _pingResult;
  bool _isPinging = false;

  Future<void> _performPingTest() async {
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    try {
      final pingService = ref.read(pingServiceProvider);
      final result = await pingService.ping(widget.ip);
      
      if (mounted) {
        setState(() {
          _pingResult = result;
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
                child: Text(widget.country,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: AppSpacing.lg),
            Text(_pingResult?.success == true 
                ? '${_pingResult!.latencyMs}ms' 
                : widget.latency, 
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _pingResult?.success == true 
                      ? (_pingResult!.latencyMs! < 50 
                          ? AppColors.success 
                          : _pingResult!.latencyMs! < 150 
                              ? Colors.orange 
                              : AppColors.error)
                      : null,
                )),
          ]),
          const SizedBox(height: AppSpacing.lg),
          if (_pingResult != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: (_pingResult!.success ? AppColors.success : AppColors.error).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    _pingResult!.success ? Icons.check_circle : Icons.error,
                    color: _pingResult!.success ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pingResult!.success 
                          ? 'Ping successful: ${_pingResult!.latencyMs}ms'
                          : 'Ping failed: Host unreachable',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _pingResult!.success ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isPinging ? null : _performPingTest,
                  child: _isPinging 
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ping Test'),
                ),
              ),
              if (widget.isUserPeer) ...[
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await peersNotifier.removePeer(widget.ip);
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
