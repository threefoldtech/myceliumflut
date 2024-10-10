# myceliumflut

A mycelium flutter UI

## Development

### prequisites

- install flutter SDK https://docs.flutter.dev/get-started/install according to your platforms
- install Rust
- vscode for editing the Dart code

### iOS

**requirements**
- Real iPhone is needed for test, we can't use Simulator here because mycelium need iOS `Network Extensions` which can't run on Simulator.

**build iOS Swift-Rust Bridge**
```bash
cd mycelmob
bash build-ios.sh
```
there is `IPHONEOS_DEPLOYMENT_TARGET` variable in the `build-ios.sh` which need to be the same with the value set in `XCode`.

### Macos

**build Macos Swift-Rust Bridge**
```bash
cd mycelmob
bash build-mac.sh
```


### Android

**requirements**

- Android Studio. The flutter related configuration can be found in the above flutter SDK  installation guide
- Android NDK 26.1.10909125. Updated version can be found at `android/app/build.gradle` file


**build Android Kotlin-Rust Bridge**
```bash
cd mycelmob
bash build-android.sh
```

### Windows

**requirements**

Visual Studio 2022.

Complete list at https://docs.flutter.dev/get-started/install/windows/desktop#software-requirements

**build Windows DLL**
```bash
cd mycelffi
./build.bat
```


### run
go to `myceliumflut` dir
- `flutter pub get`
- `flutter run`
-  or using vscode:
    - `code .` (to open vscode)
    - `Run` -> `Start Debugging

## Usage

### Windows
We currently need to run it as administrator