import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/widgets/app_scaffold.dart';
import '../../state/mycelium_providers.dart';
import 'widgets/desktop_vpn_layout.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myceliumService = ref.watch(myceliumServiceProvider);
    
    return AppScaffold(
      title: Row(
        children: [
          const Icon(Icons.vpn_lock, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'SOCKS5 Proxy VPN',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      currentIndex: 2, // VPN tab index
      child: DesktopVpnLayout(myceliumService: myceliumService),
    );
  }
}
