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
  String _nodeAddr = '';
  var tf = TunFlutter();
  var privKey = Uint8List(0);

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;

    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await tf.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    privKey = await loadOrGeneratePrivKey(platform);
    String nodeAddr = "";
    if (Platform.isAndroid) {
      nodeAddr = addressFromSecretKey(data: privKey); //.buffer.asUint8List());
    } else {
      nodeAddr = (await platform.invokeMethod<String>(
          'addressFromSecretKey', privKey)) as String;
    }
    print("nodeAddr: $nodeAddr");

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _nodeAddr = nodeAddr;
    });
  }

  // start/stop mycelium button variables
  bool _isStarted = false;
  String _textButton = "Start Mycelium";

  // peers text field
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
          title: const Text('Mycelium App'),
        ),
        body: Center(
          child: Column(
            children: [
              Text('Platform: $_platformVersion\nnode_addr:$_nodeAddr\n'),
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
                      startVpn(tf, platform, peers, _nodeAddr, privKey);
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

Future<Uint8List> loadOrGeneratePrivKey(MethodChannel platform) async {
  // get dir
  final dir = await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/priv_key.bin');
  if (file.existsSync()) {
    return await file.readAsBytes();
  }
  // create new secret key if not exists
  Uint8List privKey;
  if (Platform.isAndroid) {
    privKey = generateSecretKey();
  } else {
    privKey = (await platform.invokeMethod<Uint8List>('generateSecretKey'))
        as Uint8List;
  }
  await file.writeAsBytes(privKey); //.buffer.asUint8List());
  return privKey;
}

Future<bool?> startVpn(TunFlutter tf, MethodChannel platform,
    List<String> peers, String nodeAddr, Uint8List privKey) async {
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
