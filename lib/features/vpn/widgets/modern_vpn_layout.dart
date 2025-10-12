import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/mycelium_providers.dart' as providers;
import '../../../state/vpn_provider.dart';
import '../../../services/ffi/mycelium_service.dart';
import '../../../app/widgets/responsive_layout.dart';

class ModernVpnLayout extends ConsumerStatefulWidget {
  final MyceliumService myceliumService;
  
  const ModernVpnLayout({super.key, required this.myceliumService});

  @override
  ConsumerState<ModernVpnLayout> createState() => _ModernVpnLayoutState();
}

class _ModernVpnLayoutState extends ConsumerState<ModernVpnLayout> {
  final TextEditingController _proxyUrlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _showAllProxies = false;

  @override
  void dispose() {
    _proxyUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpnProvider = ref.watch(providers.vpnProvider);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return ListenableBuilder(
      listenable: vpnProvider,
      builder: (context, child) {
        if (isDesktop) {
          return _buildDesktopLayout(context, vpnProvider);
        } else {
          return _buildMobileLayout(context, vpnProvider);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, VpnProvider vpnProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Main content
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnectionModeCard(context, vpnProvider, isDesktop: true),
              const SizedBox(height: 16),
              if (vpnProvider.mode == VpnMode.manual)
                _buildManualConfigCard(context, vpnProvider)
              else
                _buildProxyDiscoveryCard(context, vpnProvider, isDesktop: true),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Right side - VPN Status
        SizedBox(
          width: 320,
          child: _buildVpnStatusCard(context, vpnProvider, isDesktop: true),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, VpnProvider vpnProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConnectionModeCard(context, vpnProvider, isDesktop: false),
          const SizedBox(height: 16),
          if (vpnProvider.mode == VpnMode.manual)
            _buildManualConfigCard(context, vpnProvider)
          else
            _buildProxyDiscoveryCard(context, vpnProvider, isDesktop: false),
          const SizedBox(height: 16),
          _buildVpnStatusCard(context, vpnProvider, isDesktop: false),
        ],
      ),
    );
  }

  Widget _buildConnectionModeCard(BuildContext context, VpnProvider vpnProvider, {required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vpnProvider.mode == VpnMode.automatic
                      ? 'Automatically select best proxy'
                      : 'Manually configure proxy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  vpnProvider.mode == VpnMode.automatic ? 'Auto' : 'Manual',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: vpnProvider.mode == VpnMode.automatic,
                  onChanged: (value) {
                    vpnProvider.setMode(value ? VpnMode.automatic : VpnMode.manual);
                  },
                  activeColor: Colors.blue[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualConfigCard(BuildContext context, VpnProvider vpnProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: Colors.blue[400]),
                const SizedBox(width: 8),
                Text(
                  'Manual Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Proxy URL',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _proxyUrlController,
              decoration: InputDecoration(
                hintText: 'http://proxy.example.com:8080',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the complete proxy URL including protocol and port',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyDiscoveryCard(BuildContext context, VpnProvider vpnProvider, {required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final proxies = vpnProvider.availableProxies;
    final isDiscovering = vpnProvider.isProbing;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.search, size: 20, color: Colors.blue[400]),
                    const SizedBox(width: 8),
                    Text(
                      'Proxy Discovery',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: isDiscovering ? null : () {
                    vpnProvider.startProxyDiscovery();
                  },
                  icon: isDiscovering 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        )
                      : Icon(Icons.search, size: 18),
                  label: Text(isDiscovering ? 'Searching...' : 'Search Proxies'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (proxies.isEmpty && !isDiscovering)
              _buildEmptyState(context)
            else if (proxies.isNotEmpty)
              _buildProxyList(context, vpnProvider, proxies, isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.public,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No proxies discovered yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Search Proxies" to find available servers',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProxyList(BuildContext context, VpnProvider vpnProvider, List<ProxyInfo> proxies, {required bool isDesktop}) {
    final displayProxies = _showAllProxies ? proxies : proxies.take(1).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Proxy',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${proxies.length} available',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Best proxy (first one)
        ...displayProxies.map((proxy) => _buildProxyItem(
          context,
          proxy,
          isSelected: vpnProvider.selectedProxy?.address == proxy.address,
          isBest: proxies.indexOf(proxy) == 0,
          onTap: () {
            // Update the selectProxy method to actually set the proxy
            vpnProvider.selectProxy(proxy);
          },
        )),
        
        if (proxies.length > 1) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              setState(() {
                _showAllProxies = !_showAllProxies;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showAllProxies ? 'Hide Proxies' : 'All Discovered Proxies',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      if (!_showAllProxies)
                        Text(
                          '${proxies.length} total',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _showAllProxies ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        
        if (_showAllProxies && proxies.length > 1) ...[
          const SizedBox(height: 12),
          ...proxies.skip(1).map((proxy) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildProxyItem(
              context,
              proxy,
              isSelected: vpnProvider.selectedProxy?.address == proxy.address,
              isBest: false,
              onTap: () {
                vpnProvider.selectProxy(proxy);
              },
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildProxyItem(
    BuildContext context,
    ProxyInfo proxy,
    {
      required bool isSelected,
      required bool isBest,
      required VoidCallback onTap,
    }
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.blue[900]!.withValues(alpha: 0.3) : Colors.blue[50])
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[400]! : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green[400],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          proxy.address,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'US',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Ping: 26ms',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Speed: Fast',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVpnStatusCard(BuildContext context, VpnProvider vpnProvider, {required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = vpnProvider.isConnected;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green[400] : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'VPN Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  isConnected ? Icons.shield_outlined : Icons.shield,
                  color: isConnected ? Colors.green[400] : Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isConnected ? 'Connected and protected' : 'Disconnected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            if (isConnected) ...[
              const SizedBox(height: 20),
              _buildStatusRow(context, 'Connected to:', vpnProvider.connectedProxy?.address ?? 'Unknown', showBadge: true),
              const SizedBox(height: 12),
              _buildStatusRow(context, 'Server:', vpnProvider.connectedProxy?.address ?? 'Unknown'),
              const SizedBox(height: 12),
              _buildStatusRow(context, 'Ping:', '25ms'),
            ],
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isConnected) {
                    vpnProvider.disconnect();
                  } else {
                    vpnProvider.connect();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red[600] : Colors.blue[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isConnected ? Icons.power_settings_new : Icons.power_settings_new, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Disconnect' : 'Connect',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, String value, {bool showBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            if (showBadge)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'US',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
