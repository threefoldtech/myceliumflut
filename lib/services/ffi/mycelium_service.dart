import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../myceliumflut_ffi_binding.dart';

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
    if (!ipv4Regex.hasMatch(ipPortPart) && !ipv6Regex.hasMatch(ipPortPart))
      return 'peer must contain a valid IPv4 or IPv6 address';
    if (!portRegex.hasMatch(ipPortPart)) return 'peer must end with :9651';
    return null;
  }

  String? validatePeers(List<String> peers) {
    if (peers.isEmpty || (peers.length == 1 && peers[0].isEmpty))
      return "peers can't be empty";
    for (final p in peers) {
      final e = validatePeer(p);
      if (e != null) return 'invalid peer:`$p` $e';
    }
    return null;
  }

  Future<bool> start(List<String> peers) async {
    print('MyceliumService: Starting with peers: $peers');
    _status = NodeStatus.connecting;
    _statusController.add(_status);
    final cleaned = preprocessPeers(peers);
    print('MyceliumService: Cleaned peers: $cleaned');
    final error = validatePeers(cleaned);
    if (error != null) {
      print('MyceliumService: Validation error: $error');
      _status = NodeStatus.failed;
      _statusController.add(_status);
      return false;
    }
    await storePeers(cleaned);
    final key = await _loadOrGeneratePrivKey();
    print('MyceliumService: Loaded key, starting VPN...');
    try {
      if (isUseDylib()) {
        await myFFStartMycelium(cleaned, key);
      } else {
        final result = await _platform.invokeMethod<bool>('startVpn', {
          'peers': cleaned,
          'secretKey': key,
        });
        print('MyceliumService: startVpn result: $result');
      }
      _status = NodeStatus.connected;
      _statusController.add(_status);
      print('MyceliumService: Successfully connected');
      return true;
    } catch (e) {
      print('MyceliumService: Failed to start: $e');
      _status = NodeStatus.failed;
      _statusController.add(_status);
      return false;
    }
  }

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

  Future<List<String>> getPeerStatus() async {
    try {
      List<String> peerStatus;
      if (isUseDylib()) {
        // Windows platform - use FFI
        peerStatus = await myFFGetPeerStatus();
      } else {
        // Android/iOS platform - use platform channel
        final result =
            await _platform.invokeMethod<List<dynamic>>('getPeerStatus');
        peerStatus = result?.cast<String>() ?? [];
      }
      // Filter out the first element if it's "ok" (status indicator)
      if (peerStatus.isNotEmpty && peerStatus[0] == "ok") {
        peerStatus = peerStatus.sublist(1);
      }

      return peerStatus;
    } catch (e) {
      throw Exception("Failed to get peer status: $e");
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
      print("Failed to proxyConnect: $e");
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
      print("Failed to proxyDisconnect: $e");
      return ['Failed to disconnect proxy'];
    }
  }
}
