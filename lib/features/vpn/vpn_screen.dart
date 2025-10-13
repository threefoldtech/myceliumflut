import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../state/mycelium_providers.dart';
import '../../services/ffi/mycelium_service.dart';
import 'widgets/modern_vpn_layout.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myceliumService = ref.watch(myceliumServiceProvider);

    return AppScaffold(
      title: Text(
        'VPN',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      currentIndex: 2, // VPN tab index
      child: StreamBuilder(
        stream: myceliumService.statusStream,
        builder: (context, snapshot) {
          // Check if Mycelium is running
          final isMyceliumRunning =
              myceliumService.status == NodeStatus.connected;

          if (!isMyceliumRunning) {
            return _buildMyceliumNotRunning(context);
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ModernVpnLayout(myceliumService: myceliumService),
          );
        },
      ),
    );
  }

  Widget _buildMyceliumNotRunning(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(24.0),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Colors.orange[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Mycelium Not Running',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'You need to start Mycelium before using the SOCKS5 Proxy VPN.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/');
                },
                icon: const Icon(Icons.home),
                label: const Text('Go to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
