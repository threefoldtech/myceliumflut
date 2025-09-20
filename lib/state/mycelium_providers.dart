import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myceliumflut/features/peers/peers_repository.dart';
import '../services/ffi/mycelium_service.dart';
import '../services/peers_service.dart';

final myceliumServiceProvider = Provider<MyceliumService>((ref) {
  final service = MyceliumService();
  ref.onDispose(service.dispose);
  return service;
});

final peersServiceProvider = Provider<PeersService>((ref) => PeersService());

final nodeStatusProvider = StreamProvider<NodeStatus>((ref) {
  return ref.watch(myceliumServiceProvider).statusStream;
});

class UptimeNotifier extends StateNotifier<DateTime?> {
  Timer? _timer;
  
  UptimeNotifier() : super(null);

  void startUptime() {
    if (state == null) {
      state = DateTime.now();
    }
  }

  void stopUptime() {
    state = null;
  }

  Duration? get uptime {
    if (state == null) return null;
    return DateTime.now().difference(state!);
  }

  String get formattedUptime {
    final duration = uptime;
    if (duration == null) return '0s';
    
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final uptimeProvider = StateNotifierProvider<UptimeNotifier, DateTime?>((ref) {
  final notifier = UptimeNotifier();
  
  // Listen to node status changes
  ref.listen(nodeStatusProvider, (previous, next) {
    next.whenData((status) {
      if (status == NodeStatus.connected) {
        notifier.startUptime();
      } else {
        notifier.stopUptime();
      }
    });
  });
  
  return notifier;
});

class PeersNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final PeersService _service;
  final PeersRepository _repo;

  List<String> _userPeers = [];

  List<String> get userPeers => _userPeers;

  PeersNotifier(this._service, this._repo) : super(const AsyncLoading()) {
    _fetchPeers();
  }

  Future<void> _fetchPeers() async {
    try {
      _userPeers = await _repo.loadPeers();
      final fetchedPeers = await _service.fetchPeers();

      final allPeers = {...userPeers, ...fetchedPeers}.toList();
      state = AsyncData(allPeers);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> addPeer(String peer) async {
    await _repo.addPeer(peer);
    _userPeers.add(peer);
    final current = state.value ?? [];
    if (!current.contains(peer)) {
      state = AsyncData([...current, peer]);
    }
  }

  Future<void> removePeer(String peer) async {
    await _repo.removePeer(peer);
    _userPeers.remove(peer); 
    final current = state.value ?? [];
    state = AsyncData(current.where((p) => p != peer).toList());
  }
}

final peersRepositoryProvider =
    Provider<PeersRepository>((ref) => PeersRepository());

final peersProvider =
    StateNotifierProvider<PeersNotifier, AsyncValue<List<String>>>((ref) {
  final service = ref.watch(peersServiceProvider);
  final repo = ref.watch(peersRepositoryProvider);

  return PeersNotifier(service, repo);
});
