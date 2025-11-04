import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/mycelium_providers.dart' as providers;
import '../../../state/vpn_provider.dart';
import '../../../services/ffi/mycelium_service.dart';
import '../../../app/widgets/responsive_layout.dart';
import '../../../services/geolocation_service.dart';

class ModernVpnLayout extends ConsumerStatefulWidget {
  final MyceliumService myceliumService;

  const ModernVpnLayout({super.key, required this.myceliumService});

  @override
  ConsumerState<ModernVpnLayout> createState() => _ModernVpnLayoutState();
}

class _ModernVpnLayoutState extends ConsumerState<ModernVpnLayout> {
  final TextEditingController _proxyUrlController = TextEditingController();
  String? _validationError;

  @override
  void initState() {
    super.initState();
    // Connect controller to VPN provider
    _proxyUrlController.addListener(() {
      final vpnProvider = ref.read(providers.vpnProvider);
      vpnProvider.setManualAddress(_proxyUrlController.text);
      _validateProxyAddress(_proxyUrlController.text);
    });
  }

  void _validateProxyAddress(String address) {
    setState(() {
      if (address.isEmpty) {
        _validationError = null;
        return;
      }

      // Check IPv4 format: x.x.x.x:port
      final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}:\d+$');
      if (ipv4Regex.hasMatch(address)) {
        _validationError = null;
        return;
      }

      // Check IPv6 format: [xxxx:xxxx:...]:port
      final ipv6Regex = RegExp(r'^\[[0-9a-fA-F:]+\]:\d+$');
      if (ipv6Regex.hasMatch(address)) {
        _validationError = null;
        return;
      }

      _validationError = 'Invalid format. Use [IPv6]:PORT or IPv4:PORT';
    });
  }

  bool _canConnect(VpnProvider vpnProvider, bool isConnected) {
    // Can always disconnect
    if (isConnected) return true;

    // For manual mode, check if address is valid
    if (vpnProvider.mode == VpnMode.manual) {
      return _validationError == null && _proxyUrlController.text.isNotEmpty;
    }

    // For automatic mode, check if proxies are available
    return vpnProvider.availableProxies.isNotEmpty;
  }

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

  Widget _buildConnectionModeCard(BuildContext context, VpnProvider vpnProvider,
      {required bool isDesktop}) {
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
                      ? 'Automatically select a node'
                      : 'Manually configure node',
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
                  inactiveThumbColor: Theme.of(context).colorScheme.primary,
                  value: vpnProvider.mode == VpnMode.automatic,
                  onChanged: (value) {
                    vpnProvider
                        .setMode(value ? VpnMode.automatic : VpnMode.manual);
                  },
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
                hintText: '[410:2778:53bf:6f41:af28:1b60:d7c0:707a]:1080',
                hintStyle: TextStyle(color: Colors.grey[400]),
                errorText: _validationError,
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter vpn node address in format: [IPv6]:PORT or IPv4:PORT',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyDiscoveryCard(BuildContext context, VpnProvider vpnProvider,
      {required bool isDesktop}) {
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
            LayoutBuilder(
              builder: (context, constraints) {
                // Use Row with spaceBetween if enough space, otherwise Wrap
                final hasEnoughSpace = constraints.maxWidth > 450;

                final titleWidget = Row(
                  mainAxisSize: MainAxisSize.min,
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
                );

                final buttonWidget = OutlinedButton.icon(
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
                          ),
                        )
                      : Icon(Icons.search, size: 18),
                  label:
                      Text(isDiscovering ? 'Stop Search' : 'Search VPN Nodes'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                );

                if (hasEnoughSpace) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      titleWidget,
                      buttonWidget,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleWidget,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: buttonWidget,
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            if (proxies.isEmpty && !isDiscovering)
              _buildEmptyState(context)
            else if (proxies.isNotEmpty)
              _buildProxyList(context, vpnProvider, proxies,
                  isDesktop: isDesktop),
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

  Widget _buildProxyList(
      BuildContext context, VpnProvider vpnProvider, List<ProxyInfo> proxies,
      {required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Create auto-select option
    final autoSelectOption = ProxyInfo(
      address: 'auto',
      name: 'Auto-select (Lowest Latency)',
      isAutoSelected: true,
    );

    // Remove duplicates from proxies list by address
    final uniqueProxies = <String, ProxyInfo>{};
    for (final proxy in proxies) {
      uniqueProxies[proxy.address] = proxy;
    }
    final deduplicatedProxies = uniqueProxies.values.toList();

    // Combine auto-select with deduplicated proxies
    final allOptions = [autoSelectOption, ...deduplicatedProxies];

    // Determine selected value - ensure it exists in the list
    var selectedValue = vpnProvider.selectedProxy?.address ?? 'auto';
    // If selected proxy is not in the list, default to auto
    if (selectedValue != 'auto' && !uniqueProxies.containsKey(selectedValue)) {
      selectedValue = 'auto';
    }

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
                '${deduplicatedProxies.length} available',
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
                child: _ProxyDropdownItem(
                  proxy: proxy,
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

  Widget _buildVpnStatusCard(BuildContext context, VpnProvider vpnProvider,
      {required bool isDesktop}) {
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
                  isConnected ? Icons.shield : Icons.shield_outlined,
                  color: isConnected ? Colors.green[400] : Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isConnected ? Colors.green[600] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),

            if (isConnected) ...[
              const SizedBox(height: 16),
              _buildConnectedProxyInfo(context, vpnProvider),
              const SizedBox(height: 24),
            ],

            if (!isConnected) const SizedBox(height: 24),
            // Connect/Disconnect button - always visible
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canConnect(vpnProvider, isConnected)
                    ? () {
                        if (isConnected) {
                          vpnProvider.disconnect();
                        } else {
                          vpnProvider.connect();
                        }
                      }
                    : null, // Disable button when conditions not met
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: isConnected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onPrimary,
                  disabledBackgroundColor:
                      isDark ? Colors.grey[800] : Colors.grey[300],
                  disabledForegroundColor:
                      isDark ? Colors.grey[600] : Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.power_settings_new,
                      size: 20,
                      color: isConnected
                          ? Colors.white
                          : _canConnect(vpnProvider, isConnected)
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Disconnect' : 'Connect',
                      style: const TextStyle(
                        fontSize: 15,
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

  Widget _buildConnectedProxyInfo(
      BuildContext context, VpnProvider vpnProvider) {
    final connectedProxy = vpnProvider.connectedProxy;
    if (connectedProxy == null) return const SizedBox.shrink();

    final geoService = GeolocationService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green[900]?.withValues(alpha: 0.2)
            : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.green[700]! : Colors.green[200]!,
        ),
      ),
      child: Row(
        children: [
          // Country flag
          if (connectedProxy.location != null &&
              connectedProxy.location!.country != 'Unknown')
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: geoService
                    .getFlagWidget(connectedProxy.location!.countryCode),
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.public,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        connectedProxy.address,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.green[300] : Colors.green[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (connectedProxy.pingMs != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getPingColor(connectedProxy.pingMs!)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${connectedProxy.pingMs}ms',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getPingColor(connectedProxy.pingMs!),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (connectedProxy.location != null &&
                    connectedProxy.location!.country != 'Unknown')
                  Text(
                    '${connectedProxy.location!.city.isNotEmpty ? '${connectedProxy.location!.city}, ' : ''}${connectedProxy.location!.country}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPingColor(int pingMs) {
    if (pingMs < 150) return Colors.green;
    if (pingMs < 500) return Colors.orange;
    return Colors.red;
  }
}

/// Widget for displaying proxy dropdown items with country flags
class _ProxyDropdownItem extends ConsumerWidget {
  final ProxyInfo proxy;

  const _ProxyDropdownItem({required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (proxy.address == 'auto') {
      // Auto-select option
      return Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: Colors.blue[400]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Auto-select (Lowest Latency)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
      );
    }

    // Regular proxy option with country flag and ping
    final geoService = GeolocationService();

    return Row(
      children: [
        // Country flag or loading indicator
        if (proxy.location != null && proxy.location!.country != 'Unknown') ...[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: geoService.getFlagWidget(proxy.location!.countryCode),
            ),
          ),
        ] else ...[
          // Show globe icon for unknown countries or while loading
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.public,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                proxy.address,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              if (proxy.location != null &&
                  proxy.location!.country != 'Unknown')
                Text(
                  '${proxy.location!.city.isNotEmpty ? '${proxy.location!.city}, ' : ''}${proxy.location!.country}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        // Ping indicator
        if (proxy.isPinging)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[400],
            ),
          )
        else if (proxy.pingMs != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getPingColor(proxy.pingMs!).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${proxy.pingMs}ms',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getPingColor(proxy.pingMs!),
              ),
            ),
          ),
      ],
    );
  }

  Color _getPingColor(int pingMs) {
    if (pingMs < 150) return Colors.green;
    if (pingMs < 500) return Colors.orange;
    return Colors.red;
  }
}
