# myceliumflut

A mycelium flutter UI

## Development

### prequisites

- install flutter SDK https://docs.flutter.dev/get-started/install
- install Rust
- For Android, install Android Studio / XCode, the flutter related configuration can be found in the above flutter SDK  installation guide
- For iPhone, install Xcode 

### build iOS Swift-Rust Bridge
```bash
cd mycelmob
bash build-ios.sh
```

### build Android Kotlin-Rust Bridge
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