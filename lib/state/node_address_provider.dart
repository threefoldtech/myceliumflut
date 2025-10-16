import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../myceliumflut_ffi_binding.dart';

/// Provider for the node address
final nodeAddressProvider = FutureProvider<String>((ref) async {
  try {
    const platform = MethodChannel("tech.threefold.mycelium/tun");

    // Load the private key
    final privKey = await loadOrGeneratePrivKey(platform);

    // Calculate the node address
    String nodeAddr;
    if (isUseDylib()) {
      nodeAddr = myFFAddressFromSecretKey(privKey);
    } else {
      nodeAddr = (await platform.invokeMethod<String>(
          'addressFromSecretKey', privKey)) as String;
    }

    return nodeAddr;
  } catch (e) {
    // Return empty string if there's an error
    return '';
  }
});

/// Helper function to load or generate private key (copied from main.dart)
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
  await file.writeAsBytes(privKey);
  return privKey;
}
