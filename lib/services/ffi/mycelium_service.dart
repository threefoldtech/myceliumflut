import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../myceliumflut_ffi_binding.dart';
import '../../models/peer_models.dart';

enum NodeStatus { disconnected, connecting, connected, failed }

class MyceliumService {
  static const MethodChannel _platform =
      MethodChannel("tech.threefold.mycelium/tun");

  final StreamController<NodeStatus> _statusController =
      StreamController<NodeStatus>.broadcast();
  NodeStatus _status = NodeStatus.disconnected;
  Uint8List? _privKey;

  Stream<NodeStatus> get statusStream => _statusController.stream;
  NodeStatus get status => _status;

  Future<Uint8List> _loadOrGeneratePrivKey() async {
    if (_privKey != null) return _privKey!;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/priv_key.bin');
    if (file.existsSync()) {
      _privKey = await file.readAsBytes();
      return _privKey!;
    }
    Uint8List privKey;
    if (isUseDylib()) {
      privKey = myFFGenerateSecretKey();
    } else {
      privKey = (await _platform.invokeMethod<Uint8List>('generateSecretKey'))
          as Uint8List;
    }
    await file.writeAsBytes(privKey);
    _privKey = privKey;
    return privKey;
  }

  Future<List<String>> loadPeers() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/peers.txt');
    if (await file.exists()) {
      final contents = await file.readAsString();
      return contents.split('\n');
    }
    return [];
  }

  Future<void> storePeers(List<String> peers) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/peers.txt');
    await file.writeAsString(peers.join('\n'));
  }

  List<String> preprocessPeers(List<String> peers) {
    peers.removeWhere((p) => p.trim().isEmpty);
    return peers.toSet().toList();
  }

  String? validatePeer(String peer) {
    final prefixRegex = RegExp(r'^tcp://');
    final ipv4Regex = RegExp(
        r'((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)');
    final ipv6Regex = RegExp(
        r'\[(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))\]');
    final portRegex = RegExp(r':9651$');
    if (!prefixRegex.hasMatch(peer)) return 'peer must start with tcp://';
    final ipPortPart = peer.substring(peer.indexOf('://') + 3);
    if (!ipv4Regex.hasMatch(ipPortPart) && !ipv6Regex.hasMatch(ipPortPart)) {
      return 'peer must contain a valid IPv4 or IPv6 address';
    }
    if (!portRegex.hasMatch(ipPortPart)) return 'peer must end with :9651';
    return null;
  }

  String? validatePeers(List<String> peers) {
    if (peers.isEmpty || (peers.length == 1 && peers[0].isEmpty)) {
      return "peers can't be empty";
    }
    for (final p in peers) {
      final e = validatePeer(p);
      if (e != null) return 'invalid peer:`$p` $e';
    }
    return null;
  }

  bool _socksEnabled = false;

  Future<bool> start(List<String> peers, {bool socksEnabled = false}) async {
    debugPrint('MyceliumService: Starting Mycelium...');
    debugPrint(
        'MyceliumService: Starting with peers: $peers, SOCKS: $socksEnabled');
    debugPrint(
        'MyceliumService: Platform check - isUseDylib(): ${isUseDylib()}');
    _socksEnabled = socksEnabled;
    _status = NodeStatus.connecting;
    _statusController.add(_status);
    final cleaned = preprocessPeers(peers);
    try {
      if (isUseDylib()) {
        final key = await _loadOrGeneratePrivKey();
        final result = await myFFStartMycelium(cleaned, key);
        if (!result) {
          debugPrint('MyceliumService: Failed to start Mycelium');
          _status = NodeStatus.failed;
          _statusController.add(_status);
          return false;
        }
      } else {
        final key = await _loadOrGeneratePrivKey();
        final result = await _platform.invokeMethod<bool>('startVpn', {
          'peers': cleaned,
          'secretKey': key,
          'socksEnabled': socksEnabled,
        });
        debugPrint('MyceliumService: startVpn result: $result');
        if (result != true) {
          debugPrint('MyceliumService: Platform channel returned false');
          _status = NodeStatus.failed;
          _statusController.add(_status);
          return false;
        }
      }
      _status = NodeStatus.connected;
      _statusController.add(_status);
      debugPrint('MyceliumService: Mycelium started successfully');
      return true;
    } catch (e) {
      debugPrint('MyceliumService: Error starting Mycelium: $e');
      _status = NodeStatus.failed;
      _statusController.add(_status);
      return false;
    }
  }

  bool get socksEnabled => _socksEnabled;

  Future<bool> stop() async {
    try {
      if (isUseDylib()) {
        final s = await myFFStopMycelium();
        _status = NodeStatus.disconnected;
        _statusController.add(_status);
        return s;
      } else {
        final res = await _platform.invokeMethod<bool>('stopVpn') ?? false;
        _status = NodeStatus.disconnected;
        _statusController.add(_status);
        return res;
      }
    } catch (_) {
      _status = NodeStatus.failed;
      _statusController.add(_status);
      return false;
    }
  }

  Future<List<PeerStats>> getPeerStatus() async {
    try {
      List<String> peerStatusStrings;
      if (isUseDylib()) {
        // Windows platform - use FFI
        peerStatusStrings = await myFFGetPeerStatus();
      } else {
        // Android/iOS platform - use platform channel
        final result =
            await _platform.invokeMethod<List<dynamic>>('getPeerStatus');
        peerStatusStrings = result?.cast<String>() ?? [];
      }

      // Check for error responses first
      if (peerStatusStrings.isNotEmpty) {
        final firstResponse = peerStatusStrings[0];
        if (firstResponse.startsWith('err_')) {
          // Handle error responses like "err_node_timeout"
          throw Exception('Mycelium service error: $firstResponse');
        }

        // Filter out the first element if it's "ok" (status indicator)
        if (firstResponse == "ok") {
          peerStatusStrings = peerStatusStrings.sublist(1);
        }
      }

      // Parse JSON strings into PeerStats objects
      List<PeerStats> peerStats = [];
      for (String jsonString in peerStatusStrings) {
        try {
          // Skip empty or error strings
          if (jsonString.trim().isEmpty || jsonString.startsWith('err_')) {
            continue;
          }

          final Map<String, dynamic> json = jsonDecode(jsonString);
          peerStats.add(PeerStats.fromJson(json));
        } catch (e) {
          // Skip malformed entries silently to prevent spam
        }
      }

      return peerStats;
    } catch (e) {
      throw Exception("Failed to get peer status: $e");
    }
  }

  /// Get peer status as simple strings (backward compatibility)
  Future<List<String>> getPeerStatusStrings() async {
    try {
      final peerStats = await getPeerStatus();
      return peerStats.map((peer) => peer.toString()).toList();
    } catch (e) {
      throw Exception("Failed to get peer status strings: $e");
    }
  }

  /// Get node status as JSON string
  Future<String?> getStatus() async {
    try {
      if (isUseDylib()) {
        // Use existing peer status method for now
        final peerStats = await getPeerStatus();
        final statusMap = {
          'peers': peerStats.map((p) => p.toJson()).toList(),
          'status': _status.toString(),
        };
        return jsonEncode(statusMap);
      } else {
        // For mobile platforms, don't call getPeerStatus if service is not running
        if (_status != NodeStatus.connected) {
          final statusMap = {
            'peers': <Map<String, dynamic>>[],
            'status': _status.toString(),
          };
          return jsonEncode(statusMap);
        }

        try {
          final peerStats = await getPeerStatus();
          final statusMap = {
            'peers': peerStats.map((p) => p.toJson()).toList(),
            'status': _status.toString(),
          };
          return jsonEncode(statusMap);
        } catch (e) {
          // Silent fallback for mobile when service is unavailable
          final statusMap = {
            'peers': <Map<String, dynamic>>[],
            'status': _status.toString(),
          };
          return jsonEncode(statusMap);
        }
      }
    } catch (e) {
      debugPrint("Failed to get status: $e");
      return null;
    }
  }

  void dispose() {
    _statusController.close();
  }

  Future<List<String>> proxyConnect(String remote) async {
    try {
      if (isUseDylib()) {
        return await myFFProxyConnect(remote);
      } else {
        final result = await _platform.invokeMethod<List<dynamic>>(
          'proxyConnect',
          {'remote': remote},
        );
        return result?.cast<String>() ?? [];
      }
    } catch (e) {
      debugPrint("Failed to proxyConnect: $e");
      return ['Failed to connect proxy'];
    }
  }

  Future<List<String>> proxyDisconnect() async {
    try {
      if (isUseDylib()) {
        return await myFFProxyDisconnect();
      } else {
        final result =
            await _platform.invokeMethod<List<dynamic>>('proxyDisconnect');
        return result?.cast<String>() ?? [];
      }
    } catch (e) {
      debugPrint("Failed to proxyDisconnect: $e");
      return ['Failed to disconnect proxy'];
    }
  }

  Future<List<String>> startProxyProbe() async {
    try {
      if (isUseDylib()) {
        return await myFFStartProxyProbe();
      } else {
        final result =
            await _platform.invokeMethod<List<dynamic>>('startProxyProbe');
        return result?.cast<String>() ?? [];
      }
    } catch (e) {
      debugPrint("Failed to startProxyProbe: $e");
      return ['Failed to start proxy probe'];
    }
  }

  Future<List<String>> stopProxyProbe() async {
    try {
      if (isUseDylib()) {
        return await myFFStopProxyProbe();
      } else {
        final result =
            await _platform.invokeMethod<List<dynamic>>('stopProxyProbe');
        return result?.cast<String>() ?? [];
      }
    } catch (e) {
      debugPrint("Failed to stopProxyProbe: $e");
      return ['Failed to stop proxy probe'];
    }
  }

  Future<List<String>> listProxies() async {
    try {
      if (isUseDylib()) {
        return await myFFListProxies();
      } else {
        final result =
            await _platform.invokeMethod<List<dynamic>>('listProxies');
        return result?.cast<String>() ?? [];
      }
    } catch (e) {
      debugPrint("Failed to listProxies: $e");
      return ['Failed to list proxies'];
    }
  }

  // MARK: - Device-Wide Proxy Methods

  /// Enable device-wide traffic forwarding through SOCKS5 proxy
  Future<bool> enableDeviceWideProxy() async {
    try {
      print("MyceliumService: Enabling device-wide SOCKS5 proxy");

      if (isUseDylib()) {
        // For desktop platforms (Windows/macOS), use platform-specific implementation
        final result =
            await _platform.invokeMethod<bool>('enableDeviceWideProxy');
        return result ?? false;
      } else {
        // For mobile platforms (iOS/Android), use VPN tunnel
        final result =
            await _platform.invokeMethod<bool>('enableDeviceWideProxy');
        return result ?? false;
      }
    } catch (e) {
      print("MyceliumService: Failed to enable device-wide proxy: $e");
      return false;
    }
  }

  /// Disable device-wide traffic forwarding
  Future<bool> disableDeviceWideProxy() async {
    try {
      print("MyceliumService: Disabling device-wide SOCKS5 proxy");

      if (isUseDylib()) {
        // For desktop platforms (Windows/macOS), use platform-specific implementation
        final result =
            await _platform.invokeMethod<bool>('disableDeviceWideProxy');
        return result ?? false;
      } else {
        // For mobile platforms (iOS/Android), use VPN tunnel
        final result =
            await _platform.invokeMethod<bool>('disableDeviceWideProxy');
        return result ?? false;
      }
    } catch (e) {
      print("MyceliumService: Failed to disable device-wide proxy: $e");
      return false;
    }
  }

  /// Get device-wide proxy status
  Future<Map<String, dynamic>> getDeviceWideProxyStatus() async {
    try {
      if (isUseDylib()) {
        // For desktop platforms (Windows/macOS)
        final result = await _platform
            .invokeMethod<Map<dynamic, dynamic>>('getProxyStatus');
        return result?.cast<String, dynamic>() ??
            {'enabled': false, 'error': 'Failed to get proxy status'};
      } else {
        // For mobile platforms (iOS/Android)
        final result = await _platform
            .invokeMethod<Map<dynamic, dynamic>>('getProxyStatus');
        return result?.cast<String, dynamic>() ??
            {'enabled': false, 'error': 'Failed to get proxy status'};
      }
    } catch (e) {
      print("MyceliumService: Failed to get device-wide proxy status: $e");
      return {'enabled': false, 'error': e.toString()};
    }
  }

  /// Start device-wide proxy with automatic proxy discovery and connection
  Future<bool> startDeviceWideProxy({String? specificProxy}) async {
    try {
      print("MyceliumService: Starting device-wide proxy mode");

      // First, ensure Mycelium service is running
      if (_status != NodeStatus.connected) {
        print("MyceliumService: Mycelium service must be connected first");
        return false;
      }

      // Start proxy probe to discover available proxies
      print("MyceliumService: Starting proxy probe...");
      final x = await startProxyProbe();
      print("aaaaaaaaaaa:$x");

      // Wait a bit for proxy discovery
      await Future.delayed(Duration(seconds: 5));

      // Connect to proxy (specific or auto-select best)
      print("MyceliumService: Connecting to SOCKS5 proxy...");
      
      String proxyToConnect;
      if (specificProxy != null && specificProxy.isNotEmpty) {
        proxyToConnect = specificProxy;
      } else {
        // Auto-select best available proxy
        final availableProxies = await listProxies();
        if (availableProxies.isEmpty) {
          print("MyceliumService: No proxies available for connection");
          return false;
        }
        proxyToConnect = availableProxies.first;
        print("MyceliumService: Auto-selected proxy: $proxyToConnect");
      }
      
      final connectResult = await proxyConnect(proxyToConnect);
      print("MyceliumService: Proxy connect result: $connectResult");

      if (connectResult.isNotEmpty && connectResult[0] == "ok") {
        // Enable device-wide traffic forwarding
        print("MyceliumService: Enabling device-wide traffic forwarding...");
        final enableResult = await enableDeviceWideProxy();

        if (enableResult) {
          print("MyceliumService: Device-wide proxy started successfully");
          return true;
        } else {
          print("MyceliumService: Failed to enable device-wide traffic forwarding");
          // Clean up - disconnect proxy
          await proxyDisconnect();
          await stopProxyProbe();
          return false;
        }
      } else {
        print("MyceliumService: Failed to connect to SOCKS5 proxy");
        await stopProxyProbe();
        return false;
      }
    } catch (e) {
      print("MyceliumService: Error starting device-wide proxy: $e");
      return false;
    }
  }

  /// Stop device-wide proxy and restore normal traffic routing
  Future<bool> stopDeviceWideProxy() async {
    try {
      print("MyceliumService: Stopping device-wide proxy mode");

      // Disable device-wide traffic forwarding
      final disableResult = await disableDeviceWideProxy();

      // Disconnect from SOCKS5 proxy
      await proxyDisconnect();

      // Stop proxy probing
      await stopProxyProbe();

      print("MyceliumService: Device-wide proxy stopped");
      return disableResult;
    } catch (e) {
      print("MyceliumService: Error stopping device-wide proxy: $e");
      return false;
    }
  }
}
