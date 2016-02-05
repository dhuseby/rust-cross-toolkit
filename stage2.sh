#!/usr/bin/env bash

if [[ $# -lt 3 ]]; then
  echo "Usage: stage2.sh <target> <arch> <compiler>"
  echo "    target    -- 'bitrig', 'netbsd', etc"
  echo "    arch      -- 'x86_64', 'i686', 'armv7', etc"
  echo "    compiler  -- 'gcc' or 'clang'"
  exit 1
fi

set -x
HOST=`uname -s | tr '[:upper:]' '[:lower:]'`
TARGET=$1
ARCH=$2
COMP=$3
STAGE=${0#*/}
STAGE=${STAGE%%.sh}

check(){
  if [ ${HOST} != "linux" ]; then
    echo "You have to run this on Linux!"
    exit 1
  fi

  if [ ! -e "stage1" ]; then
    echo "stage1 does not exist!"
    exit 1
  fi

  if [ ! -e "stage1/install" ]; then
    echo "stage1/install does not exist!"
    exit 1
  fi

  if [ ! -e "stage1/libs" ]; then
    echo "need stage1/libs from Bitrig!"
    exit 1
  fi
}

setup(){
  echo "Creating stage2"
  mkdir -p stage2
  cd stage2
  TOP=`pwd`
  mkdir -p rust-libs
  RUST_PREFIX=${TOP}/../stage1/install
  RUST_SRC=${TOP}/rust
  RUSTC=${RUST_PREFIX}/bin/rustc
  DF_LIB_DIR=${TOP}/../stage1/libs
  RS_LIB_DIR=${TOP}/rust-libs
}

clone(){
  if [ ! -e rust ]; then
    # clone everything
    cd ${TOP}
    REV=`cat ${TOP}/../stage1/revision.id`
    echo "cloning at the revision used in stage1: ${REV}"
    git scclone https://github.com/rust-lang/rust.git rust ${REV}
    cd rust
    echo "initializing submodules"
    git submodule init
    git submodule update
  else
    # update everything
    cd ${TOP}/rust
    #git pull origin
    #git submodule update --merge
    #rm -rf ${RS_LIB_DIR}/*
  fi
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
}

patch_src(){
  cd ${TOP}/${1}
  ID=`git rev-parse --short HEAD`
  PATCH=${TOP}/../patches/${2}_${ID}_${STAGE}_${TARGET}_${ARCH}.patch
  if [ ! -e ${PATCH} ]; then
    PATCH=${TOP}/../patches/${2}_${ID}_${STAGE}_${TARGET}.patch
  fi
  if [ ! -e ${PATCH} ]; then
    PATCH=${TOP}/../patches/${2}_${ID}_${STAGE}.patch
  fi
  if [ ! -e ${PATCH} ]; then
    PATCH=${TOP}/../patches/${2}_${ID}_${TARGET}_${ARCH}.patch
  fi
  if [ ! -e ${PATCH} ]; then
    PATCH=${TOP}/../patches/${2}_${ID}_${TARGET}.patch
  fi
  if [ ! -e ${PATCH} ]; then
    PATCH=${TOP}/../patches/${2}_${ID}.patch
  fi

  if [ -e ${PATCH} ]; then
    if [ ! -e .patched ]; then
      echo "Patching ${TOP}/${1} with ${PATCH}"
      patch -p1 < ${PATCH}
      if (( $? )); then
        echo "Failed to patch ${1}"
        exit 1
      fi
      date > .patched
    else
      echo "${1} already patched on:" `cat .patched`
    fi
  else
    echo "no patches for ${1}"
  fi
}

apply_patches(){
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch src rust/src/compiler-rt compiler-rt
  patch_src rust/src/rt/hoedown hoedown
  patch_src rust/src/jemalloc jemalloc
  patch_src rust/src/rust-installer rust-installer
  patch_src rust/src/liblibc liblibc
}

### LINUX FUNCTIONS ###

linux_configure_clang(){
  export CC="/usr/bin/clang"
  export CXX="/usr/bin/clang++"
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -fomit-frame-pointer -fPIC -O2"
  export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual -v -O2"
  export LDFLAGS="-stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"
}

linux_configure_gcc(){
  export CC="/usr/bin/gcc"
  export CXX="/usr/bin/g++"
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -fomit-frame-pointer -fPIC -O0 -gstabs+"
  export CXXFLAGS="-mstackrealign -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual -v -O0 -gstabs+"
  export LDFLAGS="-lc -lpthread -lffi -ltinfo -ldl -lm"
}

linux_build(){
  cd ${TOP}/../stage1/rust
  export CFG_VER_HASH=`git rev-parse HEAD`
  cd ${TOP}
  export CFG_VERSION="1.3.0-dev"
  export CFG_RELEASE="${TARGET}-cross"
  export CFG_VER_DATE="`date`"
  export CFG_COMPILER_HOST_TRIPLE="${ARCH}-unknown-${TARGET}"
  export CFG_PREFIX="${TOP}/../stage1/install"
  export CFG_LLVM_LINKAGE_FILE="${TOP}/rust/src/librustc_llvm/llvmdeps.rs"
  #export RUST_FLAGS="-g -Z verbose"
  #export RUST_FLAGS="--cfg stage0  -O --cfg rtopt -C debug-assertions=on -g -C rpath -C prefer-dynamic -C no-stack-check -Z verbose"
  #export RUST_FLAGS="-O --cfg rtopt -g -C rpath -C prefer-dynamic -C no-stack-check -Z verbose"
  export RUST_FLAGS="-g -C rpath -C prefer-dynamic -C no-stack-check -Z verbose"
  RUST_LIBS="core libc rustc_unicode alloc collections rand std alloc_system arena log fmt_macros serialize term syntax syntax_ext flate getopts test coretest graphviz rustc_llvm rustc_front rustc_back rbml rustc_data_structures rustc rustc_bitflags rustc_lint rustc_privacy rustc_resolve rustc_mir rustc_platform_intrinsics rustc_trans rustc_typeck rustc_borrowck rustc_metadata rustc_plugin rustc_driver rustdoc"

  # compile rust libraries
  for lib in $RUST_LIBS; do
    if [ -e ${RS_LIB_DIR}/lib${lib}.rlib ]; then
      echo "skipping $lib"
    else
      echo "compiling $lib"
      if [ ${lib} != "libc" ]; then
        LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
        ${RUSTC} --target ${CFG_COMPILER_HOST_TRIPLE} ${RUST_FLAGS} --crate-type lib -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
        if (( $? )); then
          echo "Failed to compile ${RS_LIB_DIR}/lib${lib}.rlib"
          exit 1
        fi
      else
        LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
        ${RUSTC} --target ${CFG_COMPILER_HOST_TRIPLE} ${RUST_FLAGS} --cfg stdbuild -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/src/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
        #i686-unknown-freebsd/stage0/bin/rustc --cfg stage0  -O --cfg rtopt -C debug-assertions=on -g -C rpath -C prefer-dynamic -C no-stack-check --target=i686-unknown-freebsd   -L "i686-unknown-freebsd/rt" -L native="/opt/rust/build/i686-unknown-freebsd/llvm/Release+Asserts/lib"  --cfg stdbuild   --out-dir i686-unknown-freebsd/stage0/lib/rustlib/i686-unknown-freebsd/lib -C extra-filename=-db5a760f ../src/liblibc/src/lib.rs
        if (( $? )); then
          echo "Failed to compile ${RS_LIB_DIR}/lib${lib}.rlib"
          exit 1
        fi
      fi
    fi
  done

  LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
    ${RUSTC} ${RUST_FLAGS} --emit obj -o ${TOP}/driver.o --target ${CFG_COMPILER_HOST_TRIPLE} -L${DF_LIB_DIR} -L${RS_LIB_DIR} --cfg rustc ${RUST_SRC}/src/driver/driver.rs

  if (( $? )); then
    echo "Failed to compile ${RUST_SRC}/src/driver/driver.rs"
    exit 1
  fi

  cd ${TOP}/..
  tar cvzf stage2.tgz stage2/*.o stage2/rust-libs

  echo "Please copy stage2.tgz onto your ${TARGET} machine and extract it"
}

linux(){
  setup
  clone
  apply_patches
  linux_configure_${COMP}
  linux_build
}

check
MAKE=make
linux

