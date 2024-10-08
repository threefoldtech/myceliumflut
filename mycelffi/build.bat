@echo off
rustup target add x86_64-pc-windows-msvc
cargo build --target x86_64-pc-windows-msvc --release
mkdir ..\assets\dll
copy target\x86_64-pc-windows-msvc\release\mycelffi.dll ..\assets\dll\winmycelium.dll