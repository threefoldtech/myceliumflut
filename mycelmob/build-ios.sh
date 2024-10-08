NAME="mycelmob"
HEADERPATH="out/${NAME}FFI.h"
TARGETDIR="target"
OUTDIR="out/iosframework"
RELDIR="release"
STATIC_LIB_NAME="lib${NAME}.a"
NEW_HEADER_DIR="out/include"

cargo build
cargo run --bin uniffi-bindgen generate --library target/debug/lib${NAME}.dylib --language swift --out-dir out

rustup target add aarch64-apple-ios-sim
rustup target add aarch64-apple-ios

IPHONEOS_DEPLOYMENT_TARGET=12.0 cargo build --target aarch64-apple-ios-sim --release
IPHONEOS_DEPLOYMENT_TARGET=12.0 cargo build --target aarch64-apple-ios --release

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