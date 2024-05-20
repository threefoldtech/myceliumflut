# myceliumflut

A mycelium flutter UI

## Development

### prequisites

- install flutter SDK https://docs.flutter.dev/get-started/install
- install Rust

### iOS

**requirements**
- Xcode for development.
- Real iPhone is needed for test, we can't use Simulator here because mycelium need iOS `Network Extensions` which can't run on Simulator.

**build iOS Swift-Rust Bridge**
```bash
cd mycelmob
bash build-ios.sh
```
there is `IPHONEOS_DEPLOYMENT_TARGET` variable in the `build-ios.sh` which need to be the same with the value set in `XCode`.

### Android
**requirements**
- Android Studio the flutter related configuration can be found in the above flutter SDK  installation guide
- Android NDK 26.1.10909125. Updated version can be found at `android/app/build.gradle` file


**build Android Kotlin-Rust Bridge**
```bash
cd mycelmob
bash build-android.sh
```

### run
go to `myceliumflut` dir
- `flutter pub get`
- `code .`
- `Run` -> `Start Debugging`

see your node address:

- displayed at the app UI on Android
- in the `logcat`(android studio ) or `debug console`(vscode).
The log will be something like this
```
node_addr = 464:de5d:4945:dc4d:a0a9:3dc9:c9be:35b7
```