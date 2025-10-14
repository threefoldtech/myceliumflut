import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../state/mycelium_providers.dart' as providers;
import '../../../state/vpn_provider.dart';
import '../../../services/ffi/mycelium_service.dart';
import 'manual_proxy_widget.dart';
import 'automatic_proxy_widget.dart';
import 'proxy_status_widget.dart';

class DesktopVpnLayout extends ConsumerWidget {
  final MyceliumService myceliumService;

  const DesktopVpnLayout({super.key, required this.myceliumService});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnProvider = ref.watch(providers.vpnProvider);

    return ListenableBuilder(
      listenable: vpnProvider,
      builder: (context, child) => _VpnContent(
        vpnProvider: vpnProvider,
        myceliumService: myceliumService,
      ),
    );
  }
}

class _VpnContent extends StatelessWidget {
  final VpnProvider vpnProvider;
  final MyceliumService myceliumService;

  const _VpnContent({required this.vpnProvider, required this.myceliumService});

  @override
  Widget build(BuildContext context) {
    // Check if Mycelium is running
    final isMyceliumRunning = myceliumService.status == NodeStatus.connected;

    if (!isMyceliumRunning) {
      return Center(
        child: Card(
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
                  'You need to start Mycelium before using the VPN.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to home screen
                    context.go('/');
                  },
                  icon: Icon(
                    Icons.home,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  label: const Text('Go to Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Card
        ProxyStatusWidget(vpnProvider: vpnProvider),

        const SizedBox(height: 24),

        // Mode Selection
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Mode Toggle
                SegmentedButton<VpnMode>(
                  segments: const [
                    ButtonSegment<VpnMode>(
                      value: VpnMode.automatic,
                      label: Text('Automatic'),
                      icon: Icon(Icons.auto_awesome),
                    ),
                    ButtonSegment<VpnMode>(
                      value: VpnMode.manual,
                      label: Text('Manual'),
                      icon: Icon(Icons.settings),
                    ),
                  ],
                  selected: {vpnProvider.mode},
                  onSelectionChanged: (Set<VpnMode> selection) {
                    vpnProvider.setMode(selection.first);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Mode-specific content
        vpnProvider.mode == VpnMode.automatic
            ? AutomaticProxyWidget(vpnProvider: vpnProvider)
            : ManualProxyWidget(vpnProvider: vpnProvider),
      ],
    );
  }
}
