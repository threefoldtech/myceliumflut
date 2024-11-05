import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' show join;

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
    ffi.IntPtr,
    ffi.Pointer<ffi.Uint8>,
    ffi.IntPtr);
typedef FuncDartStartMycelium = void Function(
    ffi.Pointer<ffi.Pointer<ffi.Int8>>, int, ffi.Pointer<ffi.Uint8>, int);

Future<bool?> myFFStartMycelium(List<String> peers, Uint8List privKey) async {
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

  // Call the Rust function
  startMycelium(peerPtrs, peers.length, privKeyPtr, privKey.length);

  // Free the allocated memory
  for (var i = 0; i < peers.length; i++) {
    malloc.free(peerPtrs[i]);
  }
  malloc.free(peerPtrs);
  malloc.free(privKeyPtr);
  return true;
}

typedef FuncRustStopMycelium = ffi.Uint8 Function();
typedef FuncDartStopMycelium = int Function();

Future<bool> myFFStopMycelium() async {
  // Load the dynamic library
  final dylib = loadDll();

  final FuncDartStopMycelium stopMycelium = dylib
      .lookup<ffi.NativeFunction<FuncRustStopMycelium>>('ff_stop_mycelium')
      .asFunction();

  final result = stopMycelium();
  return result != 0;
}
