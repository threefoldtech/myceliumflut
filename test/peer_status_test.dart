import 'package:flutter_test/flutter_test.dart';
import 'package:myceliumflut/models/peer_models.dart';
import 'dart:convert';

void main() {
  group('PeerStats', () {
    test('should parse JSON correctly', () {
      final jsonString = '''
      {
        "protocol": "tcp",
        "address": "185.69.166.7:9651",
        "peerType": "Static",
        "connectionState": "Connected",
        "rxBytes": 1048576,
        "txBytes": 2097152,
        "discoveredSeconds": 3600,
        "lastConnectedSeconds": 1800
      }
      ''';

      final json = jsonDecode(jsonString);
      final peerStats = PeerStats.fromJson(json);

      expect(peerStats.protocol, equals('tcp'));
      expect(peerStats.address, equals('185.69.166.7:9651'));
      expect(peerStats.peerType, equals(PeerType.static));
      expect(peerStats.connectionState, equals(ConnectionState.connected));
      expect(peerStats.rxBytes, equals(1048576));
      expect(peerStats.txBytes, equals(2097152));
      expect(peerStats.discoveredSeconds, equals(3600));
      expect(peerStats.lastConnectedSeconds, equals(1800));
    });

    test('should format bytes correctly', () {
      expect(PeerStats.formatBytes(1024), equals('1.00KB'));
      expect(PeerStats.formatBytes(1048576), equals('1.00MB'));
      expect(PeerStats.formatBytes(1073741824), equals('1.00GB'));
      expect(PeerStats.formatBytes(512), equals('512B'));
    });

    test('should format duration correctly', () {
      expect(PeerStats.formatDuration(30), equals('30s'));
      expect(PeerStats.formatDuration(90), equals('1m 30s'));
      expect(PeerStats.formatDuration(3661), equals('1h 1m 1s'));
      expect(PeerStats.formatDuration(90061), equals('1d 1h 1m 1s'));
    });

    test('should handle null lastConnectedSeconds', () {
      final jsonString = '''
      {
        "protocol": "tcp",
        "address": "185.69.166.7:9651",
        "peerType": "Discovered",
        "connectionState": "Disconnected",
        "rxBytes": 0,
        "txBytes": 0,
        "discoveredSeconds": 60,
        "lastConnectedSeconds": null
      }
      ''';

      final json = jsonDecode(jsonString);
      final peerStats = PeerStats.fromJson(json);

      expect(peerStats.lastConnectedSeconds, isNull);
      expect(peerStats.formattedLastConnected, equals('Never connected'));
    });

    test('should create endpoint correctly', () {
      final peerStats = PeerStats(
        protocol: 'tcp',
        address: '185.69.166.7:9651',
        peerType: PeerType.static,
        connectionState: ConnectionState.connected,
        rxBytes: 1024,
        txBytes: 2048,
        discoveredSeconds: 3600,
        lastConnectedSeconds: 1800,
      );

      expect(peerStats.endpoint, equals('tcp://185.69.166.7:9651'));
    });
  });

  group('PeerType', () {
    test('should parse from string correctly', () {
      expect(PeerType.fromString('static'), equals(PeerType.static));
      expect(PeerType.fromString('Static'), equals(PeerType.static));
      expect(PeerType.fromString('STATIC'), equals(PeerType.static));
      expect(PeerType.fromString('discovered'), equals(PeerType.discovered));
      expect(PeerType.fromString('unknown_type'), equals(PeerType.unknown));
    });

    test('should convert to string correctly', () {
      expect(PeerType.static.toString(), equals('Static'));
      expect(PeerType.discovered.toString(), equals('Discovered'));
      expect(PeerType.unknown.toString(), equals('Unknown'));
    });
  });

  group('ConnectionState', () {
    test('should parse from string correctly', () {
      expect(ConnectionState.fromString('connected'), equals(ConnectionState.connected));
      expect(ConnectionState.fromString('Connected'), equals(ConnectionState.connected));
      expect(ConnectionState.fromString('CONNECTED'), equals(ConnectionState.connected));
      expect(ConnectionState.fromString('connecting'), equals(ConnectionState.connecting));
      expect(ConnectionState.fromString('disconnected'), equals(ConnectionState.disconnected));
      expect(ConnectionState.fromString('failed'), equals(ConnectionState.failed));
      expect(ConnectionState.fromString('unknown_state'), equals(ConnectionState.unknown));
    });

    test('should convert to string correctly', () {
      expect(ConnectionState.connected.toString(), equals('Connected'));
      expect(ConnectionState.connecting.toString(), equals('Connecting'));
      expect(ConnectionState.disconnected.toString(), equals('Disconnected'));
      expect(ConnectionState.failed.toString(), equals('Failed'));
      expect(ConnectionState.unknown.toString(), equals('Unknown'));
    });
  });
}
