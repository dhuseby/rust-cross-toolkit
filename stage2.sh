#!/usr/bin/env bash
set -x

OS=`uname -s`

check(){
  if [ ${OS} != "Linux" ]; then
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
  TARGET=x86_64-unknown-bitrig
  DF_LIB_DIR=${TOP}/../stage1/libs
  RS_LIB_DIR=${TOP}/rust-libs
}

clone(){
  if [ ! -e rust ]; then
    # clone everything
    cd ${TOP}
    git scclone https://github.com/rust-lang/rust.git rust
    cd rust
    echo "resetting to revision used in stage1"
    git reset --hard `cat ${TOP}/../stage1/revision.id`
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
  ID=`git id`
  if [ ! -e ${TOP}/../patches/${2}_${ID}.patch ]; then
    echo "${2} patch needs to be rebased to ${1} tip ${ID}"
    exit 1
  fi
  if [ ! -e .patched ]; then
    echo "Patching ${TOP}/${1} with ${2}_${ID}.patch"
    patch -p1 < ${TOP}/../patches/${2}_${ID}.patch
    if (( $? )); then
      echo "Failed to patch ${1}"
      exit 1
    fi
    date > .patched
  else
    echo "${1} already patched on:" `cat .patched`
  fi
}

linux_build(){
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
  export CFG_PREFIX="${TOP}/../stage1/install"
  export CFG_LLVM_LINKAGE_FILE="${TOP}/rust/src/librustc_llvm/llvmdeps.rs"
  export RUST_FLAGS="-g -Z verbose"
  RUST_LIBS="core libc alloc unicode collections rand std arena regex log fmt_macros serialize term syntax flate getopts regex test coretest graphviz rustc_back rustc_llvm rbml rustc rustc_trans rustc_typeck rustc_borrowck rustc_resolve rustc_driver rustdoc "

  # compile rust libraries
  for lib in $RUST_LIBS; do
    if [ -e ${RS_LIB_DIR}/lib${lib}.rlib ]; then
      echo "skipping $lib"
    else
      echo "compiling $lib"
      LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
        ${RUSTC} --target ${TARGET} ${RUST_FLAGS} --crate-type lib -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
    fi
  done

  LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
    ${RUSTC} ${RUST_FLAGS} --emit obj -o ${TOP}/driver.o --target ${TARGET} -L${DF_LIB_DIR} -L${RS_LIB_DIR} --cfg rustc ${RUST_SRC}/src/driver/driver.rs

  cd ${TOP}/..
  tar cvzf stage2.tgz stage2/*.o stage2/rust-libs

  echo "Please copy stage2.tgz onto your Bitrig machine and extract it"
}

linux(){
  setup
  clone
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/jemalloc jemalloc
  linux_build
}

check
MAKE=make
linux

