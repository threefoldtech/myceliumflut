import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/proxy_geolocation_service.dart';
import '../services/geolocation_service.dart';

// Provider for proxy geolocation service
final proxyGeolocationServiceProvider = Provider<ProxyGeolocationService>((ref) {
  return ProxyGeolocationService();
});

// Provider for proxy location cache
final proxyLocationProvider =
    StateNotifierProvider.family<ProxyLocationNotifier, LocationInfo?, String>(
        (ref, proxyAddress) {
  return ProxyLocationNotifier(
      ref.read(proxyGeolocationServiceProvider), proxyAddress);
});

class ProxyLocationNotifier extends StateNotifier<LocationInfo?> {
  final ProxyGeolocationService _proxyGeoService;
  final String _proxyAddress;

  ProxyLocationNotifier(this._proxyGeoService, this._proxyAddress)
      : super(null) {
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final location = await _proxyGeoService.getLocationForProxy(_proxyAddress);

      if (mounted) {
        state = location;
      }
    } catch (e) {
      debugPrint('Error fetching location for proxy $_proxyAddress: $e');
      if (mounted) {
        state = LocationInfo.unknown();
      }
    }
  }

  void refresh() {
    _fetchLocation();
  }
}
