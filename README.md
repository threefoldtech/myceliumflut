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

- install Android Studio
- install flutter SDK


### dependencies

Put `mycelium` code into the same parent directory as this `myceliumflut`.
Something like this
```bash
dev_directory/
    mycelium/
    myceliumflut/
```
It is because we currently put `mycelium` dependency as local files (not github project) to ease the development.
Checkout to `tun_android` branch of `mycelium` 

### run
go to `myceliumflut` dir
- `code .`
- `mkdir assets`
- `cp your_mycelium_priv_key.bin assets/priv_key.bin`
- `echo your_mycelium_ip_v6 > assets/node_addr.txt` 
- `Run` -> `Start Debugging`


