# Mycelium Flutter

A cross-platform Flutter application providing a user interface for the Mycelium IPv6 overlay network. It supports Android, iOS, macOS, Windows, and Linux with native Rust bridges for core network functionality.

## What this is

Mycelium Flutter is a graphical client for Mycelium, the end-to-end encrypted IPv6 overlay network. The app allows users to join the encrypted mesh network and manage their network identity from mobile and desktop devices. All core networking logic is provided by the Rust-based Mycelium library, exposed to Flutter via platform-specific native bridges.

## What this repository contains

- **Flutter application** — Cross-platform UI for managing Mycelium connections and network identity.
- **iOS/macOS Swift-Rust bridge** (`mycelmob/`) — Native bridge for Apple platforms using Swift.
- **Android Kotlin-Rust bridge** (`mycelmob/`) — Native bridge for Android using Kotlin.
- **Windows Rust FFI bridge** (`mycelffi/`) — Native DLL for Windows integration.
- **Build scripts** — Platform-specific scripts for compiling the native bridges.
- **Installer configurations** — Inno Setup script for Windows installers.

## Development

### Prerequisites

- Install Flutter SDK: https://docs.flutter.dev/get-started/install according to your platform
- Install Rust
- VS Code for editing the Dart code

### iOS

**Requirements**
- A real iPhone is needed for testing; the Simulator cannot be used because Mycelium needs iOS `Network Extensions`, which do not run on the Simulator.

**Build iOS Swift-Rust Bridge**
```bash
cd mycelmob
bash build-ios.sh
```
There is an `IPHONEOS_DEPLOYMENT_TARGET` variable in `build-ios.sh` which needs to match the value set in Xcode.

### macOS

**Build macOS Swift-Rust Bridge**
```bash
cd mycelmob
bash build-mac.sh
```

### Android

**Requirements**
- Android Studio. The Flutter-related configuration can be found in the Flutter SDK installation guide.
- Android NDK 26.1.10909125. The updated version can be found in the `android/app/build.gradle` file.

**Build Android Kotlin-Rust Bridge**
```bash
cd mycelmob
bash build-android.sh
```

### Windows

**Requirements**
- Visual Studio 2022.
- Complete list at https://docs.flutter.dev/get-started/install/windows/desktop#software-requirements

**Build Windows DLL**
```bash
cd mycelffi
./build.bat
```

### Run

Go to the `mycelium_flutter` directory:
- `flutter pub get`
- `flutter run`
- Or using VS Code:
  - `code .` (to open VS Code)
  - `Run` -> `Start Debugging`

## Usage

### Windows

The application currently needs to be run as administrator.

## Installer / Release

### Android

**Self-distributed `.apk`**
```console
flutter build apk
```

**Google Play Store release**

1. Create the signature, as described at https://docs.flutter.dev/deployment/android#sign-the-app
2. Change `signingConfig signingConfigs.debug` in [build.gradle](./android/app/build.gradle) to `signingConfig signingConfigs.release`
3. Increase build number in `pubspec.yaml`
4. Build the `.aab` (application bundle):
```console
flutter build appbundle
```

### Windows

Build in release mode:
```console
flutter build windows --release
```

Copy Visual Studio `.dll` files:
```console
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\msvcp140.dll' .\build\windows\x64\runner\Release\
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\msvcp140_1.dll' .\build\windows\x64\runner\Release\
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\msvcp140_2.dll' .\build\windows\x64\runner\Release\
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\vcruntime140.dll' .\build\windows\x64\runner\Release\
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\vcruntime140_1.dll' .\build\windows\x64\runner\Release\
```

Run preparation script:
```console
.\installers\windows\prepare.bat
```

Run Inno Setup. The working directory is `build\windows\x64\runner\Release`:
- `mycelium-network.exe` as the application main executable (it is renamed from the original `mycelium_flutter.exe`)
- `add file(s)` and add all `.dll` files
- `add folder` and add the `data` folder with its subdirectories

Scroll down the list, select the `data` folder path, and click the `Edit…` button. It is important to ensure that the destination sub-folder has the same name `data`; otherwise the app will not run after installation as all contents of the folder are dispersed outside. Enter the name of the `Destination subfolder` as `data` and click `OK`.

The Inno Setup script can be found [here](./installer/windows/mycelium_flutter_innosetup.iss); you need to modify the path (according to your environment) before building it in the Inno Setup app.

## Role in the stack

Mycelium Flutter provides the end-user interface for Mycelium, the encrypted IPv6 overlay network. It connects to the same peer-to-peer network as the daemon and command-line tools, enabling users to participate in the overlay from mobile and desktop devices.

## Relation to ThreeFold

This technology is used within the ThreeFold ecosystem and was first deployed on the ThreeFold Grid. The component itself is designed as reusable infrastructure technology and should be understood by its technical function first, independent of any specific deployment.

## Ownership

This repository is owned and maintained by TF-Tech NV, a Belgian company responsible for the development and maintenance of this technology.

## License

This project is licensed under the Apache License 2.0 — see the [LICENSE](LICENSE) file for details.
Copyright (c) TF-Tech NV.
