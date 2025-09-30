import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/peer_models.dart';
import 'ffi/mycelium_service.dart';

class PeersService {
  static const _url =
      'https://raw.githubusercontent.com/threefoldtech/zos-config/refs/heads/main/production.json';

  static const List<String> _fallbackPeers = [
    "tcp://188.40.132.242:9651",
    "tcp://136.243.47.186:9651",
    "tcp://185.69.166.7:9651",
    "tcp://185.69.166.8:9651",
    "tcp://65.21.231.58:9651",
    "tcp://65.109.18.113:9651",
    "tcp://209.159.146.190:9651",
    "tcp://5.78.122.16:9651",
    "tcp://5.223.43.251:9651",
    "tcp://142.93.217.194:9651",
  ];

  Future<List<String>> fetchPeers() async {
    try {
      final response = await http.get(Uri.parse(_url));

      if (response.statusCode != 200) {
        debugPrint("failed to load peers from remote. Using fallback peers.");
        return _fallbackPeers;
      }

      final jsonData = jsonDecode(response.body);
      final peers = List<String>.from(jsonData['mycelium']['peers']);
      return peers;
    } catch (e) {
      debugPrint("error fetching peers: $e. Using fallback peers.");
      return _fallbackPeers;
    }
  }

  Future<List<PeerStats>> fetchPeerStats() async {
    try {
      final service = MyceliumService();
      final peerStatusList = await service.getPeerStatus();
      return peerStatusList;
    } catch (e) {
      debugPrint('PeersService: Error getting peer status: $e');
      return [];
    }
  }
}
