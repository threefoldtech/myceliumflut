import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tun_flutter/tun_flutter.dart';

import 'package:myceliumflut/src/rust/api/simple.dart';
import 'package:myceliumflut/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel("tech.threefold.mycelium/tun");
  String _platformVersion = 'Unknown';
  bool _vpnStarted = false;
  int _tunFd = 0;
  String _dummyBattLevel = ''; // dummy battery level
  String _nodeAddr = '';
  var tf = TunFlutter();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    bool vpnStarted = false;
    int tunFd = -1;
    String dummyBattLevel = '';

    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await tf.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    dummyBattLevel = await getBatteryLevel(platform);

    var privKey = await loadPrivKey();
    var nodeAddr = addressFromSecretKey(data: privKey.buffer.asUint8List());

    try {
      vpnStarted = await startVpn(platformVersion, tf, platform, {
            'nodeAddr': nodeAddr,
          }) ??
          false;
    } on PlatformException {
      vpnStarted = false;
    }

    // TODO FIXME
    // The TUN device creation happened in the Kotlin code in async way,
    // and we currently don't have mechanism to send data initiated from Kotlin.
    // So, we need to poll the Tun FD existance.
    // We also currently don't have good simple solution to poll the data,
    // so we do sleep for now.
    //
    // looks like android/ios can call Dart code
    // see https://docs.flutter.dev/platform-integration/platform-channels on this part
    // ```
    // If desired, method calls can also be sent in the reverse direction, with the platform acting as client to methods implemented in Dar
    // ```
    for (var i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        tunFd = await getTunFD(platformVersion, tf, platform) ?? -1;
      } on PlatformException {
        tunFd = -1;
      }
      if (tunFd > 0) {
        break;
      }
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _vpnStarted = vpnStarted;
      _tunFd = tunFd;
      _nodeAddr = nodeAddr;
      _dummyBattLevel = dummyBattLevel;
    });

    startMycelium(
        peer: 'tcp://[2a01:4f8:221:1e0b::2]:9651',
        tunFd: tunFd,
        privKey: privKey.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text(
              'Platform: $_platformVersion\nvpnStarted: $_vpnStarted \ntun_fd: $_tunFd\nnode_addr:$_nodeAddr\nbatt:$_dummyBattLevel'),
        ),
      ),
    );
  }
}

Future<ByteData> loadPrivKey() async {
  return await rootBundle.load('assets/priv_key.bin');
}

Future<String> getBatteryLevel(MethodChannel platform) async {
  String batteryLevel;
  try {
    final result = await platform.invokeMethod<int>('getBatteryLevel');
    batteryLevel = 'Battery level at $result % .';
  } on PlatformException catch (e) {
    batteryLevel = "Failed to get battery level: '${e.message}'.";
  }
  return batteryLevel;
}

Future<bool?> startVpn(String platformVersion, TunFlutter tf,
    MethodChannel platform, Map<String, String> configs) {
  if (platformVersion.toLowerCase().contains("android")) {
    return tf.startVpn(configs);
  } else {
    return platform.invokeMethod<bool>('startVpn', configs);
  }
}

Future<int?> getTunFD(
    String platformVersion, TunFlutter tf, MethodChannel platform) {
  if (platformVersion.toLowerCase().contains("android")) {
    return tf.getTunFD();
  } else {
    return platform.invokeMethod<int>('getTunFD');
  }
}
