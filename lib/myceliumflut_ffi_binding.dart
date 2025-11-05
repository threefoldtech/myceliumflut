import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' show join;
import 'dart:ffi';

ffi.DynamicLibrary loadDll() {
  var dllPath = 'assets/dll/winmycelium.dll';
  if (Platform.isMacOS) {
    var basePath =
        'build/macos/Build/Products/Debug/myceliumflut.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets';
    var fullPath =
        join('/Users/ibk/fun/threefoldtech/myceliumflut', basePath, dllPath);
    return ffi.DynamicLibrary.open(fullPath);
  } else {
    var basePath = '';
    if (kReleaseMode) {
      basePath = join(Directory.current.path, 'data', 'flutter_assets');
    } else {
      basePath = Directory.current.path;
    }
    var fullPath = join(basePath, dllPath);

    return ffi.DynamicLibrary.open(fullPath);
  }
}

bool isUseDylib() {
  return Platform.isWindows; //|| Platform.isMacOS;
}

typedef FuncRustGenerateSecretKey = ffi.Void Function(
    ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);
typedef FuncDartGenerateSecretKey = void Function(
    ffi.Pointer<ffi.Pointer<ffi.Uint8>>, ffi.Pointer<ffi.IntPtr>);
typedef FuncRustFreeSecretKey = ffi.Void Function(
    ffi.Pointer<ffi.Uint8>, ffi.IntPtr);
typedef FuncDartFreeSecretKey = void Function(ffi.Pointer<ffi.Uint8>, int);

Uint8List myFFGenerateSecretKey() {
  var dylib = loadDll();
  final FuncDartGenerateSecretKey generateSecretKey = dylib
      .lookup<ffi.NativeFunction<FuncRustGenerateSecretKey>>(
          'ff_generate_secret_key')
      .asFunction();
  final FuncDartFreeSecretKey freeSecretKey = dylib
      .lookup<ffi.NativeFunction<FuncRustFreeSecretKey>>('free_secret_key')
      .asFunction();
  final outPtr = malloc<ffi.Pointer<ffi.Uint8>>();
  final outLen = malloc<ffi.IntPtr>();

  generateSecretKey(outPtr, outLen);

  final ptr = outPtr.value;
  final len = outLen.value;

  final secretKey = ptr.asTypedList(len);

  // Free the allocated memory
  freeSecretKey(ptr, len);
  malloc.free(outPtr);
  malloc.free(outLen);

  return secretKey;
}

// Define the FFI types
typedef FuncRustMycelAddressFromSecretKey = ffi.Pointer<ffi.Int8> Function(
    ffi.Pointer<ffi.Uint8>, ffi.IntPtr);
typedef FuncDartMycelAddressFromSecretKey = ffi.Pointer<ffi.Int8> Function(
    ffi.Pointer<ffi.Uint8>, int);
typedef FuncRustFreeCString = ffi.Void Function(ffi.Pointer<ffi.Int8>);
typedef FuncDartFreeCString = void Function(ffi.Pointer<ffi.Int8>);

String myFFAddressFromSecretKey(Uint8List data) {
  // Load the dynamic library
  final dylib = loadDll();

// Look up the functions
  final FuncDartMycelAddressFromSecretKey mycelAddressFromSecretKey = dylib
      .lookup<ffi.NativeFunction<FuncRustMycelAddressFromSecretKey>>(
          'ff_address_from_secret_key')
      .asFunction();
  final FuncDartFreeCString freeCString = dylib
      .lookup<ffi.NativeFunction<FuncRustFreeCString>>('free_c_string')
      .asFunction();

  final ptr = malloc<ffi.Uint8>(data.length);
  final nativeData = ptr.asTypedList(data.length);
  nativeData.setAll(0, data);

  final addressPtr = mycelAddressFromSecretKey(ptr, data.length);
  final address = addressPtr.cast<Utf8>().toDartString();

  // Free the allocated memory
  freeCString(addressPtr);
  malloc.free(ptr);

  return address;
}

typedef FuncRustStartMycelium = ffi.Void Function(
    ffi.Pointer<ffi.Pointer<ffi.Int8>>,
    ffi.Size,
    ffi.Pointer<ffi.Uint8>,
    ffi.Size);
typedef FuncDartStartMycelium = void Function(
    ffi.Pointer<ffi.Pointer<ffi.Int8>>, int, ffi.Pointer<ffi.Uint8>, int);

Future<bool> myFFStartMycelium(List<String> peers, Uint8List privKey) async {
  // Run the blocking FFI call in a separate isolate to prevent UI freezing
  final result = compute(_startMyceliumInIsolate, {
    'peers': peers,
    'privKey': privKey,
  });
  return result;
}

// Function to run in isolate
bool _startMyceliumInIsolate(Map<String, dynamic> args) {
  final List<String> peers = args['peers'];
  final Uint8List privKey = args['privKey'];

  // Load the dynamic library
  final dylib = loadDll();

  // Look up the function
  final FuncDartStartMycelium startMycelium = dylib
      .lookup<ffi.NativeFunction<FuncRustStartMycelium>>('ff_start_mycelium')
      .asFunction();

  // Allocate memory for peers
  final peerPtrs = malloc<ffi.Pointer<ffi.Int8>>(peers.length);
  for (var i = 0; i < peers.length; i++) {
    final peer = peers[i];
    final peerPtr = peer.toNativeUtf8().cast<ffi.Int8>();
    peerPtrs[i] = peerPtr;
  }

  // Allocate memory for private key
  final privKeyPtr = malloc<ffi.Uint8>(privKey.length);
  final nativePrivKey = privKeyPtr.asTypedList(privKey.length);
  nativePrivKey.setAll(0, privKey);
  try {
    // Call the Rust function (this is the blocking call)
    startMycelium(peerPtrs, peers.length, privKeyPtr, privKey.length);
    return true;
  } catch (e) {
    // FFI binding loaded successfully
    return false;
  } finally {
    // Free the allocated memory
    for (var i = 0; i < peers.length; i++) {
      malloc.free(peerPtrs[i]);
    }
    malloc.free(peerPtrs);
    malloc.free(privKeyPtr);
  }
}

typedef FuncRustStopMycelium = ffi.Bool Function();
typedef FuncDartStopMycelium = bool Function();

Future<bool> myFFStopMycelium() async {
  // Load the dynamic library
  final dylib = loadDll();

  final FuncDartStopMycelium stopMycelium = dylib
      .lookup<ffi.NativeFunction<FuncRustStopMycelium>>('ff_stop_mycelium')
      .asFunction();

  final result = stopMycelium();
  return result;
}

typedef FuncRustGetPeerStatus = ffi.Void Function(
    ffi.Pointer<ffi.Pointer<ffi.Pointer<ffi.Int8>>>, ffi.Pointer<ffi.IntPtr>);
typedef FuncDartGetPeerStatus = void Function(
    ffi.Pointer<ffi.Pointer<ffi.Pointer<ffi.Int8>>>, ffi.Pointer<ffi.IntPtr>);
typedef FuncRustFreePeerStatus = ffi.Void Function(
    ffi.Pointer<ffi.Pointer<ffi.Int8>>, ffi.IntPtr);
typedef FuncDartFreePeerStatus = void Function(
    ffi.Pointer<ffi.Pointer<ffi.Int8>>, int);

Future<List<String>> myFFGetPeerStatus() async {
  final outPtr = calloc<Pointer<Pointer<Int8>>>();
  final outLen = calloc<IntPtr>();

  try {
    var dylib = loadDll();
    final ffGetPeerStatus = dylib
        .lookup<NativeFunction<FuncRustGetPeerStatus>>('ff_get_peer_status')
        .asFunction<FuncDartGetPeerStatus>();

    ffGetPeerStatus(outPtr, outLen);

    final length = outLen.value;
    final ptr = outPtr.value;

    final List<String> result = [];
    for (int i = 0; i < length; i++) {
      final stringPtr = (ptr + i).value;
      if (stringPtr != nullptr) {
        result.add(stringPtr.cast<Utf8>().toDartString());
      }
    }

    // Free the memory
    final freePeerStatus = dylib
        .lookup<NativeFunction<FuncRustFreePeerStatus>>('free_peer_status')
        .asFunction<FuncDartFreePeerStatus>();
    freePeerStatus(ptr, length);

    return result;
  } finally {
    calloc.free(outPtr);
    calloc.free(outLen);
  }
}

Future<List<String>> myFFProxyConnect(String remote) async {
  final outPtr = calloc<Pointer<Pointer<Int8>>>();
  final outLen = calloc<IntPtr>();
  final remotePtr = remote.toNativeUtf8().cast<Int8>();

  try {
    var dylib = loadDll();
    final ffProxyConnect = dylib
        .lookup<
            NativeFunction<
                Void Function(Pointer<Int8>, Pointer<Pointer<Pointer<Int8>>>,
                    Pointer<IntPtr>)>>('ff_proxy_connect')
        .asFunction<
            void Function(Pointer<Int8>, Pointer<Pointer<Pointer<Int8>>>,
                Pointer<IntPtr>)>();

    ffProxyConnect(remotePtr, outPtr, outLen);

    final length = outLen.value;
    final ptr = outPtr.value;

    final List<String> result = [];
    for (int i = 0; i < length; i++) {
      final stringPtr = (ptr + i).value;
      if (stringPtr != nullptr) {
        result.add(stringPtr.cast<Utf8>().toDartString());
      }
    }

    // Free the memory
    final freePeerStatus = dylib
        .lookup<NativeFunction<FuncRustFreePeerStatus>>('free_peer_status')
        .asFunction<FuncDartFreePeerStatus>();
    freePeerStatus(ptr, length);

    return result;
  } finally {
    calloc.free(remotePtr);
    calloc.free(outPtr);
    calloc.free(outLen);
  }
}

Future<List<String>> myFFProxyDisconnect() async {
  final outPtr = calloc<Pointer<Pointer<Int8>>>();
  final outLen = calloc<IntPtr>();

  try {
    var dylib = loadDll();
    final ffProxyDisconnect = dylib
        .lookup<NativeFunction<FuncRustGetPeerStatus>>('ff_proxy_disconnect')
        .asFunction<FuncDartGetPeerStatus>();

    ffProxyDisconnect(outPtr, outLen);

    final length = outLen.value;
    final ptr = outPtr.value;

    final List<String> result = [];
    for (int i = 0; i < length; i++) {
      final stringPtr = (ptr + i).value;
      if (stringPtr != nullptr) {
        result.add(stringPtr.cast<Utf8>().toDartString());
      }
    }

    // Free the memory
    final freePeerStatus = dylib
        .lookup<NativeFunction<FuncRustFreePeerStatus>>('free_peer_status')
        .asFunction<FuncDartFreePeerStatus>();
    freePeerStatus(ptr, length);

    return result;
  } finally {
    calloc.free(outPtr);
    calloc.free(outLen);
  }
}

Future<List<String>> myFFStartProxyProbe() async {
  final outPtr = calloc<Pointer<Pointer<Int8>>>();
  final outLen = calloc<IntPtr>();

  try {
    var dylib = loadDll();
    final ffStartProxyProbe = dylib
        .lookup<NativeFunction<FuncRustGetPeerStatus>>('ff_start_proxy_probe')
        .asFunction<FuncDartGetPeerStatus>();

    ffStartProxyProbe(outPtr, outLen);

    final length = outLen.value;
    final ptr = outPtr.value;

    final List<String> result = [];
    for (int i = 0; i < length; i++) {
      final stringPtr = (ptr + i).value;
      if (stringPtr != nullptr) {
        result.add(stringPtr.cast<Utf8>().toDartString());
      }
    }

    // Free the memory
    final freePeerStatus = dylib
        .lookup<NativeFunction<FuncRustFreePeerStatus>>('free_peer_status')
        .asFunction<FuncDartFreePeerStatus>();
    freePeerStatus(ptr, length);

    return result;
  } finally {
    calloc.free(outPtr);
    calloc.free(outLen);
  }
}

Future<List<String>> myFFStopProxyProbe() async {
  final outPtr = calloc<Pointer<Pointer<Int8>>>();
  final outLen = calloc<IntPtr>();

  try {
    var dylib = loadDll();
    final ffStopProxyProbe = dylib
        .lookup<NativeFunction<FuncRustGetPeerStatus>>('ff_stop_proxy_probe')
        .asFunction<FuncDartGetPeerStatus>();

    ffStopProxyProbe(outPtr, outLen);

    final length = outLen.value;
    final ptr = outPtr.value;

    final List<String> result = [];
    for (int i = 0; i < length; i++) {
      final stringPtr = (ptr + i).value;
      if (stringPtr != nullptr) {
        result.add(stringPtr.cast<Utf8>().toDartString());
      }
    }

    // Free the memory
    final freePeerStatus = dylib
        .lookup<NativeFunction<FuncRustFreePeerStatus>>('free_peer_status')
        .asFunction<FuncDartFreePeerStatus>();
    freePeerStatus(ptr, length);

    return result;
  } finally {
    calloc.free(outPtr);
    calloc.free(outLen);
  }
}

Future<List<String>> myFFListProxies() async {
  final outPtr = calloc<Pointer<Pointer<Int8>>>();
  final outLen = calloc<IntPtr>();

  try {
    var dylib = loadDll();
    final ffListProxies = dylib
        .lookup<NativeFunction<FuncRustGetPeerStatus>>('ff_list_proxies')
        .asFunction<FuncDartGetPeerStatus>();

    ffListProxies(outPtr, outLen);

    final length = outLen.value;
    final ptr = outPtr.value;

    final List<String> result = [];
    for (int i = 0; i < length; i++) {
      final stringPtr = (ptr + i).value;
      if (stringPtr != nullptr) {
        result.add(stringPtr.cast<Utf8>().toDartString());
      }
    }

    // Free the memory
    final freePeerStatus = dylib
        .lookup<NativeFunction<FuncRustFreePeerStatus>>('free_peer_status')
        .asFunction<FuncDartFreePeerStatus>();
    freePeerStatus(ptr, length);

    return result;
  } finally {
    calloc.free(outPtr);
    calloc.free(outLen);
  }
}

// Windows system proxy configuration functions
typedef FuncRustEnableSystemProxy = ffi.Bool Function(ffi.Pointer<ffi.Int8>);
typedef FuncDartEnableSystemProxy = bool Function(ffi.Pointer<ffi.Int8>);

Future<bool> myFFEnableSystemProxy({String? proxyAddress}) async {
  try {
    var dylib = loadDll();
    final ffEnableSystemProxy = dylib
        .lookup<NativeFunction<FuncRustEnableSystemProxy>>('ff_enable_system_proxy')
        .asFunction<FuncDartEnableSystemProxy>();

    if (proxyAddress != null && proxyAddress.isNotEmpty) {
      final proxyPtr = proxyAddress.toNativeUtf8().cast<Int8>();
      try {
        return ffEnableSystemProxy(proxyPtr);
      } finally {
        calloc.free(proxyPtr);
      }
    } else {
      // Pass null to use default 127.0.0.1:1080
      return ffEnableSystemProxy(nullptr);
    }
  } catch (e) {
    debugPrint("Failed to enable system proxy: $e");
    return false;
  }
}

typedef FuncRustDisableSystemProxy = ffi.Bool Function();
typedef FuncDartDisableSystemProxy = bool Function();

Future<bool> myFFDisableSystemProxy() async {
  try {
    var dylib = loadDll();
    final ffDisableSystemProxy = dylib
        .lookup<NativeFunction<FuncRustDisableSystemProxy>>('ff_disable_system_proxy')
        .asFunction<FuncDartDisableSystemProxy>();

    return ffDisableSystemProxy();
  } catch (e) {
    debugPrint("Failed to disable system proxy: $e");
    return false;
  }
}

typedef FuncRustGetSystemProxyStatus = ffi.Bool Function();
typedef FuncDartGetSystemProxyStatus = bool Function();

Future<bool> myFFGetSystemProxyStatus() async {
  try {
    var dylib = loadDll();
    final ffGetSystemProxyStatus = dylib
        .lookup<NativeFunction<FuncRustGetSystemProxyStatus>>('ff_get_system_proxy_status')
        .asFunction<FuncDartGetSystemProxyStatus>();

    return ffGetSystemProxyStatus();
  } catch (e) {
    debugPrint("Failed to get system proxy status: $e");
    return false;
  }
}

// Check if running as administrator on Windows
typedef FuncRustIsRunningAsAdmin = ffi.Bool Function();
typedef FuncDartIsRunningAsAdmin = bool Function();

bool myFFIsRunningAsAdmin() {
  try {
    var dylib = loadDll();
    final ffIsRunningAsAdmin = dylib
        .lookup<NativeFunction<FuncRustIsRunningAsAdmin>>('ff_is_running_as_admin')
        .asFunction<FuncDartIsRunningAsAdmin>();

    return ffIsRunningAsAdmin();
  } catch (e) {
    debugPrint("Failed to check admin status: $e");
    return true; // Default to true to avoid false warnings
  }
}
