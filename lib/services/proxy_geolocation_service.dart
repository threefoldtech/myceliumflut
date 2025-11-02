import 'dart:convert';
import 'dart:io';
import 'package:socks5_proxy/socks_client.dart';
import 'geolocation_service.dart';

class ProxyGeolocationService {
  static final Map<String, LocationInfo> _cache = {};

  /// Get location for a proxy by making an HTTP request through the SOCKS5 proxy
  /// to geoip.grid.tf which will detect the proxy's public IP and return geolocation
  Future<LocationInfo> getLocationForProxy(String proxyAddress) async {
    // Check cache first
    if (_cache.containsKey(proxyAddress)) {
      return _cache[proxyAddress]!;
    }

    try {
      // Parse proxy address: [IPv6]:port or IPv4:port
      final (host, port) = _parseProxyAddress(proxyAddress);
      
      // Create proxy settings
      final proxies = [
        ProxySettings(InternetAddress(host), port),
      ];

      // Create HttpClient and assign SOCKS5 proxy
      final client = HttpClient();
      SocksTCPClient.assignToHttpClient(client, proxies);

      // Set timeout
      client.connectionTimeout = const Duration(seconds: 10);

      // Make request to geoip.grid.tf through the proxy
      // It will automatically detect the proxy's public IP and return geolocation
      final request = await client.getUrl(Uri.parse('https://geoip.grid.tf'));
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      // Read response body
      final responseBody = await utf8.decodeStream(response);
      
      // Close client
      client.close();

      if (responseBody.trim().isEmpty) {
        throw Exception('Empty response from geoip.grid.tf');
      }

      // Parse JSON response
      final data = jsonDecode(responseBody);
      final location = LocationInfo.fromGridTFJson(data);
      
      _cache[proxyAddress] = location;
      return location;
    } catch (e) {
      print('ProxyGeolocationService: Error getting location for $proxyAddress: $e');
      // Cache unknown location to avoid repeated failed attempts
      final unknownLocation = LocationInfo.unknown();
      _cache[proxyAddress] = unknownLocation;
      return unknownLocation;
    }
  }

  /// Parse proxy address into host and port
  /// Supports: [IPv6]:port and IPv4:port
  (String, int) _parseProxyAddress(String address) {
    // Remove brackets and split
    if (address.startsWith('[')) {
      // IPv6 format: [xxxx:xxxx:...]:port
      final closeBracket = address.indexOf(']');
      if (closeBracket == -1) {
        throw FormatException('Invalid IPv6 proxy address: $address');
      }
      final host = address.substring(1, closeBracket);
      final portStr = address.substring(closeBracket + 2); // Skip ']:' 
      final port = int.parse(portStr);
      return (host, port);
    } else {
      // IPv4 format: x.x.x.x:port
      final parts = address.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid IPv4 proxy address: $address');
      }
      final host = parts[0];
      final port = int.parse(parts[1]);
      return (host, port);
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
