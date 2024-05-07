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
  ByteData privKey = ByteData(0);
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

    privKey = await loadPrivKey();
    var nodeAddr = addressFromSecretKey(data: privKey.buffer.asUint8List());

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

    //startMycelium(
    //    peers: ['tcp://65.21.231.58:9651'],
    //    tunFd: tunFd,
    //    privKey: privKey.buffer.asUint8List());
    //print("exited start mycelium");
  }

  bool _isStarted = false;
  String _textButton = "Start Mycelium";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Myceliym Flutter App'),
        ),
        body: Center(
          child: Column(
            children: [
              Text(
                  'Platform: $_platformVersion\nvpnStarted: $_vpnStarted \ntun_fd: $_tunFd\nnode_addr:$_nodeAddr\nbatt:$_dummyBattLevel'),
              ElevatedButton(
                onPressed: () {
                  if (!_isStarted) {
                    try {
                      startVpn(tf, platform, _nodeAddr, _tunFd,
                          privKey.buffer.asUint8List());
                      setState(() {
                        _isStarted = true;
                        _textButton = "Stop Mycelium";
                      });
                    } on PlatformException {
                      print("Start VPN failed");
                    }
                  } else {
                    try {
                      stopVpn(tf, platform);
                      setState(() {
                        _isStarted = false;
                        _textButton = "Start Mycelium";
                      });
                    } on PlatformException {
                      print("stopping VPN failed");
                    }
                  }
                },
                child: Text(_textButton),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    startVpn(tf, platform, _nodeAddr, _tunFd,
                        privKey.buffer.asUint8List());
                  } on PlatformException {
                    print("Start VPN finished");
                  }
                },
                child: Text('Start Mycelium'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    stopVpn(tf, platform);
                  } on PlatformException {
                    print("stopping VPN failed");
                  }
                },
                child: Text('Stop Mycelium'),
              ),
            ],
          ),
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

Future<bool?> startVpn(TunFlutter tf, MethodChannel platform, String nodeAddr,
    int tunFd, Uint8List privKey) async {
  var platformVersion = await tf.getPlatformVersion() ?? "unknown";
  if (platformVersion.toLowerCase().contains("android")) {
    await tf.startVpn({
      'nodeAddr': nodeAddr,
    });

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
    int tunFd = 0;
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
    startMycelium(
        peers: ['tcp://65.21.231.58:9651'], tunFd: tunFd, privKey: privKey);
  } else {
    return platform.invokeMethod<bool>('startVpn', {
      'nodeAddr': nodeAddr,
    });
  }
}

Future<bool?> stopVpn(TunFlutter tf, MethodChannel platform) async {
  var platformVersion = await tf.getPlatformVersion() ?? "unknown";
  if (platformVersion.toLowerCase().contains("android")) {
    await stopMycelium();
    print("will stop vpn");
    var val = await tf.stopVpn();
    print("stopped vpn");
    return val;
  } else {
    return platform.invokeMethod<bool>('stopVpn');
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
