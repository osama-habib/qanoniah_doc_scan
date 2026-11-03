#!/usr/bin/env bash
# Builds ios/qanoniah_doc_scan/Frameworks/CTesseract.xcframework from the official Tesseract and
# Leptonica sources, for iOS devices and Apple-silicon simulators (arm64).
#
# Used on iOS when Apple Vision cannot read Arabic (iOS 15 to 17), owner decision
# 2026-11-03. Reproducible: rerun to rebuild or to bump a version below.
#
# Leptonica is built with every image codec off: the plugin hands Tesseract raw
# grayscale pixels, so no image file is ever decoded by these libraries.
#
# Usage: bash tool/build_ios_tesseract.sh
set -euo pipefail

TESSERACT_VERSION="5.5.3"
LEPTONICA_VERSION="1.86.0"
MIN_IOS="15.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/tool/.build/tesseract"
OUT="$ROOT/ios/qanoniah_doc_scan/Frameworks/CTesseract.xcframework"
mkdir -p "$WORK"
cd "$WORK"

fetch() { # url dir
  if [ ! -d "$2" ]; then
    curl -sSfL "$1" -o "$2.tar.gz"
    mkdir "$2" && tar -xzf "$2.tar.gz" -C "$2" --strip-components 1
  fi
}
fetch "https://github.com/DanBloomberg/leptonica/archive/refs/tags/$LEPTONICA_VERSION.tar.gz" leptonica
fetch "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/$TESSERACT_VERSION.tar.gz" tesseract

build() { # sdk
  local sdk="$1" prefix="$WORK/install-$1"
  local common=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_SYSTEM_NAME=iOS
    -DCMAKE_OSX_SYSROOT="$sdk"
    -DCMAKE_OSX_ARCHITECTURES=arm64
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS"
    -DCMAKE_INSTALL_PREFIX="$prefix"
    -DCMAKE_PREFIX_PATH="$prefix"
    -DCMAKE_FIND_ROOT_PATH="$prefix"
    -DBUILD_SHARED_LIBS=OFF
    -DSW_BUILD=OFF
  )
  cmake -S leptonica -B "lept-$sdk" "${common[@]}" \
    -DBUILD_PROG=OFF -DENABLE_ZLIB=OFF -DENABLE_PNG=OFF -DENABLE_GIF=OFF -DENABLE_JPEG=OFF \
    -DENABLE_TIFF=OFF -DENABLE_WEBP=OFF -DENABLE_OPENJPEG=OFF >/dev/null
  cmake --build "lept-$sdk" --target install >/dev/null

  cmake -S tesseract -B "tess-$sdk" "${common[@]}" \
    -DLeptonica_DIR="$prefix/lib/cmake/leptonica" \
    -DBUILD_TRAINING_TOOLS=OFF -DBUILD_TESTS=OFF -DGRAPHICS_DISABLED=ON \
    -DDISABLED_LEGACY_ENGINE=ON -DDISABLE_ARCHIVE=ON -DDISABLE_CURL=ON \
    -DOPENMP_BUILD=OFF -DENABLE_LTO=OFF -DINSTALL_CONFIGS=OFF \
    -DLEPT_TIFF_RESULT=1 -DLEPT_TIFF_RESULT__TRYRUN_OUTPUT="" >/dev/null
  cmake --build "tess-$sdk" --target install >/dev/null

  # One static library per platform.
  libtool -static -o "$WORK/libctesseract-$sdk.a" \
    "$(find "$prefix/lib" -name 'libtesseract*.a' | head -1)" \
    "$(find "$prefix/lib" -name 'libleptonica*.a' | head -1)"
}
build iphoneos
build iphonesimulator

HEADERS="$WORK/headers"
rm -rf "$HEADERS" && mkdir -p "$HEADERS"
# The C API only: capi.h includes "export.h" beside it; its C++ includes sit
# behind __cplusplus and are never read from Swift.
cp "$WORK/install-iphoneos/include/tesseract/"{capi.h,export.h,version.h} "$HEADERS/"
cat > "$HEADERS/module.modulemap" <<'EOF'
module CTesseract {
  header "capi.h"
  link "c++"
  export *
}
EOF

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
xcodebuild -create-xcframework \
  -library "$WORK/libctesseract-iphoneos.a" -headers "$HEADERS" \
  -library "$WORK/libctesseract-iphonesimulator.a" -headers "$HEADERS" \
  -output "$OUT" >/dev/null
echo "Built $OUT (Tesseract $TESSERACT_VERSION, Leptonica $LEPTONICA_VERSION)"
du -sh "$OUT"
