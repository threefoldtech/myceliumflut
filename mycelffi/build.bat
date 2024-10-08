@echo off
rustup target add x86_64-pc-windows-msvc
cargo build --target x86_64-pc-windows-msvc --release
copy target\debug\mycelmob.dll ..\assets\dll\winmycelium.dll