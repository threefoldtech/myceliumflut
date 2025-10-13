import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/ffi/mycelium_service.dart';

enum VpnMode { manual, automatic }

enum ProxyStatus { disconnected, connecting, connected, error }

class ProxyInfo {
  final String address;
  final String? name;
  final bool isAutoSelected;

  ProxyInfo({
    required this.address,
    this.name,
    this.isAutoSelected = false,
  });

  @override
  String toString() => name ?? address;
}

class VpnProvider extends ChangeNotifier {
  final MyceliumService _myceliumService;

  VpnMode _mode = VpnMode.automatic;
  ProxyStatus _status = ProxyStatus.disconnected;
  List<ProxyInfo> _availableProxies = [];
  ProxyInfo? _selectedProxy;
  ProxyInfo? _connectedProxy;
  String _manualAddress = '';
  bool _isProbing = false;
  bool _deviceWideEnabled = false;
  Timer? _probeTimer;
  String? _errorMessage;

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

      // Check if Mycelium is connected first
      if (_myceliumService.status != NodeStatus.connected) {
        print("VpnProvider: Cannot start proxy discovery - Mycelium not connected");
        _setError("Mycelium must be connected to discover proxies");
        _isProbing = false;
        notifyListeners();
        return;
      }

      // Start proxy probe in background without blocking UI
      _myceliumService.startProxyProbe().catchError((e) {
        print("VpnProvider: Error starting proxy probe: $e");
        _setError("Failed to start proxy discovery: $e");
        _isProbing = false;
        notifyListeners();
        return <String>[]; // Return empty list on error
      });

      // Start periodic proxy list updates (longer interval for VPN extension environment)
      _probeTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _updateProxyList();
      });

      // Initial proxy list update after giving mesh network time to stabilize
      Timer(const Duration(seconds: 10), () {
        _updateProxyList();
      });
      
      print("VpnProvider: Proxy discovery started - checking every 15 seconds (VPN extension may need 2-3 minutes)");
    } catch (e) {
      _setError("Failed to start proxy discovery: $e");
      _isProbing = false;
      notifyListeners();
    }
  }

  Future<void> stopProxyDiscovery() async {
    _probeTimer?.cancel();
    _probeTimer = null;

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
      print("VpnProvider: Received ${proxies.length} proxy responses: $proxies");
      
      final newProxies = proxies
          .where((address) =>
              address.isNotEmpty &&
              address != "Failed to list proxies" &&
              address.toLowerCase() != "ok")
          .map((address) => ProxyInfo(
                address: address,
                name: _getProxyDisplayName(address),
              ))
          .toList();
      
      print("VpnProvider: Filtered to ${newProxies.length} valid proxies");

      // Don't auto-select any proxy - keep selectedProxy as null for auto-select mode
      _availableProxies = newProxies;
      notifyListeners();
    } catch (e) {}
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
          // Auto-select mode: pick random available proxy
          if (_availableProxies.isEmpty) {
            throw Exception("No proxies available");
          }
          // Pick a random proxy from available list
          final randomIndex = DateTime.now().millisecondsSinceEpoch % _availableProxies.length;
          proxyAddress = _availableProxies[randomIndex].address;
          proxyInfo = _availableProxies[randomIndex];
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

  @override
  void dispose() {
    _probeTimer?.cancel();
    stopProxyDiscovery();
    super.dispose();
  }
}
