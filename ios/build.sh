#!/bin/bash

########################################
# EDIT this section to Select Versions #
########################################

LIBPNG_VERSION="16"

IOS_SDK_VERSION=""
IOS_MIN_SDK_VERSION="12.0"

catalyst="0"
NOBITCODE="yes"

export BASE_DIR="/Users/perry/Development/libpng"

#Where buidling data are put
export BUILD_DIR="${BASE_DIR}/build"

export OUTPUT_DIR="${BASE_DIR}/install"

########################################
# Build helper method

buildIOS()
{
    ARCH=$1
    BITCODE=$2

    pushd . > /dev/null	
    
    PLATFORM="iPhoneOS"
    PLATFORMDIR="iOS"

    echo "Current dir $(pwd)"
	
    if [[ "${BITCODE}" == "nobitcode" ]]; then
        CC_BITCODE_FLAG=""
    else
        CC_BITCODE_FLAG="-fembed-bitcode"
    fi

	rm -rf "srcbuild-${ARCH}-${PLATFORMDIR}"	
	mkdir -p "srcbuild-${ARCH}-${PLATFORMDIR}"
	cd "srcbuild-${ARCH}-${PLATFORMDIR}"

    #export $PLATFORM
    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"
    #export CC="${BUILD_TOOLS}/usr/bin/gcc"
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG} -DPNG_ARM_NEON=1 -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto"
    export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"
    export CXXFLAGS="${CFLAGS} -std=c++17"

    echo "Building libpng${LIBPNG_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH} ${BITCODE}"


    INSTALL_DIR="${BUILD_DIR}/${LIBPNG_VERSION}-${PLATFORMDIR}-${ARCH}"

    
    ../configure -prefix="${INSTALL_DIR}" \
        --enable-static=yes --enable-shared=no \
        --disable-tools \
        --host="arm-apple-darwin"
    
    make -j8 >> "/tmp/libpng${LIBPNG_VERSION}-${PLATFORM}-${ARCH}-${BITCODE}.log" 2>&1
    make install-strip >> "/tmp/libpng${LIBPNG_VERSION}-${PLATFORM}-${ARCH}-${BITCODE}.log" 2>&1
    make clean >> "/tmp/libpng${LIBPNG_VERSION}-${PLATFORM}-${ARCH}-${BITCODE}.log" 2>&1

    popd > /dev/null
	
}

buildIOSsim()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	#cd "${SRC_DIR}"

	PLATFORM="iPhoneSimulator"
	PLATFORMDIR="iOS-simulator"

    HOST="${ARCH}-apple-darwin"
	if [[ "${ARCH}" == *"arm64"* || "${ARCH}" == "arm64e" ]]; then
		HOST="arm-apple-darwin"
	fi

	if [[ "${BITCODE}" == "nobitcode" ]]; then
        CC_BITCODE_FLAG=""
    else
        CC_BITCODE_FLAG="-fembed-bitcode"
    fi

	RUNTARGET=""	
	if [[ $ARCH != "i386" ]]; then
		RUNTARGET="-target ${ARCH}-apple-ios${IOS_MIN_SDK_VERSION}-simulator"
	fi


	rm -rf "srcbuild-${ARCH}-${PLATFORMDIR}"	
	mkdir -p "srcbuild-${ARCH}-${PLATFORMDIR}"
	cd "srcbuild-${ARCH}-${PLATFORMDIR}"

    #export $PLATFORM
    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"
    #export CC="${BUILD_TOOLS}/usr/bin/gcc"
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG} ${RUNTARGET} -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto"
    export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"
    export CXXFLAGS="${CFLAGS} -std=c++17"

    echo "Building libpng${LIBPNG_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH} ${BITCODE}"


    INSTALL_DIR="${BUILD_DIR}/${LIBPNG_VERSION}-${PLATFORMDIR}-${ARCH}"

    
    ../configure -prefix="${INSTALL_DIR}" \
        --enable-static=yes --enable-shared=no \
        --disable-tools \
        --host=${HOST}
    
    make -j8 >> "/tmp/libpng${LIBPNG_VERSION}-${PLATFORM}-${ARCH}-${BITCODE}.log" 2>&1
    make install-strip >> "/tmp/libpng${LIBPNG_VERSION}-${PLATFORM}-${ARCH}-${BITCODE}.log" 2>&1
    make clean >> "/tmp/libpng${LIBPNG_VERSION}-${PLATFORM}-${ARCH}-${BITCODE}.log" 2>&1

    popd > /dev/null	
	
}

########################################

echo
echo "Building LibPNG libpng${LIBPNG_VERSION}"

set -e

mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

# set trap to help debug any build errors
trap 'echo "** ERROR with Build - Check ${BUILD_DIR}/libpng*.log"; tail ${BUILD_DIR}/libpng*.log' INT TERM EXIT



DEVELOPER="$(xcode-select --print-path)"

cd ${BASE_DIR}

#====================================================================== 
## Run
#====================================================================== 

echo "Cleaning up"
rm -rf ${OUTPUT_DIR}/include/*
rm -rf ${OUTPUT_DIR}/lib/*

mkdir -p "${OUTPUT_DIR}/lib"
mkdir -p "${OUTPUT_DIR}/include"



if [ ! -e "libpng${LIBPNG_VERSION}.zip" ]; then
    echo "Downloading libpng${LIBPNG_VERSION}.zip"
    #curl -LO https://github.com/glennrp/libpng/archive/v${LIBPNG_VERSION}.zip
    curl -LO https://github.com/pnggroup/libpng/archive/refs/heads/libpng${LIBPNG_VERSION}.zip

    echo "Unpacking libpng"
    unzip -q "libpng${LIBPNG_VERSION}.zip"

else
    echo "Using libpng${LIBPNG_VERSION}.zip"
fi


if ! [[ "${NOBITCODE}" == "yes" ]]; then
	BITCODE="bitcode"
else
	BITCODE="nobitcode"
fi

#================

cd "${BASE_DIR}/libpng-libpng${LIBPNG_VERSION}"
#./autogen.sh


echo "Building iOS libraries (${BITCODE})"

buildIOS "arm64" ${BITCODE}
buildIOS "arm64e" ${BITCODE}

lipo \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-arm64/lib/libpng.a" \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-arm64e/lib/libpng.a" \
    -create -output "${OUTPUT_DIR}/lib/libpng_${LIBPNG_VERSION}_iOS.a"


buildIOSsim "x86_64" ${BITCODE}
buildIOSsim "arm64" ${BITCODE}

lipo \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-simulator-x86_64/lib/libpng.a" \
    "${BUILD_DIR}/${LIBPNG_VERSION}-iOS-simulator-arm64/lib/libpng.a" \
    -create -output "${OUTPUT_DIR}/lib/libpng_${LIBPNG_VERSION}_iOS_simulator.a"

echo "  Copying headers"
cp ${BUILD_DIR}/${LIBPNG_VERSION}-iOS-arm64/include/*.h "${OUTPUT_DIR}/include/"

#=================================================================================
# Finalize
#=================================================================================

echo "Checking libraries"
xcrun -sdk iphoneos lipo -info ${OUTPUT_DIR}/lib/*.a

#reset trap
trap - INT TERM EXIT

