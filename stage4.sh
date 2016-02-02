#!/usr/bin/env bash

if [[ $# -lt 3 ]]; then
  echo "Usage: stage3.sh <target> <arch> <compiler>"
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
  if [ ${HOST} != ${TARGET} ]; then
    echo "You have to run this on ${TARGET}!"
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
    echo "stage1/libs does not exist!"
    exit 1
  fi

  if [ ! -e "stage3/bin/rustc" ]; then
    echo "stage3/bin/rustc does not exist!"
    exit 1
  fi
}

setup(){
  echo "Creating stage4"
  mkdir -p stage4
  cd stage4
  TOP=`pwd`
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
  fi
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

### BITRIG FUNCTIONS ###

bitrig_configure(){
  PREFIX="/usr/local"

  # configure rust
  cd ${TOP}/rust
  #./configure --disable-optimize --disable-docs --enable-local-rust --enable-clang --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
  ./configure --disable-docs --enable-local-rust --enable-clang --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
  if (( $? )); then
    echo "Failed to configure rust"
    exit 1
  fi
}

bitrig_build(){
  cd ${TOP}/rust
  export RUST_BACKTRACE=1
  ${MAKE} VERBOSE=1
  if (( $? )); then
    echo "Failed to build rust"
    exit 1
  fi
}

bitrig(){
  setup
  clone
  apply_patches # patch before configure just in case
  bitrig_configure
  apply_patches # patch after too, configure clobbers submodules
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/x86_64-unknown-bitrig/rt/llvmdeps.rs
  bitrig_build
}

### NETBSD FUNCTIONS ###

netbsd_configure(){
  export CC="/usr/pkg/gcc49/bin/cc"
  export CXX="/usr/pkg/gcc49/bin/c++"
  export AR="/usr/pkg/gcc49/bin/gcc-ar"
  export NM="/usr/pkg/gcc49/bin/gcc-nm"
  export RANLIB="/usr/pkg/gcc49/bin/gcc-ranlib"
  PREFIX="/usr/pkg"

  # configure rust
  cd ${TOP}/rust
  #./configure --disable-optimize --disable-docs --enable-local-rust --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
  ./configure --disable-docs --enable-local-rust --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
  if (( $? )); then
    echo "Failed to configure rust"
    exit 1
  fi
}

netbsd_build(){
  cd ${TOP}/rust
  export RUST_BACKTRACE=1
  ${MAKE} VERBOSE=1
  if (( $? )); then
    echo "Failed to build rust"
    exit 1
  fi
}

netbsd(){
  setup
  clone
  apply_patches # patch before configure just in case
  netbsd_configure
  apply_patches # patch after too, configure clobbers submodules
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/x86_64-unknown-netbsd/rt/llvmdeps.rs
  netbsd_build
}

check
MAKE=make
case ${HOST} in
  "bitrig")
    MAKE=gmake
    bitrig
  ;;
  "netbsd")
    MAKE=gmake
    netbsd
  ;;
  *)
    echo "${OS} unsupported at the moment"
    exit 1
  ;;
esac

echo "To install to ${PREFIX}: cd ${TOP}/rust && ${MAKE} install"

