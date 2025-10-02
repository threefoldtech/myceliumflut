import 'package:flutter/material.dart';
import '../../../state/vpn_provider.dart';

class ProxyStatusWidget extends StatelessWidget {
  final VpnProvider vpnProvider;
  
  const ProxyStatusWidget({super.key, required this.vpnProvider});

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
                _buildStatusIcon(vpnProvider.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(vpnProvider.status),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(vpnProvider.status),
                        ),
                      ),
                      Text(
                        _getStatusDescription(vpnProvider),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vpnProvider.isConnected)
                  ElevatedButton.icon(
                    onPressed: vpnProvider.disconnect,
                    icon: const Icon(Icons.stop),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  )
                else if (vpnProvider.canConnect && vpnProvider.status != ProxyStatus.connecting)
                  ElevatedButton.icon(
                    onPressed: vpnProvider.connect,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                else if (vpnProvider.status == ProxyStatus.connecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            
            // Error message
            if (vpnProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vpnProvider.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Connected proxy info
            if (vpnProvider.connectedProxy != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected to: ${vpnProvider.connectedProxy!.name}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            vpnProvider.connectedProxy!.address,
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ProxyStatus status) {
    switch (status) {
      case ProxyStatus.connected:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case ProxyStatus.connecting:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ProxyStatus.error:
        return const Icon(Icons.error, color: Colors.red, size: 24);
      case ProxyStatus.disconnected:
        return const Icon(Icons.circle_outlined, color: Colors.grey, size: 24);
    }
  }

  Color _getStatusColor(ProxyStatus status) {
    switch (status) {
      case ProxyStatus.connected:
        return Colors.green;
      case ProxyStatus.connecting:
        return Colors.orange;
      case ProxyStatus.error:
        return Colors.red;
      case ProxyStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusTitle(ProxyStatus status) {
    switch (status) {
      case ProxyStatus.connected:
        return 'Connected';
      case ProxyStatus.connecting:
        return 'Connecting...';
      case ProxyStatus.error:
        return 'Connection Failed';
      case ProxyStatus.disconnected:
        return 'Disconnected';
    }
  }

  String _getStatusDescription(VpnProvider vpnProvider) {
    switch (vpnProvider.status) {
      case ProxyStatus.connected:
        return vpnProvider.deviceWideEnabled 
            ? 'All device traffic is routed through SOCKS5 proxy'
            : 'Proxy connected but device-wide routing disabled';
      case ProxyStatus.connecting:
        return 'Establishing connection to SOCKS5 proxy...';
      case ProxyStatus.error:
        return 'Failed to establish proxy connection';
      case ProxyStatus.disconnected:
        return 'No active proxy connection';
    }
  }
}
