#!/bin/bash

########################################
# EDIT this section to Select Versions #
########################################

LIBPNG_VERSION="1.6.28"

IOS_SDK_VERSION=""
IOS_MIN_SDK_VERSION="9.0"
IPHONEOS_DEPLOYMENT_TARGET="6.0"

########################################
# Build helper method

buildIOS()
{
ARCH=$1
BITCODE=$2

pushd . > /dev/null
cd "${SRC_DIR}"


if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
    PLATFORM="iPhoneSimulator"
else
    PLATFORM="iPhoneOS"
fi

if [[ "${BITCODE}" == "nobitcode" ]]; then
    CC_BITCODE_FLAG=""
else
    CC_BITCODE_FLAG="-fembed-bitcode"
fi


#export $PLATFORM
export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
export BUILD_TOOLS="${DEVELOPER}"
#export CC="${BUILD_TOOLS}/usr/bin/gcc"
export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG} -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto"
export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -Wl,-s"
export CXXFLAGS="${CFLAGS} -std=c++14"

echo "Building ${LIBPNG_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH} ${BITCODE}"


INSTALL_DIR="${BUILD_DIR}/${LIBPNG_VERSION}-iOS-${ARCH}-${BITCODE}"


if [[ "${ARCH}" == "arm64" ]]; then
    ./configure -prefix="${INSTALL_DIR}" \
        --enable-arm-neon=yes \
        --enable-static=yes --enable-shared=no \
        --host="arm-apple-darwin" &> "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-${ARCH}-${BITCODE}_configure.log"
else
    ./configure -prefix="${INSTALL_DIR}" \
        --enable-static=yes --enable-shared=no \
        --host="${ARCH}-apple-darwin" &> "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-${ARCH}-${BITCODE}_configure.log"
fi

make -j8 >> "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-${ARCH}-${BITCODE}_make.log" 2>&1
make install-strip >> "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-${ARCH}-${BITCODE}_make_install.log" 2>&1
make clean >> "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-${ARCH}-${BITCODE}_make_clean.log" 2>&1

popd > /dev/null
}

########################################

echo
echo "Building LibPNG ${LIBPNG_VERSION}"

set -e

BUILD_DIR="${PWD}/build"
OUTPUT_DIR="${PWD}"
SRC_DIR="${PWD}/libpng-${LIBPNG_VERSION}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${SRC_DIR}"

# set trap to help debug any build errors
trap 'echo "** ERROR with Build - Check ${BUILD_DIR}/libpng*.log"; tail ${BUILD_DIR}/libpng*.log' INT TERM EXIT



DEVELOPER="$(xcode-select --print-path)"


echo "Cleaning up"
rm -rf ${OUTPUT_DIR}/include/*
rm -rf ${OUTPUT_DIR}/lib/*

mkdir -p "${OUTPUT_DIR}/lib"
mkdir -p "${OUTPUT_DIR}/include"

rm -rf ${BUILD_DIR}/${LIBPNG_VERSION}-*
rm -rf ${BUILD_DIR}/${LIBPNG_VERSION}-*.log

rm -rf "${SRC_DIR}"

if [ ! -e "v${LIBPNG_VERSION}.zip" ]; then
    echo "Downloading v${LIBPNG_VERSION}.zip"
    curl -LO https://github.com/glennrp/libpng/archive/v${LIBPNG_VERSION}.zip
else
    echo "Using v${LIBPNG_VERSION}.zip"
fi

echo "Unpacking libpng"
unzip -q "v${LIBPNG_VERSION}.zip"

cd "${SRC_DIR}"
./autogen.sh


echo "Building iOS libraries (bitcode)"
buildIOS "armv7" "bitcode"
buildIOS "armv7s" "bitcode"
buildIOS "arm64" "bitcode"
buildIOS "x86_64" "bitcode"
buildIOS "i386" "bitcode"



lipo \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-armv7-bitcode/lib/libpng.a" \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-armv7s-bitcode/lib/libpng.a" \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-i386-bitcode/lib/libpng.a" \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-arm64-bitcode/lib/libpng.a" \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-x86_64-bitcode/lib/libpng.a" \
    -create -output "${OUTPUT_DIR}/lib/libpng_${LIBPNG_VERSION}_iOS.a"

cp ${BUILD_DIR}/${LIBPNG_VERSION}-iOS-i386-bitcode/include/*.h "${OUTPUT_DIR}/include/"

echo "Checking libraries"
xcrun -sdk iphoneos lipo -info ${OUTPUT_DIR}/lib/*.a

#reset trap
trap - INT TERM EXIT

