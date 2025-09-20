import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationInfo {
  final String country;
  final String countryCode;
  final String city;
  final String region;
  final double? latitude;
  final double? longitude;

  const LocationInfo({
    required this.country,
    required this.countryCode,
    required this.city,
    required this.region,
    this.latitude,
    this.longitude,
  });

  factory LocationInfo.fromGridTFJson(Map<String, dynamic> json) {
    return LocationInfo(
      country: json['country_name'] ?? 'Unknown',
      countryCode: json['country_code'] ?? 'XX',
      city: json['city_name'] ?? '',
      region: json['subdivision'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  factory LocationInfo.unknown() {
    return const LocationInfo(
      country: 'Unknown',
      countryCode: 'XX',
      city: '',
      region: '',
    );
  }
}

class GeolocationService {
  static const String _apiUrl = 'https://geoip.grid.tf';
  static final Map<String, LocationInfo> _cache = {};

  Future<LocationInfo> getLocationForIP(String ip) async {
    // Check cache first
    if (_cache.containsKey(ip)) {
      print('Cache hit for $ip: ${_cache[ip]!.country}');
      return _cache[ip]!;
    }

    try {
      // Extract IP from peer address if it contains protocol
      String targetIP = ip;
      if (ip.contains('://')) {
        final uri = Uri.parse(ip);
        targetIP = uri.host;
      } else if (ip.contains(':')) {
        // Format: ip:port
        targetIP = ip.split(':')[0];
      }

      print('Making API call to: $_apiUrl with X-Real-IP: $targetIP');
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/json',
          'X-Real-IP': targetIP,
        },
      ).timeout(const Duration(seconds: 10));

      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final locationInfo = LocationInfo.fromGridTFJson(data);
        print('Parsed location: ${locationInfo.country}, ${locationInfo.city}');
        _cache[ip] = locationInfo;
        return locationInfo;
      } else {
        print('API returned non-200 status: ${response.statusCode}');
      }
    } catch (e) {
      print('Geolocation error for $ip: $e');
    }

    // Return unknown location and cache it
    final unknownLocation = LocationInfo.unknown();
    _cache[ip] = unknownLocation;
    print('Returning unknown location for $ip');
    return unknownLocation;
  }

  String getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    
    final codePoints = countryCode.toUpperCase().codeUnits;
    final flag = String.fromCharCode(0x1F1E6 + codePoints[0] - 0x41) +
                 String.fromCharCode(0x1F1E6 + codePoints[1] - 0x41);
    return flag;
  }

  void clearCache() {
    _cache.clear();
  }
}
