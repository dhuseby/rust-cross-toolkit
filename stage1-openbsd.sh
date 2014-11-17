#!/bin/sh

if [ `uname -s` != "OpenBSD" ]; then
  echo "You have to run this on OpenBSD!"
  exit 1
fi

mkdir -p stage1-openbsd
cd stage1-openbsd

TOP=`pwd`

AUTOMAKE_VERSION=1.14
BINUTILS_VERSION=2.24

TARGET_SUB=libs
TARGET=${TOP}/${TARGET_SUB}
ARCH=`machine -a`
RUSTARCH=${ARCH}
if [ "${ARCH}" -eq "amd64" ]; then
  RUSTARCH="x86_64"
fi

export AS="/usr/local/bin/egcc-as"
export LD="/usr/local/bin/egcc-ld"
export CC="/usr/local/bin/egcc"
export CXX="/usr/local/bin/eg++"
export LDFLAGS="-L/usr/local/lib"
export CFLAGS="-I/usr/local/include"
export CXXFLAGS="-I/usr/local/include/c++/4.8.3/"
#export AR="/usr/local/bin/egcc-ar"
#export NM="/usr/local/bin/egcc-nm"
#export RANLIB="/usr/local/bin/egcc-ranlib"
LLVM_TARGET="/usr/local"

mkdir -p ${TARGET}

echo "-- TOP:         ${TOP}"
echo "-- TARGET:      ${TARGET}"
echo "-- LLVM_TARGET: ${LLVM_TARGET}"
echo "-- ARCH:        ${ARCH}"
echo "-- RUSTARCH:    ${RUSTARCH}"

if [ ! -d binutils-${BINUTILS_VERSION} ]; then
  curl ftp://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.bz2 | tar -jxvf -
fi
cd binutils-${BINUTILS_VERSION}
./configure --prefix=${LLVM_TARGET} --program-prefix=egcc-
gmake VERBOSE=1
gmake VERBOSE=1 install
cd ${TOP}

if [ ! -d rust ]; then
  git clone https://github.com/rust-lang/rust.git
fi
cd rust
git submodule init
git submodule update
if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-rust
  date > .patched
else
  echo "Rust already patched on:" `cat .patched`
fi
cd src/jemalloc
if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-jemalloc
  date > .patched
else
  echo "jemalloc already patched on:" `cat .patched`
fi
cd ../llvm
if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-llvm
  date > .patched
else
  echo "LLVM already patched on:" `cat .patched`
fi
cd ..
mkdir -p llvm-build
cd llvm-build
../llvm/configure --prefix=${LLVM_TARGET} #--disable-compiler-version-checks
gmake VERBOSE=1 ENABLE_OPTIMIZED=1
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
${CC} -c -o rust_try.o rust_try.s
${CC} -c -o record_sp.o arch/${RUSTARCH}/record_sp.S
ar rcs ${TARGET}/librustrt_native.a rust_try.o record_sp.o

cd ${TOP}/rust/src/rt
${CC} -c -o context.o arch/${RUSTARCH}/_context.S
ar rcs ${TARGET}/libcontext_switch.a context.o

cd ${TOP}/rust/src/rt
${CC} -c -o rust_builtin.o rust_builtin.c
ar rcs ${TARGET}/librust_builtin.a rust_builtin.o 

cd ${TOP}/rust/src/rt
${CC} -c -o morestack.o arch/${RUSTARCH}/morestack.S
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
