import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      builder: (context, child) => _MobileVpnContent(
        vpnProvider: vpnProvider,
        myceliumService: widget.myceliumService,
      ),
    );
  }
}

class _MobileVpnContent extends StatelessWidget {
  final VpnProvider vpnProvider;
  final MyceliumService myceliumService;
  
  const _MobileVpnContent({required this.vpnProvider, required this.myceliumService});

  @override
  Widget build(BuildContext context) {
    // Check if Mycelium is running
    final isMyceliumRunning = myceliumService.status == NodeStatus.connected;
    
    if (!isMyceliumRunning) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'You need to start Mycelium before using the SOCKS5 Proxy VPN.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
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
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Description
          Text(
            'Route traffic through Mycelium mesh',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
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
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16.0),
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: AutomaticProxyWidget(vpnProvider: vpnProvider),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16.0),
                          physics: const AlwaysScrollableScrollPhysics(),
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
