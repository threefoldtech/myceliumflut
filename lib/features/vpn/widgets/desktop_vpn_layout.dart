import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/vpn_provider.dart';
import '../../../services/ffi/mycelium_service.dart';
import 'manual_proxy_widget.dart';
import 'automatic_proxy_widget.dart';
import 'proxy_status_widget.dart';

class DesktopVpnLayout extends ConsumerStatefulWidget {
  final MyceliumService myceliumService;
  
  const DesktopVpnLayout({super.key, required this.myceliumService});

  @override
  ConsumerState<DesktopVpnLayout> createState() => _DesktopVpnLayoutState();
}

class _DesktopVpnLayoutState extends ConsumerState<DesktopVpnLayout> {
  late VpnProvider vpnProvider;

  @override
  void initState() {
    super.initState();
    vpnProvider = VpnProvider(widget.myceliumService);
  }

  @override
  void dispose() {
    vpnProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vpnProvider,
      builder: (context, child) => _VpnContent(vpnProvider: vpnProvider),
    );
  }
}

class _VpnContent extends StatelessWidget {
  final VpnProvider vpnProvider;
  
  const _VpnContent({required this.vpnProvider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
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
          Expanded(
            child: vpnProvider.mode == VpnMode.automatic
                ? AutomaticProxyWidget(vpnProvider: vpnProvider)
                : ManualProxyWidget(vpnProvider: vpnProvider),
          ),
        ],
      ),
    );
  }
}
