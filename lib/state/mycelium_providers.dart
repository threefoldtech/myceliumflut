import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ffi/mycelium_service.dart';

final myceliumServiceProvider = Provider<MyceliumService>((ref) {
  final service = MyceliumService();
  ref.onDispose(service.dispose);
  return service;
});

final nodeStatusProvider = StreamProvider<NodeStatus>((ref) {
  return ref.watch(myceliumServiceProvider).statusStream;
});

class PeersNotifier extends StateNotifier<List<String>> {
  final MyceliumService _service;
  Timer? _timer;
  bool _isActive = false;
  bool _isDisposed = false;

  PeersNotifier(this._service) : super([]) {
    _startPeerStatusUpdates();
  }

  void _startPeerStatusUpdates() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isActive) {
        timer.cancel();
        return;
      }
      _updatePeerStatus();
    });
  }

  Future<void> _updatePeerStatus() async {
    if (_isDisposed || !_isActive) return;
    try {
      final peerStatus = await _service.getPeerStatus();
      print('Updated peer status: $peerStatus');
      if (!_isDisposed && _isActive) {
        state = peerStatus;
      }
    } catch (e) {
      print('Failed to update peer status: $e');
      // Handle error, perhaps log or set to empty
      if (!_isDisposed && _isActive) {
        state = [];
      }
    }
  }

  void startUpdates() {
    _isActive = true;
    if (_timer == null || !_timer!.isActive) {
      _startPeerStatusUpdates();
    }
  }

  void stopUpdates() {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopUpdates();
    super.dispose();
  }
}

final peersProvider = StateNotifierProvider<PeersNotifier, List<String>>((ref) {
  final service = ref.watch(myceliumServiceProvider);
  final notifier = PeersNotifier(service);
  ref.onDispose(notifier.dispose);
  return notifier;
});



