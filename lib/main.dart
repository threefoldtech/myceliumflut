import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter_desktop_sleep/flutter_desktop_sleep.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

import 'myceliumflut_ffi_binding.dart';

final _logger = Logger('Mycelium');

const String startMyceliumText = 'Start Mycelium';
const String stopMyceliumText = 'Stop Mycelium';

const String myceliumStatusStarted = 'Mycelium Started';
const String myceliumStatusStopped = 'Mycelium Stopped';
const String myceliumStatusRestarted = 'Mycelium Restarted';
const String myceliumStatusFailedStart = 'Mycelium failed to start';

const Color colorDarkBlue = Color(0xFF025996);
const Color colorLimeGreen = Color(0xFF0D9C9E);
const Color colorMycelRed = Color(0xFFEC3F09);

const sizedBoxHeight = 40.0;

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
  List<String> peers = [];
  late TextEditingController textEditController;
  final _flutterDesktopSleepPlugin = FlutterDesktopSleep();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    textEditController = TextEditingController(text: '');
    super.initState();
    initPlatformState();
    platform.setMethodCallHandler((MethodCall call) async {
      methodHandler(call.method);
    });
    // flutter desktop sleep plugin only works on macos and windows
    _flutterDesktopSleepPlugin.setWindowSleepHandler((String? s) async {
      if (s != null) {
        if (s == 'woke_up') {
          if (_isStarted) {
            restartMyceliumOnWakeup();
          }
        } else if (s == 'terminate_app') {
          // only for macos because:
          // 1. it supposed to work on Windows as well, but it doesn't
          // 2. to make it clear that it's only for macos
          if (Platform.isMacOS) {
            _logger.info("TERMINATE_APP");
            if (_isStarted) {
              stopMycelium();
            }
            _flutterDesktopSleepPlugin.terminateApp();
          }
        } else {
          _logger
              .info("[flutter_desktop_sleep handler]Unknown event handler: $s");
        }
      }
    });

    // only for windows because macos already has own handler
    if (Platform.isWindows) {
      FlutterWindowClose.setWindowShouldCloseHandler(() async {
        _logger.info("Window close handler");
        if (_isStarted) {
          stopMycelium();
        }
        return true;
      });
    }
  }

  void methodHandler(String methodName) {
    switch (methodName) {
      case 'notifyMyceliumFailed':
        // mycelium failed to start
        _logger.warning("Mycelium failed to start");
        setStateFailedStart();
        break;
      case 'notifyMyceliumFinished':
        // mycelium finished (user triggered)
        _logger.info("Mycelium finished");
        setStateStopped();
        break;
      case 'notifyMyceliumStarted':
        // mycelium started successfully
        _logger.info("Mycelium started");
        setStateStarted();
        break;
      case 'notifyAppWakeup':
        // the app woke up, after sleep
        if (_isStarted) {
          _logger.info("App woke up");
          restartMyceliumOnWakeup();
        }
      default:
        _logger.warning("Unknown method call: $methodName");
        throw MissingPluginException();
    }
  }

  void restartMyceliumOnWakeup() async {
    _logger.info("[wake up handler]stopping mycelium");
    stopMycelium();
    // Wait for isStarted to become false, but no more than 3 seconds
    final timeout = DateTime.now().add(const Duration(seconds: 3));
    while (_isStarted && DateTime.now().isBefore(timeout)) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _logger.info("[wake up handler]starting mycelium");
    startMycelium();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    privKey = await loadOrGeneratePrivKey(platform);
    peers = await loadPeers();
    if (peers.isEmpty || (peers.length == 1 && peers[0].isEmpty)) {
      peers = [
        'tcp://185.69.166.7:9651',
        'tcp://188.40.132.242:9651',
        'tcp://209.159.146.190:9651',
        'tcp://5.223.43.251:9651'
      ];
    }
    textEditController = TextEditingController(text: peers.join('\n'));

    String nodeAddr;
    if (isUseDylib()) {
      nodeAddr = myFFAddressFromSecretKey(privKey);
    } else {
      nodeAddr = (await platform.invokeMethod<String>(
          'addressFromSecretKey', privKey)) as String;
    }

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
  bool isRestartVisible = false;
  String _textButton = startMyceliumText;
  String _myceliumStatus = '';
  String _peerValidity = '';
  Color _myceliumStatusColor = Colors.white;
  Color _startStopButtonColor = colorDarkBlue;

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    textEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //_logger.info("ratio: ${MediaQuery.devicePixelRatioOf(context)}");
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        appBar: AppBar(
          title: Container(
            margin: const EdgeInsets.only(top: 16.0),
            child: Image.asset(
              'assets/images/mycelium_top.png',
              width: 1200, //physicalPxToLogicalPx(context, 161.9),
              height: 150, //physicalPxToLogicalPx(context, 29.85),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Center(
            child: Column(
              children: [
                const SizedBox(
                  height: sizedBoxHeight,
                ),
                const Align(
                    alignment: Alignment.centerLeft,
                    // IP address title
                    child: Text("IP Address:",
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7D7E7E),
                            fontWeight: FontWeight.w500))),
                Container(
                    // Node address
                    width: double.infinity,
                    height: physicalPxToLogicalPx(context, 48),
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 245, 241, 241),
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10.0)),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SelectableText(
                            _nodeAddr,
                            //textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _nodeAddr));
                            },
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: sizedBoxHeight),
                const Align(
                    alignment: Alignment.centerLeft,
                    // Peers
                    child: Text("Peers:",
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7D7E7E),
                            fontWeight: FontWeight.w500))),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 150,
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: TextField(
                      // peers address
                      controller: textEditController,
                      onTapOutside: (event) => {
                        FocusManager.instance.primaryFocus?.unfocus(),
                      },
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        //labelText: 'Peers',
                      ),
                    ),
                  ),
                ),
                Text(_peerValidity,
                    style: const TextStyle(color: colorMycelRed)),
                const SizedBox(height: sizedBoxHeight), // Add some space
                SizedBox(
                  width: double.infinity,
                  height: physicalPxToLogicalPx(context, 48),
                  child: ElevatedButton(
                    // Start/Stop button
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _startStopButtonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              10.0), // reduce the roundedness
                        ),
                        textStyle: const TextStyle(fontSize: 16)),
                    child: Text(_textButton),
                    onPressed: () {
                      if (!_isStarted) {
                        startMycelium();
                      } else {
                        stopMycelium();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20), // Add some space
                Text(
                  _myceliumStatus,
                  style: TextStyle(
                      color: _myceliumStatusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 20), // Add some space
                Visibility(
                  visible: isRestartVisible,
                  child: SizedBox(
                    width: double.infinity,
                    height: physicalPxToLogicalPx(context, 48),
                    child: ElevatedButton(
                      // Restart button
                      style: ElevatedButton.styleFrom(
                          backgroundColor: colorLimeGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.only(left: 16, right: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                10.0), // reduce the roundedness
                          ),
                          textStyle: const TextStyle(fontSize: 16)),
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              child: Icon(Icons.restart_alt_rounded,
                                  size: 20), // Add the icon
                            ),
                            TextSpan(
                              text: " RestartMycelium",
                            ),
                          ],
                        ),
                      ),
                      onPressed: () async {
                        stopMycelium();
                        // Wait for isStarted to become false, but no more than 3 seconds
                        final timeout =
                            DateTime.now().add(const Duration(seconds: 3));
                        while (_isStarted && DateTime.now().isBefore(timeout)) {
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                        }
                        startMycelium();
                        setState(() {
                          _myceliumStatus = myceliumStatusRestarted;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void startMycelium() {
    if (_isStarted) {
      _logger.warning("Mycelium already started");
      return;
    }
    _peerValidity = '';
    var peers = getPeers(textEditController.text);
    peers = preprocessPeers(peers);

    // verify the peers
    String? peerError = isValidPeers(peers);
    if (peerError != null) {
      setState(() {
        _peerValidity = peerError;
      });
      return;
    }
    // store the peers if verified
    storePeers(peers);
    textEditController.text = peers.join('\n');
    try {
      if (!isUseDylib()) {
        startVpn(platform, peers, privKey);
        // the startVpn result will be send in async way by Kotlin/Swift
        setStateStarted();
      } else {
        final receivePort = ReceivePort();

        // Create a Map to hold the arguments
        final args = {
          'sendPort': receivePort.sendPort,
          'peers': peers,
          'privKey': privKey,
        };

        // Spawn the isolate
        Isolate.spawn(startMyceliumIsolate, args);

        // the startVpn result will be send in async way by Kotlin/Swift
        setStateStarted();
        methodHandler('notifyMyceliumStarted');
        // Handle the isolate completion using a StreamSubscription
        receivePort.listen((message) {
          if (message == 'done') {
            _logger.info("mycelStartMycelium task completed");
            receivePort.close();
            methodHandler('notifyMyceliumFinished');
          } else {
            _logger.warning("mycelStartMycelium task finished, but not done");
            methodHandler('notifyMyceliumFinished');
          }
        });
      }
    } on Exception {
      _logger.warning("Start VPN failed");
      setStateFailedStart();
    }
  }

  static void startMyceliumIsolate(Map<String, dynamic> args) {
    final SendPort sendPort = args['sendPort'];
    final List<String> peers = args['peers'];
    final Uint8List privKey = args['privKey'];

    // Perform the mycelStartMycelium task
    myFFStartMycelium(peers, privKey);

    // Notify the main thread that the task is complete
    sendPort.send('done');
  }

  void stopMycelium() {
    try {
      stopVpn(platform);
      // stopVpn result will be send in async way by Kotlin/Swift
      // the message will be received by the setMethodCallHandler with the method 'notifyMyceliumFinished'
    } on Exception {
      _logger.warning("stopping VPN failed");
    }
  }

  void setStateFailedStart() {
    setState(() {
      _isStarted = false;
      _textButton = startMyceliumText;
      _myceliumStatus = myceliumStatusFailedStart;
      _startStopButtonColor = colorDarkBlue;
      _myceliumStatusColor = colorMycelRed;
      isRestartVisible = false;
    });
  }

  void setStateStopped() {
    setState(() {
      _isStarted = false;
      _textButton = startMyceliumText;
      _myceliumStatus = myceliumStatusStopped;
      _startStopButtonColor = colorDarkBlue;
      _myceliumStatusColor = colorMycelRed;
      isRestartVisible = false;
    });
  }

  void setStateStarted() {
    setState(() {
      _isStarted = true;
      _textButton = stopMyceliumText;
      _myceliumStatus = myceliumStatusStarted;
      _startStopButtonColor = colorMycelRed;
      _myceliumStatusColor = colorDarkBlue;
      isRestartVisible = true;
    });
  }
}

double physicalPxToLogicalPx(BuildContext context, double physicalPx) {
  return physicalPx; //x * MediaQuery.of(context).devicePixelRatio;
}

List<String> getPeers(String texts) {
  return texts.split('\n').map((e) => e.trim()).toList();
}

Future<void> storePeers(List<String> peers) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/peers.txt');
  await file.writeAsString(peers.join('\n'));
}

Future<List<String>> loadPeers() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/peers.txt');
  if (await file.exists()) {
    String contents = await file.readAsString();
    return contents.split('\n');
  } else {
    return [];
  }
}

Future<Uint8List> loadOrGeneratePrivKey(MethodChannel platform) async {
  // get dir
  final dir = await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/priv_key.bin');
  if (file.existsSync()) {
    return await file.readAsBytes();
  }
  // create new secret key if not exists
  Uint8List privKey = Uint8List(0);
  if (isUseDylib()) {
    privKey = myFFGenerateSecretKey();
  } else {
    privKey = (await platform.invokeMethod<Uint8List>('generateSecretKey'))
        as Uint8List;
  }
  //}
  await file.writeAsBytes(privKey);
  return privKey;
}

Future<bool?> startVpn(
    MethodChannel platform, List<String> peers, Uint8List privKey) async {
  if (isUseDylib()) {
    return myFFStartMycelium(peers, privKey);
  } else {
    return platform.invokeMethod<bool>('startVpn', {
      'peers': peers,
      'secretKey': privKey,
    });
  }
}

Future<bool> stopVpn(MethodChannel platform) async {
  // check if VPN is started is done on Kotlin / Swift side
  var stopped = false;
  if (isUseDylib()) {
    stopped = await myFFStopMycelium();
  } else {
    stopped = await platform.invokeMethod<bool>('stopVpn') ?? false;
  }

  _logger.info("stop vpn : $stopped");
  return stopped;
}

List<String> preprocessPeers(List<String> peers) {
  // Remove empty elements
  peers.removeWhere((peer) => peer.isEmpty);

  // Remove duplicated elements
  return peers.toSet().toList();
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
  final prefixRegex = RegExp(r'^tcp://');
  final ipv4Regex = RegExp(
      r'((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)');
  final ipv6Regex = RegExp(
      r'\[(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))\]');
  final portRegex = RegExp(r':9651$');

  if (!prefixRegex.hasMatch(peer)) {
    return 'peer must start with tcp://';
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
