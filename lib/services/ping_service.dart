import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PingResult {
  final String host;
  final int? latencyMs;
  final bool success;
  final DateTime timestamp;

  const PingResult({
    required this.host,
    this.latencyMs,
    required this.success,
    required this.timestamp,
  });
}

class PingService {
  static const List<String> _defaultHosts = [
    '8.8.8.8',
    '1.1.1.1',
    'google.com',
  ];

  // Limit concurrent ping operations to prevent socket exhaustion
  static const int _maxConcurrentPings = 10;
  static int _activePings = 0;
  static final List<Completer<void>> _waitingQueue = [];

  Future<void> _acquirePingSlot() async {
    if (_activePings < _maxConcurrentPings) {
      _activePings++;
      return;
    }

    // Wait in queue if max concurrent pings reached
    final completer = Completer<void>();
    _waitingQueue.add(completer);
    await completer.future;
  }

  void _releasePingSlot() {
    _activePings--;
    
    // Process next waiting ping if any
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeAt(0);
      _activePings++;
      completer.complete();
    }
  }

  Future<PingResult> ping(String host) async {
    // Acquire a slot to limit concurrent pings
    await _acquirePingSlot();
    
    Socket? socket;
    try {
      // Extract hostname/IP from peer address if it contains protocol
      String targetHost = host;
      if (host.contains('://')) {
        final uri = Uri.parse(host);
        targetHost = uri.host;
      }

      // Use actual socket connection to test reachability and measure latency
      final stopwatch = Stopwatch()..start();

      socket = await Socket.connect(
        targetHost,
        9651, // Mycelium default port
        timeout: const Duration(seconds: 5),
      );

      stopwatch.stop();
      
      // Properly close and destroy the socket
      await socket.close();
      socket.destroy();

      return PingResult(
        host: host,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Ping error for $host: $e');
      return PingResult(
        host: host,
        latencyMs: null,
        success: false,
        timestamp: DateTime.now(),
      );
    } finally {
      // Ensure socket is destroyed even if an error occurs
      try {
        socket?.destroy();
      } catch (e) {
        // Ignore errors during cleanup
      }
      
      // Release the ping slot for next waiting operation
      _releasePingSlot();
    }
  }

  Future<List<PingResult>> pingMultiple([List<String>? hosts]) async {
    final targetHosts = hosts ?? _defaultHosts;
    final futures = targetHosts.map((host) => ping(host));
    return await Future.wait(futures);
  }

  Future<int?> getAverageLatency([List<String>? hosts]) async {
    final results = await pingMultiple(hosts);
    final successfulPings =
        results.where((r) => r.success && r.latencyMs != null);

    if (successfulPings.isEmpty) return null;

    final totalLatency = successfulPings.fold<int>(
      0,
      (sum, result) => sum + (result.latencyMs ?? 0),
    );

    return (totalLatency / successfulPings.length).round();
  }
}

// Provider for ping service
final pingServiceProvider = Provider<PingService>((ref) {
  return PingService();
});

// Provider for current latency
final latencyProvider = StateNotifierProvider<LatencyNotifier, int?>((ref) {
  return LatencyNotifier(ref.read(pingServiceProvider));
});

class LatencyNotifier extends StateNotifier<int?> {
  final PingService _pingService;
  Timer? _timer;

  LatencyNotifier(this._pingService) : super(null) {
    _startPeriodicPing();
  }

  void _startPeriodicPing() {
    // Initial ping
    _updateLatency();

    // Ping every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateLatency();
    });
  }

  Future<void> _updateLatency() async {
    try {
      final latency = await _pingService.getAverageLatency();
      state = latency;
    } catch (e) {
      debugPrint('LatencyNotifier: Error updating latency: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
