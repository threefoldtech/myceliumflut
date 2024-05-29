import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Mycelium');

const String startMyceliumText = 'Start Mycelium';
const String stopMyceliumText = 'Stop Mycelium';

const String myceliumStatusStarted = 'Mycelium Started';
const String myceliumStatusStopped = 'Mycelium Stopped';
const String myceliumStatusFailedStart = 'Mycelium failed to start';
const Color myceliumStatusBackgroundColorStarted = Colors.lightGreenAccent;
const Color myceliumStatusBackgroundColorStopped = Colors.grey;
const Color myceliumStatusBackgroundColorFailedStart = Colors.yellowAccent;

Future<void> main() async {
  // Logger configuration
  Logger.root.level = Level.ALL; // Log messages emitted at all levels
  Logger.root.onRecord.listen((record) {
    // we need this to print to the console
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
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
    platform.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'notifyMyceliumFailed':
          _logger.warning("Mycelium failed to start");
          // Handle the method call and optionally return a result
          // Update the UI
          setState(() {
            _isStarted = false;
            _textButton = startMyceliumText;
            _myceliumStatus = myceliumStatusFailedStart;
            _myceliumStatusBackgroundColor =
                myceliumStatusBackgroundColorFailedStart;
          });

          break;
        default:
          throw MissingPluginException();
      }
    });
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
  String _textButton = startMyceliumText;
  String _myceliumStatus = '';
  Color _myceliumStatusBackgroundColor = Colors.white;

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
              SelectableText(_nodeAddr),
              TextField(
                controller: textEditController,
                minLines: 1,
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
                    String? peerError = isValidPeers(peers);
                    if (peerError != null) {
                      setState(() {
                        _myceliumStatus = peerError;
                        _myceliumStatusBackgroundColor =
                            myceliumStatusBackgroundColorFailedStart;
                      });
                      return;
                    }
                    try {
                      startVpn(platform, peers, privKey);
                      // the startVpn result will be send in async way by Kotlin/Swift
                      setState(() {
                        _isStarted = true;
                        _textButton = stopMyceliumText;
                        _myceliumStatus = myceliumStatusStarted;
                        _myceliumStatusBackgroundColor =
                            myceliumStatusBackgroundColorStarted;
                      });
                    } on PlatformException {
                      _logger.warning("Start VPN failed");
                      _myceliumStatus = myceliumStatusFailedStart;
                    }
                  } else {
                    try {
                      stopVpn(platform);
                      setState(() {
                        _isStarted = false;
                        _textButton = startMyceliumText;
                        _myceliumStatus = myceliumStatusStopped;
                        _myceliumStatusBackgroundColor =
                            myceliumStatusBackgroundColorStopped;
                      });
                    } on PlatformException {
                      _logger.warning("stopping VPN failed");
                    }
                  }
                },
                child: Text(_textButton),
              ),
              const SizedBox(height: 5), // Add some space
              Container(
                  color: _myceliumStatusBackgroundColor,
                  child: Text(_myceliumStatus)),
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
  // check if VPN is started is done on Kotlin / Swift side
  var stopped = await platform.invokeMethod<bool>('stopVpn') ?? false;
  _logger.info("stop vpn : $stopped");
  return stopped;
}

String? isValidPeers(List<String> peers) {
  if (peers.isEmpty || (peers.length == 1 && peers[0].isEmpty)) {
    return "peers can't be empty";
  }

  for (var peer in peers) {
    String? error = isValidPeer(peer);
    if (error != null) {
      return 'invalid peer:`$peer` $error';
    }
  }
  return null;
}

// check if a peer is a valid peer
String? isValidPeer(String peer) {
  final prefixRegex = RegExp(r'^(tcp|quic)://');
  final ipv4Regex = RegExp(
      r'((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)');
  final ipv6Regex = RegExp(
      r'\[(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))\]');
  final portRegex = RegExp(r':9651$');

  if (!prefixRegex.hasMatch(peer)) {
    return 'peer must start with tcp:// or quic://';
  }

  String ipPortPart = peer.substring(peer.indexOf('://') + 3);
  if (!ipv4Regex.hasMatch(ipPortPart) && !ipv6Regex.hasMatch(ipPortPart)) {
    return 'peer must contain a valid IPv4 or IPv6 address';
  }

  if (!portRegex.hasMatch(ipPortPart)) {
    return 'peer must end with :9651';
  }

  return null;
}
