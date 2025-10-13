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

  @override
  void dispose() {
    _proxyUrlController.dispose();
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
                      'VPN Node Discovery',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (isDiscovering) {
                      vpnProvider.stopProxyDiscovery();
                    } else {
                      vpnProvider.startProxyDiscovery();
                    }
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
                  label: Text(isDiscovering ? 'Stop Search' : 'Search VPN Nodes'),
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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.public,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No VPN nodes discovered yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Search VPN Nodes" to find available servers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyList(BuildContext context, VpnProvider vpnProvider, List<ProxyInfo> proxies, {required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Create auto-select option
    final autoSelectOption = ProxyInfo(
      address: 'auto',
      name: 'Auto-select (Random)',
      isAutoSelected: true,
    );
    
    // Combine auto-select with discovered proxies
    final allOptions = [autoSelectOption, ...proxies];
    
    // Determine selected value
    final selectedValue = vpnProvider.selectedProxy?.address ?? 'auto';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select VPN Node',
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
        
        // Dropdown for VPN node selection
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
            style: Theme.of(context).textTheme.bodyMedium,
            dropdownColor: isDark ? Colors.grey[850] : Colors.white,
            items: allOptions.map((proxy) {
              return DropdownMenuItem<String>(
                value: proxy.address,
                child: Row(
                  children: [
                    if (proxy.address == 'auto') ...[
                      Icon(Icons.auto_awesome, size: 16, color: Colors.blue[400]),
                      const SizedBox(width: 8),
                    ] else ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        proxy.address == 'auto' 
                            ? 'Auto-select (Random)' 
                            : proxy.address,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (proxy.address == 'auto')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                if (newValue == 'auto') {
                  // Auto-select means no specific proxy selected - will pick random on connect
                  vpnProvider.selectProxy(null);
                } else {
                  // Find and select the specific proxy
                  final selectedProxy = proxies.firstWhere(
                    (p) => p.address == newValue,
                    orElse: () => proxies.first,
                  );
                  vpnProvider.selectProxy(selectedProxy);
                }
              }
            },
          ),
        ),
      ],
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
            const SizedBox(height: 12),
            Text(
              isConnected ? 'Connected and protected' : 'Disconnected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isConnected ? Colors.green[600] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            if (isConnected) ...[
              const SizedBox(height: 16),
              _buildStatusRow(context, 'Connected to:', vpnProvider.connectedProxy?.address ?? 'Unknown'),
              const SizedBox(height: 8),
              _buildStatusRow(context, 'Server:', vpnProvider.connectedProxy?.address ?? 'Unknown'),
              const SizedBox(height: 8),
              _buildStatusRow(context, 'Ping:', '25ms'),
              const SizedBox(height: 24),
            ],
            
            if (!isConnected)
              const SizedBox(height: 24),
            
            // Connect/Disconnect button - always visible
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isConnected || vpnProvider.availableProxies.isNotEmpty) 
                    ? () {
                        if (isConnected) {
                          vpnProvider.disconnect();
                        } else {
                          vpnProvider.connect();
                        }
                      }
                    : null, // Disable button when no proxies available and not connected
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected 
                      ? Colors.red
                      : null, // Use theme default (cyan/teal)
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isConnected ? Icons.power_off : Icons.power_settings_new, 
                      size: 20,
                    ),
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

  Widget _buildStatusRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
