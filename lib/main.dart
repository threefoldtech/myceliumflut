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
  String _platformVersion = 'Unknown';
  bool _vpnStarted = false;
  int _tunFd = 0;
  String _greeting = '';
  var tf = TunFlutter();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    bool vpnStarted;
    int tunFd = -1;

    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await tf.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    try {
      vpnStarted = await tf.startVpn({
            'nodeAddr': '5b4:86cf:d8db:87ee:3c:ab49:ef82:8f81',
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

    var greeting = greet(name: "Paijo");

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _vpnStarted = vpnStarted;
      _tunFd = tunFd;
      _greeting = greeting;
    });
    startMycelium(peer: 'tcp://[2a01:4f8:221:1e0b::2]:9651', tunFd: tunFd);
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
              'greeting: $_greeting\nRunning on: $_platformVersion\nvpnStarted: $_vpnStarted \ntun_fd: $_tunFd\n'),
        ),
      ),
    );
  }
}
