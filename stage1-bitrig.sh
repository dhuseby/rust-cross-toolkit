#!/bin/sh
set -x

if [ `uname -s` != "Bitrig" ]; then
  echo "You have to run this on Bitrig!"
  exit 1
fi

mkdir -p stage1-bitrig
cd stage1-bitrig

TOP=`pwd`

AUTOCONF_VERSION=2.68

TARGET_SUB=libs
TARGET=${TOP}/${TARGET_SUB}
ARCH=`machine -a`
RUSTARCH=${ARCH}
if [ "${ARCH}" -eq "amd64" ]; then
  RUSTARCH="x86_64"
fi

export CFLAGS="-O3 -pipe -fvisibility=hidden"
export CXXFLAGS="-O3 -fvisibility=hidden -fvisibility-inlines-hidden"
export LDFLAGS="-L/usr/local/lib"
LLVM_TARGET="/usr/local"

mkdir -p ${TARGET}

echo "-- TOP:         ${TOP}"
echo "-- TARGET:      ${TARGET}"
echo "-- LLVM_TARGET: ${LLVM_TARGET}"
echo "-- ARCH:        ${ARCH}"
echo "-- RUSTARCH:    ${RUSTARCH}"

if [ ! -e rust ]; then
  git clone https://github.com/dhuseby/rust.git
fi
cd rust
git submodule init
git submodule update
cd src
mkdir -p llvm-build
cd llvm-build
../llvm/configure --prefix=${LLVM_TARGET} #--disable-compiler-version-checks
gmake VERBOSE=1 ENABLE_OPTIMIZED=1

exit 1
gmake VERBOSE=1 ENABLE_OPTIMIZED=1 install

mkdir -p ${TARGET}/llvm
cp `${LLVM_TARGET}/bin/llvm-config --libfiles` ${TARGET}/llvm

cd ${TOP}/rust/src/rustllvm
${CXX} -c `${LLVM_TARGET}/bin/llvm-config --cxxflags` PassWrapper.cpp
${CXX} -c `${LLVM_TARGET}/bin/llvm-config --cxxflags` RustWrapper.cpp
ar rcs librustllvm.a PassWrapper.o RustWrapper.o	
cp librustllvm.a ${TARGET}

# build libcompiler-rt.a
cd ${TOP}/rust/src/compiler-rt
cmake -DLLVM_CONFIG_PATH=${LLVM_TARGET}/bin/llvm-config
gmake VERBOSE=1
cp ./lib/openbsd/libclang_rt.${ARCH}.a ${TARGET}/libcompiler-rt.a


cd ${TOP}/rust/src
ln -s libbacktrace include
cd libbacktrace
./configure
gmake VERBOSE=1
cp .libs/libbacktrace.a ${TARGET}
cd ..
rm -rf include

set -x
cd ${TOP}/rust/src/rt
${LLVM_TARGET}/bin/llc rust_try.ll
#${CC} -c -o rust_try.o rust_try.s
#${CC} -c -o record_sp.o arch/${RUSTARCH}/record_sp.S
${AS} -o rust_try.o rust_try.s
${AS} -o record_sp.o arch/${RUSTARCH}/record_sp.S
ar rcs ${TARGET}/librustrt_native.a rust_try.o record_sp.o

cd ${TOP}/rust/src/rt
${CC} -c -o context.o arch/${RUSTARCH}/_context.S
#${AS} -o context.o arch/${RUSTARCH}/_context.S
ar rcs ${TARGET}/libcontext_switch.a context.o

cd ${TOP}/rust/src/rt
${CC} -c -o rust_builtin.o rust_builtin.c
ar rcs ${TARGET}/librust_builtin.a rust_builtin.o 

cd ${TOP}/rust/src/rt
${CC} -c -o morestack.o arch/${RUSTARCH}/morestack.S
#${AS} -o morestack.o arch/${RUSTARCH}/morestack.S
ar rcs ${TARGET}/libmorestack.a morestack.o

cd ${TOP}/rust/src/rt
${CC} -c -o miniz.o miniz.c
ar rcs ${TARGET}/libminiz.a miniz.o 
set +x

cd ${TOP}/rust/src/rt/hoedown
gmake VERBOSE=1 libhoedown.a 
cp libhoedown.a ${TARGET}

# Copy Openbsd system libraries

mkdir -p ${TARGET}/usr/lib
cp -r /usr/lib ${TARGET}/usr/lib

# 
cd ${TOP}/..
#python ${TOP}/rust/src/etc/mklldeps.py stage1-openbsd/llvmdeps.rs "x86 arm mips ipo bitreader bitwriter linker asmparser jit mcjit interpreter instrumentation" true "${LLVM_TARGET}/bin/llvm-config"
python ${TOP}/rust/src/etc/mklldeps.py stage1-openbsd/llvmdeps.rs "x86 arm mips ipo bitreader bitwriter linker asmparser mcjit interpreter instrumentation" true "${LLVM_TARGET}/bin/llvm-config"

cd ${TOP}/..
tar cvzf stage1-openbsd.tgz stage1-openbsd/${TARGET_SUB} stage1-openbsd/llvmdeps.rs



echo "Please copy stage1-openbsd.tgz onto your Linux machine and extract it"
