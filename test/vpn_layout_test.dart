import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myceliumflut/features/vpn/widgets/automatic_proxy_widget.dart';
import 'package:myceliumflut/features/vpn/widgets/manual_proxy_widget.dart';
import 'package:myceliumflut/state/vpn_provider.dart';
import 'package:myceliumflut/services/ffi/mycelium_service.dart';

void main() {
  group('VPN Layout Tests', () {
    late VpnProvider vpnProvider;
    late MyceliumService mockService;

    setUp(() {
      mockService = MyceliumService();
      vpnProvider = VpnProvider(mockService);
    });

    testWidgets('Automatic proxy widget renders without layout errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: AutomaticProxyWidget(vpnProvider: vpnProvider),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Automatic Proxy Discovery'), findsOneWidget);
    });

    testWidgets('Manual proxy widget renders without layout errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ManualProxyWidget(vpnProvider: vpnProvider),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Manual Proxy Configuration'), findsOneWidget);
    });
  });
}
