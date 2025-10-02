import 'package:flutter/material.dart';
import '../../../state/vpn_provider.dart';

class AutomaticProxyWidget extends StatefulWidget {
  final VpnProvider vpnProvider;
  
  const AutomaticProxyWidget({super.key, required this.vpnProvider});

  @override
  State<AutomaticProxyWidget> createState() => _AutomaticProxyWidgetState();
}

class _AutomaticProxyWidgetState extends State<AutomaticProxyWidget> {
  @override
  void initState() {
    super.initState();
    // User will manually start discovery with the button
  }

  @override
  Widget build(BuildContext context) {
    final vpnProvider = widget.vpnProvider;
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Discovery controls
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: !vpnProvider.isProbing
                          ? vpnProvider.startProxyDiscovery
                          : null,
                      icon: vpnProvider.isProbing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(vpnProvider.isProbing ? 'Searching...' : 'Start Discovery'),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    if (vpnProvider.isProbing)
                      TextButton.icon(
                        onPressed: vpnProvider.stopProxyDiscovery,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    
                    const Spacer(),
                    
                    // Proxy count
                    if (vpnProvider.availableProxies.isNotEmpty)
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
                ),
                const SizedBox(height: 24),
                
                // Proxy list
                _buildProxyList(vpnProvider),
                
                const SizedBox(height: 24),
                
                // Discovery button
                Row(
                  children: [
                    Expanded(
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
                          backgroundColor: !vpnProvider.isProbing
                              ? Colors.blue
                              : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Connect button
                if (!vpnProvider.isConnected && vpnProvider.selectedProxy != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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

  Widget _buildProxyList(VpnProvider vpnProvider) {
    if (!vpnProvider.isProbing && vpnProvider.availableProxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No proxies discovered yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start discovery to find available SOCKS5 proxies',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (vpnProvider.isProbing && vpnProvider.availableProxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Searching for proxies...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                Text(
                  'Available Proxies',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (vpnProvider.isProbing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Auto-select option
            RadioListTile<ProxyInfo?>(
              title: const Text('Auto-select best proxy'),
              subtitle: Text(
                vpnProvider.availableProxies.isNotEmpty
                    ? 'Will use: ${vpnProvider.availableProxies.first.address}'
                    : 'No proxies available',
              ),
              value: vpnProvider.availableProxies.isNotEmpty
                  ? ProxyInfo(
                      address: vpnProvider.availableProxies.first.address,
                      name: "Auto-selected",
                      isAutoSelected: true,
                    )
                  : null,
              groupValue: vpnProvider.selectedProxy,
              onChanged: vpnProvider.isConnected ? null : vpnProvider.selectProxy,
              dense: true,
            ),
            
            const Divider(),
            
            // Individual proxies
            if (vpnProvider.availableProxies.isNotEmpty)
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
                  secondary: _buildProxyIcon(proxy.address),
                );
              }).toList(),
      ],
    );
  }

  Widget _buildProxyIcon(String address) {
    if (address.startsWith('[') && address.contains(']:')) {
      // IPv6
      return const Icon(Icons.language, color: Colors.purple);
    } else {
      // IPv4
      return const Icon(Icons.language, color: Colors.blue);
    }
  }
}
