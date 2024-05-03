cd mycelios

NAME="mycelios"
HEADERPATH="out/${NAME}FFI.h"
TARGETDIR="target"
OUTDIR="../myceliosframework"
RELDIR="release"
STATIC_LIB_NAME="lib${NAME}.a"
NEW_HEADER_DIR="out/include"

cargo build
cargo run --bin uniffi-bindgen generate --library target/debug/lib${NAME}.dylib --language swift --out-dir out

cargo build --target aarch64-apple-ios-sim --release
cargo build --target aarch64-apple-ios --release

mkdir -p "${NEW_HEADER_DIR}"
cp "${HEADERPATH}" "${NEW_HEADER_DIR}/"
cp "out/${NAME}FFI.modulemap" "${NEW_HEADER_DIR}/module.modulemap"

rm -rf "${OUTDIR}/${NAME}.xcframework"

xcodebuild -create-xcframework \
    -library "${TARGETDIR}/aarch64-apple-ios-sim/${RELDIR}/${STATIC_LIB_NAME}" \
    -headers "${NEW_HEADER_DIR}" \
     -library "${TARGETDIR}/aarch64-apple-ios/${RELDIR}/${STATIC_LIB_NAME}" \
    -headers "${NEW_HEADER_DIR}" \
    -output "${OUTDIR}/${NAME}.xcframework"

rm -rf "${NEW_HEADER_DIR}"