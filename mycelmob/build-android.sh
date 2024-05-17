cargo build

# android
cargo install cargo-ndk
rustup target add \
        aarch64-linux-android \
        armv7-linux-androideabi \
        i686-linux-android \
        x86_64-linux-android

cargo ndk -o ../android/app/src/main/jniLibs \
        --manifest-path ./Cargo.toml \
        -t armeabi-v7a \
        -t arm64-v8a \
        -t x86 \
        -t x86_64 \
        build --release

# libmycelmob.dylib was produced by `cargo build` step
cargo run --bin uniffi-bindgen generate --library ./target/debug/libmycelmob.dylib --language kotlin\
         --out-dir ../android/app/src/main/kotlin/tech/threefold/mycelium/rust

# the generated kotlin file doesn't have proper package name, we need to fix it
sed -i '' 's/package uniffi.mycelmob/package tech.threefold.mycelium.rust.uniffi.mycelmob/g' \
        ../android/app/src/main/kotlin/tech/threefold/mycelium/rust/uniffi/mycelmob/*.kt
