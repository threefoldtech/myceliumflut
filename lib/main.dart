import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tun_flutter/tun_flutter.dart';

import 'package:myceliumflut/src/rust/api/simple.dart';
import 'package:myceliumflut/src/rust/frb_generated.dart';
import 'package:path_provider/path_provider.dart';

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
  int _tunFd = 0;
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
    int tunFd = -1;

    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await tf.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    privKey = await loadOrGeneratePrivKey();
    var nodeAddr = addressFromSecretKey(data: privKey.buffer.asUint8List());

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _tunFd = tunFd;
      _nodeAddr = nodeAddr;
    });
  }

  bool _isStarted = false;
  String _textButton = "Start Mycelium";
  final textEditController =
      TextEditingController(text: 'tcp://65.21.231.58:9651');

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    textEditController.dispose();
    super.dispose();
  }

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
                  'Platform: $_platformVersion\ntun_fd: $_tunFd\nnode_addr:$_nodeAddr\n'),
              TextField(
                controller: textEditController,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Peers',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final peers = getPeers(textEditController.text);
                  if (!_isStarted) {
                    try {
                      startVpn(tf, platform, peers, _nodeAddr, _tunFd,
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
            ],
          ),
        ),
      ),
    );
  }
}

List<String> getPeers(String texts) {
  return texts.split('\n').map((e) => e.trim()).toList();
}

Future<ByteData> loadOrGeneratePrivKey() async {
  // get dir
  final dir = await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/priv_key.bin');
  if (file.existsSync()) {
    return ByteData.view((await file.readAsBytes()).buffer);
  }
  // create new secret key if not exists
  final privKey = generateSecretKey();
  await file.writeAsBytes(privKey.buffer.asUint8List());
  return ByteData.view(privKey.buffer);
}

Future<bool?> startVpn(TunFlutter tf, MethodChannel platform,
    List<String> peers, String nodeAddr, int tunFd, Uint8List privKey) async {
  var platformVersion = await tf.getPlatformVersion() ?? "unknown";
  if (platformVersion.toLowerCase().contains("android")) {
    await tf.startVpn({
      'nodeAddr': nodeAddr,
    });
    int tunFd = await getTunFDAndroid(tf);
    print("tunFd: $tunFd");
    startMycelium(peers: peers, tunFd: tunFd, privKey: privKey);
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
Future<int> getTunFDAndroid(TunFlutter tf) async {
  int tunFd = 0;
  for (var i = 0; i < 30; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      tunFd = await tf.getTunFD() ?? -1;
    } on PlatformException {
      tunFd = -1;
    }
    if (tunFd > 0) {
      break;
    }
  }
  return tunFd;
}
