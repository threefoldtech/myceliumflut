import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/widgets/traffic_chart.dart';
import '../models/peer_models.dart';

// Provider for historical traffic data
final trafficHistoryProvider = StateNotifierProvider<TrafficHistoryNotifier, List<TrafficDataPoint>>((ref) {
  return TrafficHistoryNotifier();
});

class TrafficHistoryNotifier extends StateNotifier<List<TrafficDataPoint>> {
  Timer? _timer;
  
  TrafficHistoryNotifier() : super([]) {
    // Initialize with minimal data immediately
    _initializeMinimalData();
    // Schedule full initialization after UI is ready
    Future.microtask(() => _initializeDataAsync());
  }

  void _initializeMinimalData() {
    // Add just a few data points to prevent empty chart errors
    final now = DateTime.now();
    state = [
      TrafficDataPoint(upload: 0, download: 0, timestamp: now.subtract(const Duration(hours: 2))),
      TrafficDataPoint(upload: 0, download: 0, timestamp: now.subtract(const Duration(hours: 1))),
      TrafficDataPoint(upload: 0, download: 0, timestamp: now),
    ];
  }

  void _initializeDataAsync() async {
    try {
      // Small delay to ensure UI is rendered first
      await Future.delayed(const Duration(milliseconds: 500));
      _initializeData();
      _startPeriodicUpdates();
    } catch (e) {
      print('TrafficHistoryNotifier: Error initializing data: $e');
      // Keep minimal data on error
    }
  }

  void _initializeData() {
    // Initialize with 24 hours of sample data (one point per hour)
    final now = DateTime.now();
    final List<TrafficDataPoint> initialData = [];
    
    for (int i = 23; i >= 0; i--) {
      final timestamp = now.subtract(Duration(hours: i));
      // Generate some sample data with realistic patterns
      final baseUpload = _generateRealisticTraffic(i, isUpload: true);
      final baseDownload = _generateRealisticTraffic(i, isUpload: false);
      
      initialData.add(TrafficDataPoint(
        upload: baseUpload,
        download: baseDownload,
        timestamp: timestamp,
      ));
    }
    
    state = initialData;
  }

  double _generateRealisticTraffic(int hourAgo, {required bool isUpload}) {
    final random = Random(hourAgo + (isUpload ? 1000 : 0));
    
    // Create realistic daily patterns
    final hour = (24 - hourAgo) % 24;
    double baseActivity = 1.0;
    
    // Higher activity during day hours (8-22), lower at night
    if (hour >= 8 && hour <= 22) {
      baseActivity = 0.5 + 0.5 * sin((hour - 8) * pi / 14);
    } else {
      baseActivity = 0.1 + 0.2 * random.nextDouble();
    }
    
    // Upload is typically lower than download
    final multiplier = isUpload ? 0.3 : 1.0;
    
    // Generate bytes (in MB range for visibility)
    final baseMB = baseActivity * multiplier * (2 + 6 * random.nextDouble());
    return baseMB * 1024 * 1024; // Convert to bytes
  }

  void _startPeriodicUpdates() {
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateWithCurrentTraffic();
    });
  }

  void _updateWithCurrentTraffic() {
    // In a real implementation, this would get actual traffic data
    // For now, we'll simulate realistic updates
    final now = DateTime.now();
    final random = Random();
    
    // Remove oldest data point and add new one
    final newData = List<TrafficDataPoint>.from(state);
    if (newData.length >= 24) {
      newData.removeAt(0);
    }
    
    // Generate new data point with some randomness
    final upload = 0.5 + 2.0 * random.nextDouble(); // 0.5-2.5 MB
    final download = 1.0 + 4.0 * random.nextDouble(); // 1-5 MB
    
    newData.add(TrafficDataPoint(
      upload: upload * 1024 * 1024, // Convert to bytes
      download: download * 1024 * 1024,
      timestamp: now,
    ));
    
    state = newData;
  }

  void updateWithPeerData(List<PeerStats> peerStats) {
    // This method can be called to update with real peer traffic data
    if (peerStats.isEmpty) return;
    
    final now = DateTime.now();
    double totalUpload = 0;
    double totalDownload = 0;
    
    for (final peer in peerStats) {
      totalUpload += peer.txBytes.toDouble();
      totalDownload += peer.rxBytes.toDouble();
    }
    
    // Update the most recent data point or add a new one
    final newData = List<TrafficDataPoint>.from(state);
    if (newData.isNotEmpty) {
      final lastPoint = newData.last;
      final timeDiff = now.difference(lastPoint.timestamp);
      
      if (timeDiff.inMinutes < 30) {
        // Update the last point if it's recent
        newData[newData.length - 1] = TrafficDataPoint(
          upload: totalUpload,
          download: totalDownload,
          timestamp: now,
        );
      } else {
        // Add new point
        if (newData.length >= 24) {
          newData.removeAt(0);
        }
        newData.add(TrafficDataPoint(
          upload: totalUpload,
          download: totalDownload,
          timestamp: now,
        ));
      }
    }
    
    state = newData;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
