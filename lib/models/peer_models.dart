import '../services/geolocation_service.dart';

/// Enum representing the type of peer connection
enum PeerType {
  static,
  discovered,
  unknown;

  static PeerType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'static':
        return PeerType.static;
      case 'discovered':
        return PeerType.discovered;
      default:
        return PeerType.unknown;
    }
  }

  @override
  String toString() {
    switch (this) {
      case PeerType.static:
        return 'Static';
      case PeerType.discovered:
        return 'Discovered';
      case PeerType.unknown:
        return 'Unknown';
    }
  }
}

/// Enum representing the connection state of a peer
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  failed,
  unknown;

  static ConnectionState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'alive':
        return ConnectionState.connected;
      case 'connecting':
        return ConnectionState.connecting;
      case 'dead':
        return ConnectionState.disconnected;
      case 'connected':
        return ConnectionState.connected;
      case 'disconnected':
        return ConnectionState.disconnected;
      case 'failed':
        return ConnectionState.failed;
      default:
        return ConnectionState.unknown;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.connecting:
        return 'Connecting';
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.failed:
        return 'Failed';
      case ConnectionState.unknown:
        return 'Unknown';
    }
  }
}

/// Model representing detailed peer statistics and information
class PeerStats {
  /// The protocol used by this peer (e.g., "tcp", "quic")
  final String protocol;
  
  /// The socket address of the peer
  final String address;
  
  /// The type of peer (static, discovered, etc.)
  final PeerType peerType;
  
  /// Current connection state
  final ConnectionState connectionState;
  
  /// Total bytes received from this peer
  final int rxBytes;
  
  /// Total bytes transmitted to this peer
  final int txBytes;
  
  /// Time since this peer was discovered (in seconds)
  final int discoveredSeconds;
  
  /// Time since last successful connection (in seconds), null if never connected
  final int? lastConnectedSeconds;
  
  /// Location information for this peer (country, city, etc.)
  final LocationInfo? locationInfo;

  const PeerStats({
    required this.protocol,
    required this.address,
    required this.peerType,
    required this.connectionState,
    required this.rxBytes,
    required this.txBytes,
    required this.discoveredSeconds,
    this.lastConnectedSeconds,
    this.locationInfo,
  });

  /// Create PeerStats from a JSON map
  factory PeerStats.fromJson(Map<String, dynamic> json) {
    return PeerStats(
      protocol: json['protocol'] as String,
      address: json['address'] as String,
      peerType: PeerType.fromString(json['peerType'] as String),
      connectionState: ConnectionState.fromString(json['connectionState'] as String),
      rxBytes: json['rxBytes'] as int,
      txBytes: json['txBytes'] as int,
      discoveredSeconds: json['discoveredSeconds'] as int,
      lastConnectedSeconds: json['lastConnectedSeconds'] as int?,
    );
  }

  /// Convert PeerStats to JSON map
  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'address': address,
      'peerType': peerType.toString(),
      'connectionState': connectionState.toString(),
      'rxBytes': rxBytes,
      'txBytes': txBytes,
      'discoveredSeconds': discoveredSeconds,
      'lastConnectedSeconds': lastConnectedSeconds,
      // Note: locationInfo is not serialized as it's fetched separately
    };
  }

  /// Format bytes in a human-readable way
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  /// Format seconds in a human-readable duration
  static String formatDuration(int totalSeconds) {
    final seconds = totalSeconds % 60;
    final minutes = (totalSeconds ~/ 60) % 60;
    final hours = (totalSeconds ~/ 3600) % 24;
    final days = totalSeconds ~/ 86400;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get formatted receive bytes
  String get formattedRxBytes => formatBytes(rxBytes);

  /// Get formatted transmit bytes
  String get formattedTxBytes => formatBytes(txBytes);

  /// Get formatted discovered duration
  String get formattedDiscovered => formatDuration(discoveredSeconds);

  /// Get formatted last connected duration
  String get formattedLastConnected {
    if (lastConnectedSeconds == null) return 'Never connected';
    return formatDuration(lastConnectedSeconds!);
  }

  /// Get the full endpoint string (protocol + address)
  String get endpoint => '$protocol://$address';

  @override
  String toString() {
    return 'PeerStats(protocol: $protocol, address: $address, type: $peerType, '
           'state: $connectionState, rx: $formattedRxBytes, tx: $formattedTxBytes, '
           'discovered: $formattedDiscovered, lastConnected: $formattedLastConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PeerStats &&
        other.protocol == protocol &&
        other.address == address &&
        other.peerType == peerType &&
        other.connectionState == connectionState &&
        other.rxBytes == rxBytes &&
        other.txBytes == txBytes &&
        other.discoveredSeconds == discoveredSeconds &&
        other.lastConnectedSeconds == lastConnectedSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      protocol,
      address,
      peerType,
      connectionState,
      rxBytes,
      txBytes,
      discoveredSeconds,
      lastConnectedSeconds,
    );
  }
}
