import 'package:flutter/material.dart';
import '../../../state/vpn_provider.dart';
import '../../../services/ffi/mycelium_service.dart';
import 'proxy_status_widget.dart';
import 'manual_proxy_widget.dart';
import 'automatic_proxy_widget.dart';

class MobileVpnLayout extends StatefulWidget {
  final MyceliumService myceliumService;
  
  const MobileVpnLayout({super.key, required this.myceliumService});

  @override
  State<MobileVpnLayout> createState() => _MobileVpnLayoutState();
}

class _MobileVpnLayoutState extends State<MobileVpnLayout> {
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
      builder: (context, child) => _MobileVpnContent(vpnProvider: vpnProvider),
    );
  }
}

class _MobileVpnContent extends StatelessWidget {
  final VpnProvider vpnProvider;
  
  const _MobileVpnContent({required this.vpnProvider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Description
          Text(
            'Route traffic through Mycelium mesh',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Status
          ProxyStatusWidget(vpnProvider: vpnProvider),
          
          const SizedBox(height: 16),
          
          // Mode tabs
          Expanded(
            child: DefaultTabController(
              length: 2,
              initialIndex: vpnProvider.mode == VpnMode.automatic ? 0 : 1,
              child: Column(
                children: [
                  TabBar(
                    onTap: (index) {
                      vpnProvider.setMode(
                        index == 0 ? VpnMode.automatic : VpnMode.manual,
                      );
                    },
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.auto_awesome),
                        text: 'Automatic',
                      ),
                      Tab(
                        icon: Icon(Icons.settings),
                        text: 'Manual',
                      ),
                    ],
                  ),
                  
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: AutomaticProxyWidget(vpnProvider: vpnProvider),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ManualProxyWidget(vpnProvider: vpnProvider),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
