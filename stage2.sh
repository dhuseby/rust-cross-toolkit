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
STAGE=${0#*/}
STAGE=${STAGE%%.sh}

while getopts "hcr:t:a:p:v" OPTION; do
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
  if [ ${HOST} != "linux" ]; then
    echo "You have to run this on Linux!"
    exit 1
  fi

  for f in "stage1" "stage1/install" "stage1/libs"; do
    check_for ${f}
  done
}

setup(){
  if [[ -z $CONTINUE ]]; then
    echo "Rebuilding stage2"
    rm -rf build2.log
    rm -rf stage2
    rm -rf .stage2
  elif [[ -e .stage2 ]]; then
    echo "Stage 2 already built on:" `cat .stage2`
    exit 1
  fi
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
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -fomit-frame-pointer -fPIC -O0 -g"
  export CXXFLAGS="-mstackrealign -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual -v -O0 -g"
  export LDFLAGS="-lc -lpthread -lffi -ltinfo -ldl -lm"
}

linux_build(){
  cd ${TOP}/../stage1/rust
  export CFG_VER_HASH=`git rev-parse HEAD`
  cd ${TOP}
  export CFG_VERSION="1.8.0-dev"
  export CFG_RELEASE="${TARGET}-cross"
  export CFG_VER_DATE="`date`"
  export CFG_COMPILER_HOST_TRIPLE="${ARCH}-unknown-${TARGET}"
  export CFG_PREFIX="${TOP}/../stage1/install"
  export CFG_LLVM_LINKAGE_FILE="${TOP}/rust/src/librustc_llvm/llvmdeps.rs"
  #export RUST_FLAGS="-g -Z verbose"
  #export RUST_FLAGS="--cfg stage0  -O --cfg rtopt -C debug-assertions=on -g -C rpath -C prefer-dynamic -C no-stack-check -Z verbose"
  #export RUST_FLAGS="-O --cfg rtopt -g -C rpath -C prefer-dynamic -C no-stack-check -Z verbose"
  export RUST_FLAGS="-g -C rpath -C prefer-dynamic -C no-stack-check -Z verbose"
  RUST_LIBS="core libc rustc_unicode alloc collections rand std alloc_system arena log fmt_macros serialize term syntax syntax_ext flate getopts test graphviz rustc_llvm rustc_front rustc_back rbml rustc_data_structures rustc rustc_bitflags rustc_lint rustc_privacy rustc_resolve rustc_mir rustc_platform_intrinsics rustc_trans rustc_typeck rustc_borrowck rustc_metadata rustc_plugin rustc_passes rustc_driver rustdoc"

  # compile rust libraries
  for lib in $RUST_LIBS; do
    if [ -e ${RS_LIB_DIR}/lib${lib}.rlib ]; then
      echo "skipping $lib"
    else
      echo "compiling $lib"
      if [ ${lib} != "libc" ]; then
        LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
        ${RUSTC} --target ${CFG_COMPILER_HOST_TRIPLE} ${RUST_FLAGS} --crate-type lib -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
        check_error $? "Failed to compile ${RS_LIB_DIR}/lib${lib}.rlib"
      else
        LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
        ${RUSTC} --target ${CFG_COMPILER_HOST_TRIPLE} ${RUST_FLAGS} --cfg stdbuild -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/src/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
        #i686-unknown-freebsd/stage0/bin/rustc --cfg stage0  -O --cfg rtopt -C debug-assertions=on -g -C rpath -C prefer-dynamic -C no-stack-check --target=i686-unknown-freebsd   -L "i686-unknown-freebsd/rt" -L native="/opt/rust/build/i686-unknown-freebsd/llvm/Release+Asserts/lib"  --cfg stdbuild   --out-dir i686-unknown-freebsd/stage0/lib/rustlib/i686-unknown-freebsd/lib -C extra-filename=-db5a760f ../src/liblibc/src/lib.rs
        check_error $? "Failed to compile ${RS_LIB_DIR}/lib${lib}.rlib"
      fi
    fi
  done

  LD_LIBRARY_PATH=${TOP}/../stage1/install/lib \
    ${RUSTC} ${RUST_FLAGS} --emit obj -o ${TOP}/driver.o --target ${CFG_COMPILER_HOST_TRIPLE} -L${DF_LIB_DIR} -L${RS_LIB_DIR} --cfg rustc ${RUST_SRC}/src/driver/driver.rs

  check_error $? "Failed to compile ${RUST_SRC}/src/driver/driver.rs"

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
  date > .stage2
}

check
MAKE=make
linux

