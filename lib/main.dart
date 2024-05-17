import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:myceliumflut/src/rust/frb_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Mycelium');

Future<void> main() async {
  // Logger configuration
  Logger.root.level = Level.ALL; // Log messages emitted at all levels
  Logger.root.onRecord.listen((record) {
    // we need this to print to the console
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
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
  String _nodeAddr = '';
  var privKey = Uint8List(0);

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    privKey = await loadOrGeneratePrivKey(platform);

    String nodeAddr = (await platform.invokeMethod<String>(
        'addressFromSecretKey', privKey)) as String;

    _logger.info("nodeAddr: $nodeAddr");

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
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
              Text('node_addr:$_nodeAddr\n'),
              TextField(
                controller: textEditController,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Peers',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final peers = getPeers(textEditController.text);
                  if (!_isStarted) {
                    try {
                      startVpn(platform, peers, privKey);
                      // TODO: check return value of the startVpn above
                      setState(() {
                        _isStarted = true;
                        _textButton = "Stop Mycelium";
                      });
                    } on PlatformException {
                      _logger.warning("Start VPN failed");
                    }
                  } else {
                    try {
                      stopVpn(platform);
                      setState(() {
                        _isStarted = false;
                        _textButton = "Start Mycelium";
                      });
                    } on PlatformException {
                      _logger.warning("stopping VPN failed");
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
  Uint8List privKey = (await platform
      .invokeMethod<Uint8List>('generateSecretKey')) as Uint8List;
  //}
  await file.writeAsBytes(privKey);
  return privKey;
}

Future<bool?> startVpn(
    MethodChannel platform, List<String> peers, Uint8List privKey) async {
  return platform.invokeMethod<bool>('startVpn', {
    'peers': peers,
    'secretKey': privKey,
  });
  //}
}

Future<bool> stopVpn(MethodChannel platform) async {
  // TODO: check if VPN is started
  var stopped = await platform.invokeMethod<bool>('stopVpn') ?? false;

  _logger.info("stop vpn : $stopped");
  return stopped;
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
Future<int> getTunFDAndroid(MethodChannel platform) async {
  int tunFd = 0;
  for (var i = 0; i < 30; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      tunFd = await platform.invokeMethod<int>('getTunFD') as int;
    } on PlatformException {
      tunFd = -1;
    }
    if (tunFd > 0) {
      break;
    }
  }
  return tunFd;
}
