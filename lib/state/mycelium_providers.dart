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

final peersFutureProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(myceliumServiceProvider);
  return service.loadPeers();
});



