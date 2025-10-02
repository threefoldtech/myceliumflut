import 'package:flutter/material.dart';
import '../../../state/vpn_provider.dart';

class ManualProxyWidget extends StatefulWidget {
  final VpnProvider vpnProvider;
  
  const ManualProxyWidget({super.key, required this.vpnProvider});

  @override
  State<ManualProxyWidget> createState() => _ManualProxyWidgetState();
}

class _ManualProxyWidgetState extends State<ManualProxyWidget> {
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.vpnProvider.manualAddress;
    _addressController.addListener(() {
      widget.vpnProvider.setManualAddress(_addressController.text);
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
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
                const Icon(Icons.settings, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Manual Proxy Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Enter the IP address and port of your SOCKS5 proxy server',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Proxy Address',
                      hintText: '192.168.1.100:1080 or [::1]:1080',
                      prefixIcon: Icon(Icons.language),
                      border: OutlineInputBorder(),
                      helperText: 'Format: IP:PORT (IPv4 or IPv6)',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a proxy address';
                      }
                      
                      final address = value.trim();
                      
                      // Check IPv4 format: x.x.x.x:port
                      final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}:\d+$');
                      if (ipv4Regex.hasMatch(address)) {
                        // Validate IP parts
                        final parts = address.split(':');
                        final ipParts = parts[0].split('.');
                        for (final part in ipParts) {
                          final num = int.tryParse(part);
                          if (num == null || num < 0 || num > 255) {
                            return 'Invalid IPv4 address';
                          }
                        }
                        
                        // Validate port
                        final port = int.tryParse(parts[1]);
                        if (port == null || port < 1 || port > 65535) {
                          return 'Invalid port number (1-65535)';
                        }
                        
                        return null;
                      }
                      
                      // Check IPv6 format: [xxxx:xxxx:...]:port
                      final ipv6Regex = RegExp(r'^\[[0-9a-fA-F:]+\]:\d+$');
                      if (ipv6Regex.hasMatch(address)) {
                        // Basic IPv6 validation
                        final parts = address.split(']:');
                        if (parts.length != 2) {
                          return 'Invalid IPv6 format';
                        }
                        
                        // Validate port
                        final port = int.tryParse(parts[1]);
                        if (port == null || port < 1 || port > 65535) {
                          return 'Invalid port number (1-65535)';
                        }
                        
                        return null;
                      }
                      
                      return 'Invalid format. Use IP:PORT (e.g., 192.168.1.100:1080 or [::1]:1080)';
                    },
                    enabled: !vpnProvider.isConnected,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Connect button
                  if (!vpnProvider.isConnected)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: vpnProvider.manualAddress.isNotEmpty && 
                                  vpnProvider.status != ProxyStatus.connecting
                            ? () {
                                if (_formKey.currentState!.validate()) {
                                  vpnProvider.connect();
                                }
                              }
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
                              : 'Connect to Proxy',
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
          ],
        ),
      ),
    );
  }

}
