import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mycelium_providers.dart';
import '../services/ffi/mycelium_service.dart';

class TrafficStats {
  final int totalUploadBytes;
  final int totalDownloadBytes;
  final int peakUploadBytesPerSec;
  final int peakDownloadBytesPerSec;
  final DateTime lastUpdated;

  const TrafficStats({
    required this.totalUploadBytes,
    required this.totalDownloadBytes,
    required this.peakUploadBytesPerSec,
    required this.peakDownloadBytesPerSec,
    required this.lastUpdated,
  });

  String get totalUploadFormatted => _formatBytes(totalUploadBytes);
  String get totalDownloadFormatted => _formatBytes(totalDownloadBytes);
  String get peakUploadFormatted => '${_formatBytes(peakUploadBytesPerSec)}/s';
  String get peakDownloadFormatted =>
      '${_formatBytes(peakDownloadBytesPerSec)}/s';

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Provider for dynamic traffic statistics
final dynamicTrafficProvider =
    StateNotifierProvider<DynamicTrafficNotifier, TrafficStats>((ref) {
  return DynamicTrafficNotifier(ref);
});

class DynamicTrafficNotifier extends StateNotifier<TrafficStats> {
  final Ref _ref;
  Timer? _timer;
  int _previousTotalRx = 0;
  int _previousTotalTx = 0;
  int _maxRxRate = 0;
  int _maxTxRate = 0;

  DynamicTrafficNotifier(this._ref)
      : super(TrafficStats(
          totalUploadBytes: 0,
          totalDownloadBytes: 0,
          peakUploadBytesPerSec: 0,
          peakDownloadBytesPerSec: 0,
          lastUpdated: DateTime.now(),
        )) {
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    // Update every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateTrafficStats();
    });
  }

  Future<void> _updateTrafficStats() async {
    try {
      // Check if Mycelium is connected before fetching stats
      final nodeStatusAsync = _ref.read(nodeStatusProvider);
      final nodeStatus = nodeStatusAsync.asData?.value;

      if (nodeStatus != NodeStatus.connected) return;

      // Use MyceliumService directly to get peer stats like the home screen does
      final myceliumService = _ref.read(myceliumServiceProvider);
      final peerStats = await myceliumService.getPeerStatus();

      if (peerStats.isEmpty) return;

      int totalRx = 0;
      int totalTx = 0;

      // Sum up traffic from all peer stats
      for (final peer in peerStats) {
        totalRx += peer.rxBytes;
        totalTx += peer.txBytes;
      }

      // Calculate rates (bytes per second over 5-second interval)
      final rxRate =
          _previousTotalRx > 0 ? ((totalRx - _previousTotalRx) / 5).round() : 0;
      final txRate =
          _previousTotalTx > 0 ? ((totalTx - _previousTotalTx) / 5).round() : 0;

      // Update peak rates
      if (rxRate > _maxRxRate) _maxRxRate = rxRate;
      if (txRate > _maxTxRate) _maxTxRate = txRate;

      // Accumulate total traffic instead of replacing it
      final currentState = state;
      final newTotalUpload =
          currentState.totalUploadBytes + (totalTx - _previousTotalTx).abs();
      final newTotalDownload =
          currentState.totalDownloadBytes + (totalRx - _previousTotalRx).abs();

      // Update state with accumulated totals
      state = TrafficStats(
        totalUploadBytes: _previousTotalTx == 0 ? totalTx : newTotalUpload,
        totalDownloadBytes: _previousTotalRx == 0 ? totalRx : newTotalDownload,
        peakUploadBytesPerSec: _maxTxRate,
        peakDownloadBytesPerSec: _maxRxRate,
        lastUpdated: DateTime.now(),
      );

      _previousTotalRx = totalRx;
      _previousTotalTx = totalTx;
    } catch (e) {
      debugPrint('DynamicTrafficNotifier: Error updating traffic stats: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
