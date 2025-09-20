import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/geolocation_service.dart';

// Provider for geolocation service
final geolocationServiceProvider = Provider<GeolocationService>((ref) {
  return GeolocationService();
});

// Provider for peer location cache
final peerLocationProvider = StateNotifierProvider.family<PeerLocationNotifier, LocationInfo?, String>((ref, peerAddress) {
  return PeerLocationNotifier(ref.read(geolocationServiceProvider), peerAddress);
});

class PeerLocationNotifier extends StateNotifier<LocationInfo?> {
  final GeolocationService _geolocationService;
  final String _peerAddress;

  PeerLocationNotifier(this._geolocationService, this._peerAddress) : super(null) {
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      // Extract IP from address (remove tcp:// prefix if present)
      String cleanIP = _peerAddress.replaceAll('tcp://', '');
      if (cleanIP.contains(':')) {
        cleanIP = cleanIP.split(':')[0]; // Remove port if present
      }
      
      print('Fetching location for peer: $_peerAddress -> cleaned IP: $cleanIP');
      final location = await _geolocationService.getLocationForIP(cleanIP);
      print('Location result for $cleanIP: ${location.country}, ${location.city}');
      
      if (mounted) {
        state = location;
      }
    } catch (e) {
      print('Error fetching location for $_peerAddress: $e');
      if (mounted) {
        state = LocationInfo.unknown();
      }
    }
  }

  void refresh() {
    _fetchLocation();
  }
}
