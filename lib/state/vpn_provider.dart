import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/ffi/mycelium_service.dart';
import '../services/geolocation_service.dart';
import '../services/proxy_geolocation_service.dart';

enum VpnMode { manual, automatic }

enum ProxyStatus { disconnected, connecting, connected, error }

class ProxyInfo {
  final String address;
  final String? name;
  final bool isAutoSelected;
  int? pingMs;
  LocationInfo? location;
  bool isPinging;

  ProxyInfo({
    required this.address,
    this.name,
    this.isAutoSelected = false,
    this.pingMs,
    this.location,
    this.isPinging = false,
  });

  @override
  String toString() => name ?? address;
  
  /// Create a copy with updated fields
  ProxyInfo copyWith({
    String? address,
    String? name,
    bool? isAutoSelected,
    int? pingMs,
    LocationInfo? location,
    bool? isPinging,
  }) {
    return ProxyInfo(
      address: address ?? this.address,
      name: name ?? this.name,
      isAutoSelected: isAutoSelected ?? this.isAutoSelected,
      pingMs: pingMs ?? this.pingMs,
      location: location ?? this.location,
      isPinging: isPinging ?? this.isPinging,
    );
  }
}

class VpnProvider extends ChangeNotifier {
  final MyceliumService _myceliumService;

  VpnMode _mode = VpnMode.automatic;
  ProxyStatus _status = ProxyStatus.disconnected;
  List<ProxyInfo> _availableProxies = [];
  List<ProxyInfo> _pendingProxies = []; // Proxies waiting for ping/location data
  ProxyInfo? _selectedProxy;
  ProxyInfo? _connectedProxy;
  String _manualAddress = '';
  bool _isProbing = false;
  bool _deviceWideEnabled = false;
  Timer? _probeTimer;
  Timer? _connectedProxyPingTimer;
  Timer? _periodicPingTimer; // Timer for updating all proxy pings
  String? _errorMessage;

  // Hardcoded proxy nodes for faster initial display (all on port 1080)
  static const List<String> _hardcodedProxyNodes = [
    '[54b:83ab:6cb5:7b38:44ae:cd14:53f3:a907]:1080',
    '[40a:152c:b85b:9646:5b71:d03a:eb27:2462]:1080',
    '[597:a4ef:806:b09:6650:cbbf:1b68:cc94]:1080',
    '[549:8bce:fa45:e001:cbf8:f2e2:2da6:a67c]:1080',
    '[410:2778:53bf:6f41:af28:1b60:d7c0:707a]:1080',
    '[488:74ac:8a31:277b:9683:c8e:e14f:79a7]:1080',
    '[4ab:a385:5a4e:ef8f:92e0:1605:7cb6:24b2]:1080',
    '[4de:b695:3859:8234:d04c:5de6:8097:c27c]:1080',
    '[5eb:c711:f9ab:eb24:ff26:e392:a115:1c0e]:1080',
    '[445:465:fe81:1e2b:5420:a029:6b0:9f61]:1080',
  ];

  VpnProvider(this._myceliumService);

  // Getters
  VpnMode get mode => _mode;
  ProxyStatus get status => _status;
  List<ProxyInfo> get availableProxies => _availableProxies;
  ProxyInfo? get selectedProxy => _selectedProxy;
  ProxyInfo? get connectedProxy => _connectedProxy;
  String get manualAddress => _manualAddress;
  bool get isProbing => _isProbing;
  bool get deviceWideEnabled => _deviceWideEnabled;
  String? get errorMessage => _errorMessage;
  bool get canConnect => _selectedProxy != null || _manualAddress.isNotEmpty;
  bool get isConnected => _status == ProxyStatus.connected;

  void setMode(VpnMode mode) {
    if (_mode != mode) {
      _mode = mode;
      _clearError();

      // Don't auto-start discovery when switching to automatic mode
      // User should manually click "Search VPN Nodes" button
      if (mode == VpnMode.manual) {
        stopProxyDiscovery();
      }

      notifyListeners();
    }
  }

  void setManualAddress(String address) {
    _manualAddress = address.trim();
    _clearError();
    notifyListeners();
  }

  void selectProxy(ProxyInfo? proxy) {
    _selectedProxy = proxy;
    _clearError();
    notifyListeners();
  }

  Future<void> startProxyDiscovery() async {
    if (_isProbing) return; // Already probing

    try {
      _isProbing = true;
      _clearError();
      notifyListeners();

      print("VpnProvider: Starting proxy discovery...");
      
      // Initialize pending proxies with hardcoded addresses
      if (_pendingProxies.isEmpty && _availableProxies.isEmpty) {
        print("VpnProvider: Initializing ${_hardcodedProxyNodes.length} hardcoded proxies in pending state");
        _pendingProxies = _hardcodedProxyNodes.map((address) => ProxyInfo(
          address: address,
          name: _getProxyDisplayName(address),
        )).toList();
        // Don't notify yet - wait until they have data
      }

      // Check if Mycelium is connected first
      if (_myceliumService.status != NodeStatus.connected) {
        print(
            "VpnProvider: Cannot start proxy discovery - Mycelium is not connected");
        _setError("Mycelium must be connected to discover proxies");
        _isProbing = false;
        notifyListeners();
        return;
      }

      // Start proxy probe in background without blocking UI
      final probeResult = await _myceliumService.startProxyProbe();

      // Check for error responses
      if (probeResult.isNotEmpty &&
          probeResult.first.toLowerCase().contains("err_node_timeout")) {
        print(
            "VpnProvider: Node timeout error - Mycelium mesh network not responding");
        _setError("Mesh network timeout - check Mycelium connection");
        _isProbing = false;
        notifyListeners();
        return;
      }

      // Start periodic proxy list updates (longer interval for VPN extension environment)
      _probeTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _updateProxyList();
      });

      // Initial proxy list update after giving mesh network time to stabilize
      Timer(const Duration(seconds: 10), () {
        _updateProxyList();
      });

      print(
          "VpnProvider: Proxy discovery started - checking every 15 seconds (VPN extension may need 2-3 minutes)");
    } catch (e) {
      _setError("Failed to start proxy discovery: $e");
      _isProbing = false;
      notifyListeners();
    }
  }

  Future<void> stopProxyDiscovery() async {
    _probeTimer?.cancel();
    _probeTimer = null;
    
    // Also stop periodic ping updates
    _stopPeriodicPingUpdates();

    if (_isProbing) {
      try {
        await _myceliumService.stopProxyProbe();
      } catch (e) {
        print("VpnProvider: Error stopping proxy probe: $e");
      }
      _isProbing = false;
      notifyListeners();
    }
  }

  Future<void> _updateProxyList() async {
    try {
      print("VpnProvider: Checking for available proxies...");
      final proxies = await _myceliumService.listProxies();
      print(
          "VpnProvider: Received ${proxies.length} proxy responses: $proxies");

      // Check for error responses
      if (proxies.isNotEmpty &&
          proxies.first.toLowerCase().contains("err_node_timeout")) {
        print(
            "VpnProvider: Node timeout error - Mycelium mesh network not responding");
        _setError("Mesh network timeout - check Mycelium connection");
        
        // On timeout, add hardcoded proxies to pending if not already there
        if (_pendingProxies.isEmpty && _availableProxies.isEmpty) {
          print("VpnProvider: Adding hardcoded proxies to pending due to timeout");
          _pendingProxies = _hardcodedProxyNodes.map((address) => ProxyInfo(
            address: address,
            name: _getProxyDisplayName(address),
          )).toList();
          // Process them to get ping/location data
          _processPendingProxies();
        }
        
        // Stop discovery on timeout
        await stopProxyDiscovery();
        return;
      }

      // Filter discovered proxies
      final discoveredProxies = proxies
          .where((address) =>
              address.isNotEmpty &&
              address != "Failed to list proxies" &&
              address.toLowerCase() != "ok" &&
              !address.toLowerCase().contains("err_"))
          .toList();

      print(
          "VpnProvider: Filtered to ${discoveredProxies.length} discovered proxies");

      // Create a set of hardcoded proxy addresses for duplicate detection
      final hardcodedAddressSet =
          _hardcodedProxyNodes.map((addr) => _normalizeProxyAddress(addr)).toSet();

      // Build set of all addresses that should exist
      final Set<String> allAddresses = {..._hardcodedProxyNodes};
      
      // Add discovered proxies only if they're not already in hardcoded list
      for (final discoveredAddress in discoveredProxies) {
        final normalizedDiscovered = _normalizeProxyAddress(discoveredAddress);
        if (!hardcodedAddressSet.contains(normalizedDiscovered)) {
          allAddresses.add(discoveredAddress);
        }
      }

      // Get all existing addresses (both available and pending)
      final existingAvailableAddresses = _availableProxies.map((p) => p.address).toSet();
      final existingPendingAddresses = _pendingProxies.map((p) => p.address).toSet();
      
      // Add new addresses to pending list
      for (final address in allAddresses) {
        if (!existingAvailableAddresses.contains(address) && 
            !existingPendingAddresses.contains(address)) {
          print("VpnProvider: Adding new proxy to pending: $address");
          _pendingProxies.add(ProxyInfo(
            address: address,
            name: _getProxyDisplayName(address),
          ));
        }
      }

      print("VpnProvider: Available: ${_availableProxies.length}, Pending: ${_pendingProxies.length}");
      
      // Ping and fetch location for pending proxies
      _processPendingProxies();
      
      notifyListeners();
    } catch (e) {
      print("VpnProvider: Error updating proxy list: $e");
      _setError("Failed to list proxies: $e");
    }
  }

  /// Process pending proxies: ping them and fetch location data (only once)
  Future<void> _processPendingProxies() async {
    if (_pendingProxies.isEmpty) return;

    print("VpnProvider: Processing ${_pendingProxies.length} pending proxies...");

    // Process each pending proxy
    for (int i = _pendingProxies.length - 1; i >= 0; i--) {
      final proxy = _pendingProxies[i];
      
      // Skip if already being processed
      if (proxy.isPinging) continue;

      // Mark as pinging
      _pendingProxies[i] = proxy.copyWith(isPinging: true);
      
      try {
        // Parse proxy address to get host and port
        final (host, port) = _parseProxyAddress(proxy.address);
        
        // Ping the proxy using socket connection
        final stopwatch = Stopwatch()..start();
        
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        
        stopwatch.stop();
        await socket.close();
        socket.destroy();

        final pingMs = stopwatch.elapsedMilliseconds;
        print("VpnProvider: Proxy ${proxy.address} ping: ${pingMs}ms");
        
        // Fetch location info ONLY ONCE during initial processing
        LocationInfo? location;
        try {
          final proxyGeoService = ProxyGeolocationService();
          location = await proxyGeoService.getLocationForProxy(proxy.address);
          print("VpnProvider: Fetched location for ${proxy.address}: ${location.country}");
        } catch (e) {
          print("VpnProvider: Failed to get location for ${proxy.address}: $e");
        }

        // Move to available list with ping and location data
        final readyProxy = proxy.copyWith(
          pingMs: pingMs,
          location: location,
          isPinging: false,
        );
        
        _availableProxies.add(readyProxy);
        _pendingProxies.removeAt(i);
        
        print("VpnProvider: Moved ${proxy.address} to available list (ping: ${pingMs}ms, country: ${location?.country ?? 'Unknown'})");
        
        // Sort available proxies by ping
        _availableProxies.sort((a, b) {
          if (a.pingMs == null && b.pingMs == null) return 0;
          if (a.pingMs == null) return 1;
          if (b.pingMs == null) return -1;
          return a.pingMs!.compareTo(b.pingMs!);
        });
        
        notifyListeners();
        
        // Add small delay between processing to avoid overwhelming the network
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print("VpnProvider: Failed to process ${proxy.address}: $e");
        // Remove from pending if ping fails
        _pendingProxies.removeAt(i);
        notifyListeners();
      }
    }

    print("VpnProvider: Finished processing. Available: ${_availableProxies.length}, Pending: ${_pendingProxies.length}");
    
    // Start periodic ping updates for all available proxies
    _startPeriodicPingUpdates();
  }

  /// Ping only new proxies that haven't been pinged yet
  Future<void> _pingNewProxies() async {
    if (_availableProxies.isEmpty) return;

    // Find proxies that haven't been pinged yet (no ping data and not currently pinging)
    final indicesToPing = <int>[];
    for (int i = 0; i < _availableProxies.length; i++) {
      if (_availableProxies[i].pingMs == null && !_availableProxies[i].isPinging) {
        indicesToPing.add(i);
      }
    }

    if (indicesToPing.isEmpty) {
      print("VpnProvider: All proxies already pinged, skipping");
      return;
    }

    print("VpnProvider: Pinging ${indicesToPing.length} new proxies...");

    // Ping new proxies in parallel with a limit to avoid overwhelming the network
    final futures = <Future>[];
    for (int i = 0; i < indicesToPing.length; i++) {
      futures.add(_pingProxy(indicesToPing[i]));
      
      // Add small delay between starting pings to avoid socket exhaustion
      if (i < indicesToPing.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Wait for all pings to complete
    await Future.wait(futures);

    // Sort proxies by ping (lowest first), with unpinged at the end
    _availableProxies.sort((a, b) {
      if (a.pingMs == null && b.pingMs == null) return 0;
      if (a.pingMs == null) return 1;
      if (b.pingMs == null) return -1;
      return a.pingMs!.compareTo(b.pingMs!);
    });

    print("VpnProvider: Finished pinging new proxies. Sorted by latency.");
    notifyListeners();
  }

  /// Ping all available proxies and update their latency
  Future<void> _pingAllProxies() async {
    if (_availableProxies.isEmpty) return;

    print("VpnProvider: Starting to ping ${_availableProxies.length} proxies...");

    // Ping proxies in parallel with a limit to avoid overwhelming the network
    final futures = <Future>[];
    for (int i = 0; i < _availableProxies.length; i++) {
      futures.add(_pingProxy(i));
      
      // Add small delay between starting pings to avoid socket exhaustion
      if (i < _availableProxies.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Wait for all pings to complete
    await Future.wait(futures);

    // Sort proxies by ping (lowest first), with unpinged at the end
    _availableProxies.sort((a, b) {
      if (a.pingMs == null && b.pingMs == null) return 0;
      if (a.pingMs == null) return 1;
      if (b.pingMs == null) return -1;
      return a.pingMs!.compareTo(b.pingMs!);
    });

    print("VpnProvider: Finished pinging proxies. Sorted by latency.");
    notifyListeners();
  }

  /// Ping a single proxy and update its latency
  Future<void> _pingProxy(int index) async {
    if (index >= _availableProxies.length) return;

    final proxy = _availableProxies[index];
    
    // Mark as pinging
    _availableProxies[index] = proxy.copyWith(isPinging: true);
    notifyListeners();

    try {
      // Parse proxy address to get host and port
      final (host, port) = _parseProxyAddress(proxy.address);
      
      // Ping the proxy using socket connection
      final stopwatch = Stopwatch()..start();
      
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      
      stopwatch.stop();
      await socket.close();
      socket.destroy();

      // Update proxy with ping result
      _availableProxies[index] = proxy.copyWith(
        pingMs: stopwatch.elapsedMilliseconds,
        isPinging: false,
      );

      print("VpnProvider: Proxy ${proxy.address} ping: ${stopwatch.elapsedMilliseconds}ms");
      
      // Fetch location info in background
      _fetchProxyLocation(index);
    } catch (e) {
      print("VpnProvider: Failed to ping ${proxy.address}: $e");
      _availableProxies[index] = proxy.copyWith(
        pingMs: null,
        isPinging: false,
      );
    }

    notifyListeners();
  }

  /// Fetch location info for a proxy
  Future<void> _fetchProxyLocation(int index) async {
    if (index >= _availableProxies.length) return;

    final proxy = _availableProxies[index];
    
    try {
      // Use ProxyGeolocationService which makes a request through the SOCKS5 proxy
      // to detect the proxy's public IP and get its geolocation
      final proxyGeoService = ProxyGeolocationService();
      final location = await proxyGeoService.getLocationForProxy(proxy.address);
      
      // Update proxy with location
      if (index < _availableProxies.length) {
        _availableProxies[index] = proxy.copyWith(location: location);
        notifyListeners();
      }
    } catch (e) {
      print("VpnProvider: Failed to get location for ${proxy.address}: $e");
    }
  }

  /// Parse proxy address into host and port
  (String, int) _parseProxyAddress(String address) {
    if (address.startsWith('[')) {
      // IPv6 format: [xxxx:xxxx:...]:port
      final closeBracket = address.indexOf(']');
      if (closeBracket == -1) {
        throw FormatException('Invalid IPv6 proxy address: $address');
      }
      final host = address.substring(1, closeBracket);
      final portStr = address.substring(closeBracket + 2); // Skip ']:' 
      final port = int.parse(portStr);
      return (host, port);
    } else {
      // IPv4 format: x.x.x.x:port
      final parts = address.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid IPv4 proxy address: $address');
      }
      final host = parts[0];
      final port = int.parse(parts[1]);
      return (host, port);
    }
  }

  /// Normalize proxy address for duplicate detection
  /// Extracts the core address part, removing port and brackets if present
  String _normalizeProxyAddress(String address) {
    // Remove brackets and port for IPv6: [xxxx:xxxx:...]:port -> xxxx:xxxx:...
    if (address.contains('[') && address.contains(']:')) {
      final parts = address.split(']:');
      return parts[0].replaceAll('[', '').trim();
    }
    // Remove port for IPv4: x.x.x.x:port -> x.x.x.x
    if (address.contains(':')) {
      final parts = address.split(':');
      // For IPv6 without brackets, keep the full address
      // For IPv4, remove the last part (port)
      if (parts.length == 2) {
        // Likely IPv4:port
        return parts[0].trim();
      }
      // IPv6 address without brackets - keep as is
      return address.trim();
    }
    return address.trim();
  }

  String _getProxyDisplayName(String address) {
    // Extract meaningful name from proxy address
    if (address.contains('[') && address.contains(']:')) {
      // IPv6 format: [address]:port
      final parts = address.split(']:');
      if (parts.length == 2) {
        final port = parts[1];
        return "IPv6 Proxy ($port)";
      }
    } else if (address.contains(':')) {
      // IPv4 format: address:port
      final parts = address.split(':');
      if (parts.length == 2) {
        return "IPv4 Proxy (${parts[1]})";
      }
    }
    return "SOCKS5 Proxy";
  }

  Future<void> connect() async {
    if (_status == ProxyStatus.connecting) return;

    try {
      _status = ProxyStatus.connecting;
      _clearError();
      notifyListeners();

      String proxyAddress;
      ProxyInfo proxyInfo;

      if (_mode == VpnMode.manual) {
        if (_manualAddress.isEmpty) {
          throw Exception("Manual address is required");
        }
        if (!_isValidProxyAddress(_manualAddress)) {
          throw Exception("Invalid proxy address format. Use IP:PORT");
        }
        proxyAddress = _manualAddress;
        proxyInfo = ProxyInfo(
          address: proxyAddress,
          name: "Manual Proxy",
        );
      } else {
        if (_selectedProxy == null) {
          // Auto-select mode: pick proxy with lowest ping
          if (_availableProxies.isEmpty) {
            throw Exception("No proxies available");
          }
          
          // Find proxy with lowest ping (proxies are already sorted by ping)
          // First proxy in the list has the lowest ping
          final bestProxy = _availableProxies.firstWhere(
            (p) => p.pingMs != null,
            orElse: () => _availableProxies.first,
          );
          
          proxyAddress = bestProxy.address;
          proxyInfo = bestProxy;
          print("VpnProvider: Auto-selected proxy with ${bestProxy.pingMs ?? '?'}ms ping: ${bestProxy.address}");
        } else {
          proxyAddress = _selectedProxy!.address;
          proxyInfo = _selectedProxy!;
        }
      }

      print("VpnProvider: Connecting to proxy: $proxyAddress");

      // Connect to the proxy
      final connectResult = await _myceliumService.proxyConnect(proxyAddress);
      print("VpnProvider: Proxy connect result: $connectResult");

      if (connectResult.isEmpty || connectResult[0] != "ok") {
        throw Exception(
            "Failed to connect to proxy: ${connectResult.join(', ')}");
      }

      // Extract actual proxy address from result
      String actualAddress = proxyAddress;
      if (connectResult.length > 1) {
        actualAddress = connectResult[1];
      }

      // Enable device-wide proxy
      final deviceWideResult = await _myceliumService.enableDeviceWideProxy(
        proxyAddress: actualAddress,
      );

      if (!deviceWideResult) {
        // Clean up proxy connection
        await _myceliumService.proxyDisconnect();
        throw Exception("Failed to enable device-wide proxy");
      }

      _status = ProxyStatus.connected;
      _connectedProxy = proxyInfo;
      _deviceWideEnabled = true;

      // Stop proxy discovery when connected
      await stopProxyDiscovery();

      // Start periodic ping updates for connected proxy
      _startConnectedProxyPing();

      print("VpnProvider: Successfully connected to SOCKS5 proxy");
    } catch (e) {
      _status = ProxyStatus.error;
      _setError("Connection failed: $e");
      print("VpnProvider: Connection error: $e");
    }

    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      _clearError();

      // Always try to disable device-wide proxy (even if flag is not set)
      // This ensures system proxy is cleaned up
      print("VpnProvider: Disabling device-wide proxy...");
      await _myceliumService.disableDeviceWideProxy();
      _deviceWideEnabled = false;

      // Disconnect from proxy
      if (_status == ProxyStatus.connected) {
        print("VpnProvider: Disconnecting from proxy...");
        await _myceliumService.proxyDisconnect();
      }

      _status = ProxyStatus.disconnected;
      _connectedProxy = null;

      // Stop periodic ping updates
      _stopConnectedProxyPing();

      print("VpnProvider: Disconnected from SOCKS5 proxy");
    } catch (e) {
      _setError("Disconnect failed: $e");
      print("VpnProvider: Disconnect error: $e");
    }

    notifyListeners();
  }

  bool _isValidProxyAddress(String address) {
    // Check IPv4 format: x.x.x.x:port
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}:\d+$');
    if (ipv4Regex.hasMatch(address)) {
      return true;
    }

    // Check IPv6 format: [xxxx:xxxx:...]:port
    final ipv6Regex = RegExp(r'^\[[0-9a-fA-F:]+\]:\d+$');
    if (ipv6Regex.hasMatch(address)) {
      return true;
    }

    return false;
  }

  void _setError(String message) {
    _errorMessage = message;
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Start periodic ping updates for all available proxies (every 10 seconds)
  void _startPeriodicPingUpdates() {
    // Cancel any existing timer
    _periodicPingTimer?.cancel();

    // Ping every 10 seconds
    _periodicPingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateAllProxyPings(),
    );
    
    print("VpnProvider: Started periodic ping updates (every 10 seconds)");
  }

  /// Stop periodic ping updates for all proxies
  void _stopPeriodicPingUpdates() {
    _periodicPingTimer?.cancel();
    _periodicPingTimer = null;
    print("VpnProvider: Stopped periodic ping updates");
  }

  /// Update ping for all available proxies (preserves location data)
  Future<void> _updateAllProxyPings() async {
    if (_availableProxies.isEmpty) return;

    print("VpnProvider: Updating ping for ${_availableProxies.length} proxies...");

    // Update pings for all proxies in parallel
    final futures = <Future>[];
    for (int i = 0; i < _availableProxies.length; i++) {
      futures.add(_updateProxyPing(i));
      
      // Small delay to avoid overwhelming network
      if (i < _availableProxies.length - 1) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    await Future.wait(futures);

    // Re-sort by ping after updates
    _availableProxies.sort((a, b) {
      if (a.pingMs == null && b.pingMs == null) return 0;
      if (a.pingMs == null) return 1;
      if (b.pingMs == null) return -1;
      return a.pingMs!.compareTo(b.pingMs!);
    });

    notifyListeners();
  }

  /// Update ping for a single proxy (keeps location data)
  Future<void> _updateProxyPing(int index) async {
    if (index >= _availableProxies.length) return;

    final proxy = _availableProxies[index];
    
    try {
      // Parse proxy address to get host and port
      final (host, port) = _parseProxyAddress(proxy.address);
      
      // Ping the proxy using socket connection
      final stopwatch = Stopwatch()..start();
      
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      
      stopwatch.stop();
      await socket.close();
      socket.destroy();

      // Update proxy with new ping (preserve location)
      _availableProxies[index] = proxy.copyWith(
        pingMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      // On ping failure, keep old ping value
      // Don't log every failure to avoid spam
    }
  }

  /// Start periodic ping updates for connected proxy
  void _startConnectedProxyPing() {
    // Cancel any existing timer
    _connectedProxyPingTimer?.cancel();

    // Ping immediately
    _updateConnectedProxyPing();

    // Then ping every 10 seconds (same as list updates)
    _connectedProxyPingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateConnectedProxyPing(),
    );
  }

  /// Stop periodic ping updates for connected proxy
  void _stopConnectedProxyPing() {
    _connectedProxyPingTimer?.cancel();
    _connectedProxyPingTimer = null;
  }

  /// Update ping for the currently connected proxy
  Future<void> _updateConnectedProxyPing() async {
    if (_connectedProxy == null) return;

    try {
      // Parse proxy address to get host and port
      final (host, port) = _parseProxyAddress(_connectedProxy!.address);

      // Ping the proxy using socket connection
      final stopwatch = Stopwatch()..start();

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      stopwatch.stop();
      await socket.close();
      socket.destroy();

      final newPingMs = stopwatch.elapsedMilliseconds;

      // Update connected proxy with new ping result
      _connectedProxy = _connectedProxy!.copyWith(
        pingMs: newPingMs,
      );

      // Also update the proxy in the available list
      final index = _availableProxies.indexWhere((p) => p.address == _connectedProxy!.address);
      if (index != -1) {
        _availableProxies[index] = _availableProxies[index].copyWith(
          pingMs: newPingMs,
        );
      }

      notifyListeners();
    } catch (e) {
      // If ping fails, keep the old ping value
      print("VpnProvider: Failed to ping connected proxy: $e");
    }
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _connectedProxyPingTimer?.cancel();
    _periodicPingTimer?.cancel();
    stopProxyDiscovery();
    super.dispose();
  }
}
