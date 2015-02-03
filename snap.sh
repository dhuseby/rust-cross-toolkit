#!/usr/bin/env bash
set -x

if (( $# < 2 )); then
  echo "usage: $0 <revision to build> <snapshot tarball to use>"
  exit 1
fi

OS=`uname -s`
REV=$1
SNAP=$2

check(){
  if [ ${OS} != "Bitrig" ]; then
    echo "You have to run this on Bitrig!"
    exit 1
  fi

  if [ ! -e snapshots/${SNAP} ]; then
    echo "snapshot tarball doesn't exist"
    exit 1
  fi
}

setup(){
  echo "Creating rust-build-${REV}"
  mkdir -p snap-${REV}
  cd snap-${REV}
  TOP=`pwd`
}

clone(){
  cd ${TOP}
  if [ ! -e rust ]; then
    # clone everything
    echo "cloning at revision: ${REV}"
    git scclone https://github.com/rust-lang/rust.git rust ${REV}
    cd rust
    echo "initializing submodules"
    git submodule init
    git submodule update
  else
    # update everything
    echo "already cloned...skipping"
    cd ${TOP}/rust
    #git pull origin
    #git submodule update --merge
  fi
}

patch_src(){
  cd ${TOP}/${1}
  ID=`git id`
  PATCH=${TOP}/../patches/${2}_${ID}.patch
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
    echo "${1} already patched on:" `cat .patched` "...skipping"
  fi
}

bitrig_configure(){
  PREFIX="/usr/local"

  # configure rust
  cd ${TOP}/rust
  if [ ! -e .configured ]; then
    ./configure --disable-docs --enable-clang --prefix=${PREFIX}
    if (( $? )); then
      echo "Failed to configure rust"
      exit 1
    fi
    date > .configured
  else
    echo "already configured...skipping"
  fi
}

bitrig_build(){
  cd ${TOP}/rust
  #export RUST_BACKTRACE=1
  export CFG_SRC_DIR=${TOP}/rust
  export SNAPSHOT_FILE=${TOP}/../snapshots/${SNAP}
  ${MAKE} VERBOSE=1
  if (( $? )); then
    echo "Failed to build rust"
    exit 1
  fi
}

create_snap(){
  cd ${TOP}/rust
  export CFG_SRC_DIR=${TOP}/rust
  export SNAPSHOT_FILE=${TOP}/../snapshots/${SNAP}
  ${MAKE} VERBOSE=1 snap-stage3
  if (( $? )); then
    echo "Failed to build the snapshot"
    exit 1
  fi
  cp rust-stage0-*.tar.bz2 ${TOP}/../snapshots/
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
  bitrig_build
  create_snap
}

MAKE=gmake
bitrig

