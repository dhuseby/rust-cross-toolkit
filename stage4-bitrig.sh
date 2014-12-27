#!/bin/sh
set -x

if [ `uname -s` != "Bitrig" ]; then
  echo "You have to run this on Linux!"
  exit 1
fi

if [ ! -e "stage3-bitrig" ]; then
  echo "stage3-bitrig does not exist!"
  exit 1
fi

mkdir -p stage3.5-bitrig
mkdir -p stage3.5-bitrig/lib
cd stage3.5-bitrig

TOP=`pwd`

RUST_PREFIX=${TOP}/../stage3-bitrig
RUST_SRC=${TOP}/rust
RUSTC=${RUST_PREFIX}/bin/rustc
TARGET=x86_64-unknown-bitrig

DF_LIB_DIR=${TOP}/../stage1-bitrig/libs
RS_LIB_DIR=${TOP}/lib

export LD_LIBRARY_PATH=${RUST_PREFIX}/lib

if [ ! -e rust ]; then
  # clone everything
  git clone --reference ${TOP}/../stage1-bitrig/rust https://github.com/dhuseby/rust.git
  cd rust
  git submodule init
  git submodule update
else
  # update everything
  cd rust
  git pull origin
  git submodule update --merge
  rm -rf ${RS_LIB_DIR}/*
fi

cp ${TOP}/../stage1-bitrig/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/

export CC="/usr/bin/clang"
export CXX="/usr/bin/clang++"
export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fPIC"
export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual -v"
export LDFLAGS="-g -stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"
export CFG_VERSION="0.13.0-dev"
export CFG_RELEASE="bitrig-cross"
export CFG_VER_HASH="hash"
export CFG_VER_DATE="`date`"
export CFG_COMPILER_HOST_TRIPLE="x86_64-unknown-bitrig"
export CFG_PREFIX="/usr/local"
export CFG_LLVM_LINKAGE_FILE="${TOP}/rust/src/librustc_llvm/llvmdeps.rs"
export RUST_FLAGS="-g"

RUST_LIBS="core libc alloc unicode collections rustrt rand std arena regex log fmt_macros serialize term syntax flate time getopts regex test coretest graphviz rustc_back rustc_llvm rbml rustc regex_macros green rustc_trans rustc_typeck rustc_driver rustdoc "

# compile rust libraries
for lib in $RUST_LIBS; do
  if [ -e ${RS_LIB_DIR}/lib${lib}.rlib ]; then
    echo "skipping $lib"
  else
    echo "compiling $lib"
    ${RUSTC} --target ${TARGET} ${RUST_FLAGS} --crate-type lib -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
  fi
done

${RUSTC} ${RUST_FLAGS} --emit obj -o ${TOP}/driver.o --target ${TARGET} -L${DF_LIB_DIR} -L${RS_LIB_DIR} --cfg rustc ${RUST_SRC}/src/driver/driver.rs

