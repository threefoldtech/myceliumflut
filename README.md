# myceliumflut

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development

### prequisites

- install flutter SDK https://docs.flutter.dev/get-started/install
- install Rust
- For Android, install Android Studio / XCode, the flutter related configuration can be found in the above flutter SDK  installation guide
- For iPhone, install Xcode 

### build iOS Swift-Rust Bridge
```bash
cd ios
bash build-mycelios.sh
```

### build Android Kotlin-Rust Bridge
```bash
cd mycelmob
bash build-android.sh
```

### run
go to `myceliumflut` dir
- `code .`
- `Run` -> `Start Debugging`

see your node address:

- displayed at the app UI on Android
- in the `logcat`(android studio ) or `debug console`(vscode).
The log will be something like this
```
node_addr = 464:de5d:4945:dc4d:a0a9:3dc9:c9be:35b7
```