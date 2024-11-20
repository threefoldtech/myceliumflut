import 'package:flutter_test/flutter_test.dart';
import 'package:myceliumflut/main.dart'; // Adjust the import based on your project structure

void main() {
  group('preprocessPeers', () {
    test('removes empty elements', () {
      final peers = [
        'tcp://192.168.0.1:9651',
        '',
        'tcp://192.168.0.2:9651',
        ''
      ];
      final result = preprocessPeers(peers);
      expect(result, ['tcp://192.168.0.1:9651', 'tcp://192.168.0.2:9651']);
    });

    test('removes duplicated elements', () {
      final peers = [
        'tcp://192.168.0.1:9651',
        'tcp://192.168.0.2:9651',
        'tcp://192.168.0.1:9651'
      ];
      final result = preprocessPeers(peers);
      expect(result, ['tcp://192.168.0.1:9651', 'tcp://192.168.0.2:9651']);
    });

    test('removes empty and duplicated elements', () {
      final peers = [
        'tcp://192.168.0.1:9651',
        '',
        'tcp://192.168.0.2:9651',
        'tcp://192.168.0.1:9651',
        ''
      ];
      final result = preprocessPeers(peers);
      expect(result, ['tcp://192.168.0.1:9651', 'tcp://192.168.0.2:9651']);
    });

    test('returns empty list if all elements are empty', () {
      final peers = ['', '', ''];
      final result = preprocessPeers(peers);
      expect(result, []);
    });

    test('returns the same list if no empty or duplicated elements', () {
      final peers = [
        'tcp://192.168.0.1:9651',
        'tcp://192.168.0.2:9651',
        'peer3:9651'
      ];
      final result = preprocessPeers(peers);
      expect(result,
          ['tcp://192.168.0.1:9651', 'tcp://192.168.0.2:9651', 'peer3:9651']);
    });
  });

  group('isValidPeers', () {
    test('returns error if peers list is empty', () {
      final peers = <String>[];
      final result = isValidPeers(peers);
      expect(result, "peers can't be empty");
    });

    test('returns error if peers list contains only an empty string', () {
      final peers = [''];
      final result = isValidPeers(peers);
      expect(result, "peers can't be empty");
    });

    test('returns error for invalid peer without tcp prefix', () {
      final peers = ['tcp://192.168.0.1:9651', '192.168.0.3:9651'];
      final result = isValidPeers(peers);
      expect(result,
          'invalid peer:`192.168.0.3:9651` peer must start with tcp://');
    });

    test('returns error for invalid peer without port', () {
      final peers = ['tcp://192.168.0.1:9651', 'tcp://192.168.0.3'];
      final result = isValidPeers(peers);
      expect(
          result, 'invalid peer:`tcp://192.168.0.3` peer must end with :9651');
    });

    test('returns null for valid peers', () {
      final peers = ['tcp://192.168.0.1:9651', 'tcp://192.168.0.2:9651'];
      final result = isValidPeers(peers);
      expect(result, null);
    });
  });
}
