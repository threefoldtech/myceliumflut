#!/bin/bash
set -e

NAME="mycelmob"
HEADERPATH="out/${NAME}FFI.h"
TARGETDIR="target"
OUTDIR="out/iosframework"
RELDIR="release"
STATIC_LIB_NAME="lib${NAME}.a"
NEW_HEADER_DIR="out/include"

# Set up iOS development environment
export IPHONEOS_DEPLOYMENT_TARGET=12.0

# Get SDK paths
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

# Set up environment for iOS builds
export SDKROOT="$IPHONEOS_SDK"
export CC_aarch64_apple_ios="$(xcrun --sdk iphoneos --find clang)"
export CXX_aarch64_apple_ios="$(xcrun --sdk iphoneos --find clang++)"
export AR_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ar)"

# Set up environment for iOS Simulator builds  
export CC_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find clang)"
export CXX_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find clang++)"
export AR_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find ar)"

# Set CFLAGS for both targets
export CFLAGS_aarch64_apple_ios="-isysroot $IPHONEOS_SDK -mios-version-min=12.0"
export CFLAGS_aarch64_apple_ios_sim="-isysroot $IPHONESIMULATOR_SDK -mios-simulator-version-min=12.0"

# Set BINDGEN_EXTRA_CLANG_ARGS for both targets to help bindgen find system headers
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios="-isysroot $IPHONEOS_SDK -mios-version-min=12.0 -target aarch64-apple-ios"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim="-isysroot $IPHONESIMULATOR_SDK -mios-simulator-version-min=12.0 -target aarch64-apple-ios-simulator"

# Build for host first
cargo build
cargo run --bin uniffi-bindgen generate --library target/debug/lib${NAME}.dylib --language swift --out-dir out

# Add iOS targets
rustup target add aarch64-apple-ios-sim
rustup target add aarch64-apple-ios

# Build for iOS Simulator with proper SDK
echo "Building for iOS Simulator..."
SDKROOT="$IPHONESIMULATOR_SDK" cargo build --target aarch64-apple-ios-sim --release

# Build for iOS Device with proper SDK
echo "Building for iOS Device..."
SDKROOT="$IPHONEOS_SDK" cargo build --target aarch64-apple-ios --release

mkdir -p "${NEW_HEADER_DIR}"
cp "${HEADERPATH}" "${NEW_HEADER_DIR}/"
cp "out/${NAME}FFI.modulemap" "${NEW_HEADER_DIR}/module.modulemap"

rm -rf "${OUTDIR}/${NAME}.xcframework"

IPHONEOS_DEPLOYMENT_TARGET=12.0 xcodebuild -create-xcframework \
    -library "${TARGETDIR}/aarch64-apple-ios-sim/${RELDIR}/${STATIC_LIB_NAME}" \
    -headers "${NEW_HEADER_DIR}" \
    -library "${TARGETDIR}/aarch64-apple-ios/${RELDIR}/${STATIC_LIB_NAME}" \
    -headers "${NEW_HEADER_DIR}" \
    -output "${OUTDIR}/${NAME}.xcframework"

ls -l out/iosframework

rm -rf "${NEW_HEADER_DIR}"

# create empty dll, because only Windoes need it
mkdir -p ../assets/dll
echo "" > ../assets/dll/winmycelium.dll