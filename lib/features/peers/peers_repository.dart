import 'package:shared_preferences/shared_preferences.dart';

class PeersRepository {
  static const _peersKey = 'user_peers';

  Future<List<String>> loadPeers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_peersKey) ?? [];
  }

  Future<void> savePeers(List<String> peers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_peersKey, peers);
  }

  Future<void> addPeer(String peer) async {
    final peers = await loadPeers();
    if (!peers.contains(peer)) {
      peers.add(peer);
      await savePeers(peers);
    }
  }

  Future<void> removePeer(String peer) async {
    final peers = await loadPeers();
    peers.remove(peer);
    await savePeers(peers);
  }
}
