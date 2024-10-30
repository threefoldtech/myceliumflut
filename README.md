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

## Installer / Release

### Android

**self distributed `.apk`**
```console
flutter build apk
```

**google playstore release**

1. create the signature, as described at https://docs.flutter.dev/deployment/android#sign-the-app
2. change `signingConfig signingConfigs.debug` in [build.gradle](./android/app/build.gradle) to `signingConfig signingConfigs.release`
3. increase build number in pubspec.yaml
4. build the `.aab` (application bundle)
```console
flutter build appbundle
```



### Windows

Build in release mode
```console
flutter build windows --release
```

copy visual studo `.dll` files:
```console
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\msvcp140.dll' .\build\windows\x64\runner\Release\
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\msvcp140_1.dll' .\build\windows\x64\runner\Release\ 
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\msvcp140_2.dll' .\build\windows\x64\runner\Release\  
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\vcruntime140.dll' .\build\windows\x64\runner\Release\
cp 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\vcruntime140_1.dll' .\build\windows\x64\runner\Release\
```


Run Inno Setup, our working dir is `build\windows\x64\runner\Release`:
- myceliumflut.exe as the application main executable
- `add file(s)` and add all `.dll` files
- `add folder` and add `data` folder with it's subdirectories

Scroll down the list & select the `data` folder path and click on `Edit…` button.
It is important to ensure that the destination sub-folder has the same name `data` otherwise the app wont run after installation as all contents of the folder are dispersed outside. So, enter the name of the `Destination subfolder` as `data` and click `OK`.

The Inno Setup script can be found [here](./files/windows_installer.iss), you need to modify the path (according to your env) before `Build` it on `Inno Setup` app.



