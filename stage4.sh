#!/usr/bin/env bash

usage(){
  cat<<EOF
  usage: $0 options

  This script drives the whole bootstrapping process.

  OPTIONS:
    -h      Show this message.
    -c      Continue previous build. Default is to rebuild all.
    -t      Target OS. Required. Valid options: 'bitrig', 'netbsd', 'illumos'.
    -a      CPU archictecture. Required. Valid options: 'x86_64' or 'i686'.
    -p      Compiler. Required. Valid options: 'gcc' or 'clang'.
    -v      Verbose output from this script.
EOF
}

HOST=`uname -s | tr '[:upper:]' '[:lower:]'`
CONTINUE=
TARGET=
ARCH=
COMP=
TRIPLE=
STAGE=${0#*/}
STAGE=${STAGE%%.sh}

while getopts "hr:t:a:p:v" OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    c)
      CONTINUE="yes"
      ;;
    r)
      ;;
    t)
      TARGET=$OPTARG
      ;;
    a)
      ARCH=$OPTARG
      ;;
    p)
      COMP=$OPTARG
      ;;
    v)
      set -x
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

if [[ -z $TARGET ]] || [[ -z $ARCH ]] || [[ -z $COMP ]]; then
  usage
  exit 1
fi

check_error(){
  if (( $1 )); then
    echo $2
    exit $1
  fi
}

check_for(){
  if [ ! -e ${1} ]; then
    echo "${1} does not exist!"
    exit 1
  fi
}

check(){
  if [ ${HOST} != ${TARGET} ]; then
    echo "You have to run this on ${TARGET}!"
    exit 1
  fi

  for f in "stage1" "stage1/install" "stage1/libs" "stage3/bin/rustc"; do
    check_for ${f}
  done
}

setup(){
  if [[ -z $CONTINUE ]] || [[ ! -e .stage4 ]]; then
    echo "Rebuilding stage4"
    rm -rf build4.log
    rm -rf stage4
    rm -rf .stage4
  elif [[ -e .stage4 ]]; then
    echo "Stage 4 already built on:" `cat .stage4`
    exit 1
  fi
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
      check_error $? "Failed to patch ${1}"
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
  check_error $? "Failed to confiture ${TARGET} rust"
}

bitrig_build(){
  cd ${TOP}/rust
  export RUST_BACKTRACE=1
  ${MAKE} VERBOSE=1
  check_error $? "Failed to build ${TARGET} rust"
}

bitrig(){
  setup
  clone
  apply_patches # patch before configure just in case
  bitrig_configure
  apply_patches # patch after too, configure clobbers submodules
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/${ARCH}-unknown-bitrig/rt/llvmdeps.rs
  bitrig_build
  date > .stage4
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
  check_error $? "Failed to configure ${TARGET} rust"
}

netbsd_build(){
  cd ${TOP}/rust
  export RUST_BACKTRACE=1
  ${MAKE} VERBOSE=1
  check_error $? "Failed to build ${TARGET} rust"
}

netbsd(){
  setup
  clone
  apply_patches # patch before configure just in case
  netbsd_configure
  apply_patches # patch after too, configure clobbers submodules
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/${ARCH}-unknown-netbsd/rt/llvmdeps.rs
  netbsd_build
  date > .stage4
}

### ILLUMOS FUNCTIONS ###

illumos_configure(){
  export CC="/usr/gcc/4.9/bin/gcc"
  export CXX="/usr/gcc/4.9/bin/g++"
  export AR="/usr/gcc/4/9/bin/gcc-ar"
  export NM="/usr/gcc/4.9/bin/gcc-nm"
  export RANLIB="/usr/gcc/4.9/bin/gcc-ranlib"
  PREFIX="/usr/local"

  # configure rust
  cd ${TOP}/rust
  #./configure --disable-optimize --disable-docs --enable-local-rust --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
  ./configure --disable-docs --enable-local-rust --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
  check_error $? "Failed to configure ${TARGET} rust"
}

illumos_build(){
  cd ${TOP}/rust
  export RUST_BACKTRACE=1
  ${MAKE} VERBOSE=1
  check_error $? "Failed to build ${TARGET} rust"
}

illumos(){
  setup
  clone
  apply_patches # patch before configure just in case
  illumos_configure
  apply_patches # patch after too, configure clobbers submodules
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
  cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/${ARCH}-sun-solaris/rt/llvmdeps.rs
  illumos_build
  date > .stage4
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

