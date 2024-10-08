NAME="mycelmob"
HEADERPATH="outmac/${NAME}FFI.h"
TARGETDIR="target"
OUTDIR="outmac/macframework"
RELDIR="release"
STATIC_LIB_NAME="lib${NAME}.a"
NEW_HEADER_DIR="outmac/include"
UNIVERSAL_LIB_NAME="lib${NAME}_universal.a"

cargo build
cargo run --bin uniffi-bindgen generate --library target/debug/lib${NAME}.dylib --language swift --out-dir outmac

rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin

MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --target aarch64-apple-darwin --release
MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --target x86_64-apple-darwin --release

# creates headers directory
mkdir -p "${NEW_HEADER_DIR}"
cp "${HEADERPATH}" "${NEW_HEADER_DIR}/"
cp "outmac/${NAME}FFI.modulemap" "${NEW_HEADER_DIR}/module.modulemap"

# combine the libs using lipo
lipo -create -output "${TARGETDIR}/${UNIVERSAL_LIB_NAME}" \
    "${TARGETDIR}/aarch64-apple-darwin/${RELDIR}/${STATIC_LIB_NAME}" \
    "${TARGETDIR}/x86_64-apple-darwin/${RELDIR}/${STATIC_LIB_NAME}"

# delete old xcframework
rm -rf "${OUTDIR}/${NAME}.xcframework"

# creates xcframework from the universal library
MACOSX_DEPLOYMENT_TARGET=12.0 xcodebuild -create-xcframework \
    -library "${TARGETDIR}/${UNIVERSAL_LIB_NAME}" -headers "${NEW_HEADER_DIR}" \
    -output "${OUTDIR}/${NAME}.xcframework"

# for debugging
ls -l outmac/macframework

# remove the temporary directory
rm -rf "${NEW_HEADER_DIR}"

# create empty dll, because only Windoes need it
mkdir -p ../assets/dll
echo "" > ../assets/dll/winmycelium.dll