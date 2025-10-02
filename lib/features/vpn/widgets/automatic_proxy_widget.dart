import 'package:flutter/material.dart';
import '../../../state/vpn_provider.dart';

class AutomaticProxyWidget extends StatelessWidget {
  final VpnProvider vpnProvider;
  
  const AutomaticProxyWidget({super.key, required this.vpnProvider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Automatic Proxy Discovery',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Automatically discover and connect to available SOCKS5 proxies in the Mycelium network',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Discovery button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !vpnProvider.isProbing
                    ? vpnProvider.startProxyDiscovery
                    : vpnProvider.stopProxyDiscovery,
                icon: !vpnProvider.isProbing
                    ? const Icon(Icons.search)
                    : const Icon(Icons.stop),
                label: !vpnProvider.isProbing
                    ? const Text('Start Discovery')
                    : const Text('Stop Discovery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: !vpnProvider.isProbing ? Colors.blue : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            
            if (vpnProvider.availableProxies.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${vpnProvider.availableProxies.length} proxy(ies) found',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Proxy list
            if (vpnProvider.availableProxies.isEmpty && !vpnProvider.isProbing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No proxies discovered yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start discovery to find available SOCKS5 proxies',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (vpnProvider.isProbing && vpnProvider.availableProxies.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Searching for proxies...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (vpnProvider.availableProxies.isNotEmpty) ...[
              Text(
                'Available Proxies',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...vpnProvider.availableProxies.map((proxy) {
                return RadioListTile<ProxyInfo>(
                  title: Text(proxy.name ?? 'SOCKS5 Proxy'),
                  subtitle: Text(
                    proxy.address,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  value: proxy,
                  groupValue: vpnProvider.selectedProxy,
                  onChanged: vpnProvider.isConnected ? null : vpnProvider.selectProxy,
                  dense: true,
                );
              }).toList(),
            ],
            
            const SizedBox(height: 20),
            
            // Connect/Disconnect button
            if (vpnProvider.selectedProxy != null)
              SizedBox(
                width: double.infinity,
                child: vpnProvider.isConnected
                    ? ElevatedButton.icon(
                        onPressed: vpnProvider.disconnect,
                        icon: const Icon(Icons.stop),
                        label: const Text('Disconnect from Proxy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: vpnProvider.status != ProxyStatus.connecting
                            ? vpnProvider.connect
                            : null,
                        icon: vpnProvider.status == ProxyStatus.connecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          vpnProvider.status == ProxyStatus.connecting
                              ? 'Connecting...'
                              : 'Connect to Selected Proxy',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
