#!/usr/bin/env bash
set -x

OS=`uname -s`
STAGE=${0#*/}
STAGE=${STAGE%%.sh}

check(){
  if [ ${OS} != "Bitrig" ]; then
    echo "You have to run this on Bitrig!"
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
  ID=`git id`
  PATCH=${TOP}/../patches/${2}_${ID}_${STAGE}.patch
  if [ ! -e ${PATCH} ]; then
    PATCH=${TOP}/../patches/${2}_${ID}.patch
  fi
  if [ ! -e ${PATCH} ]; then
    echo "${2} patch needs to be rebased to ${1} tip ${ID}"
    exit 1
  fi
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
}

bitrig_configure(){
  PREFIX="/usr/local"

  # configure rust
  cd ${TOP}/rust
  ./configure --disable-optimize --disable-docs --enable-local-rust --enable-clang --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
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
  check
  setup
  clone
  # patch before configure so we can configure for bitrig
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/jemalloc jemalloc
  bitrig_configure
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/x86_64-unknown-bitrig/rt/llvmdeps.rs
  bitrig_build
}

MAKE=gmake
bitrig

echo "To install to ${PREFIX}: cd ${TOP}/rust && ${MAKE} install"

