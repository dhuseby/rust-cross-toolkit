#!/usr/bin/env bash

usage(){
  cat<<EOF
  usage: $0 options

  This script drives the whole bootstrapping process.

  OPTIONS:
    -h      Show this message.
    -c      Continue previous build. Default is to rebuild all.
    -r      Revision to build. Default is to build most recent snapshot revision.
    -t      Target OS. Required. Valid options: 'bitrig' or 'netbsd'.
    -a      CPU archictecture. Required. Valid options: 'x86_64' or 'i686'.
    -p      Compiler. Required. Valid options: 'gcc' or 'clang'.
    -v      Verbose output from this script.
EOF
}

HOST=`uname -s | tr '[:upper:]' '[:lower:]'`
CONTINUE=
REV=
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
      REV=$OPTARG
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

setup(){
  if [[ -z $CONTINUE ]]; then
    echo "Rebuilding stage1"
    rm -rf build1.log
    rm -rf stage1
    rm -rf .stage1
  elif [[ -e .stage1 ]]; then
    echo "Stage 1 already built on:" `cat .stage1`
    exit 1
  fi
  echo "Creating stage1"
  mkdir -p stage1
  cd stage1
  TOP=`pwd`
}

clone(){
  if [ ! -e rust ]; then
    cd ${TOP}
    if [[ -z ${REV} ]]; then
      git cclone https://github.com/rust-lang/rust.git tmp-rust
      REV=`head -n 1 tmp-rust/src/snapshots.txt | grep -oEi "[0-9a-fA-F]+$"`
      rm -rf tmp-rust
    fi
    git scclone https://github.com/rust-lang/rust.git rust ${REV}
    cd rust
    git rev-parse --short HEAD > ${TOP}/revision.id
    git submodule init
    git submodule update
  else
    cd ${TOP}/rust
    #git pull upstream
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
  patch_src rust/src/compiler-rt compiler-rt
  patch_src rust/src/rt/hoedown hoedown
  patch_src rust/src/jemalloc jemalloc
  patch_src rust/src/rust-installer rust-installer
  patch_src rust/src/liblibc liblibc
}

### LINUX FUNCTIONS ###

linux_configure_clang(){
  export CC="/usr/bin/clang"
  export CXX="/usr/bin/clang++"
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -O2 -fomit-frame-pointer -fPIC"
  export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include  -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -O2 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual"
  export LDFLAGS="-stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"

  # configure rust
  cd ${TOP}/rust
  ./configure --disable-docs --enable-clang --prefix=${TOP}/install
}

linux_configure_gcc() {
  export CC="/usr/bin/gcc"
  export CXX="/usr/bin/g++"
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -O0 -g -fomit-frame-pointer -fPIC"
  export CXXFLAGS="-mstackrealign -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -O0 -g -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual"
  export LDFLAGS="-lc -lpthread -lffi -ltinfo -ldl -lm"

  # configure rust
  cd ${TOP}/rust
  ./configure --disable-docs --enable-debug --prefix=${TOP}/install
}

linux_build(){
  cd ${TOP}/rust
  ${MAKE} VERBOSE=1
  ${MAKE} install
}

linux(){
  setup
  clone
  # patch before configure so we can configure for target
  apply_patches
  linux_configure_${COMP}
  # patch again because rust ./configure resets submodules
  apply_patches
  linux_build
}

### NETBSD FUNCTIONS ###

netbsd_build_llvm(){
  mkdir -p ${LLVM_INSTALL}
  mkdir -p ${TARGET}
  mkdir -p ${LLVM_TARGET}

  # compile llvm
  cd ${TOP}/rust/src
  mkdir -p llvm-build
  cd llvm-build
  ../llvm/configure --prefix=${LLVM_INSTALL} --enable-debug-symbols
  #../llvm/configure --prefix=${LLVM_INSTALL}
  check_error $? "Failed to configure LLVM"
  ${MAKE} -j2 VERBOSE=1
  ${MAKE} VERBOSE=1 install

  # copy the llvm lib files to the LLVM TARGET
  cp `${LLVM_INSTALL}/bin/llvm-config --libfiles` ${LLVM_TARGET}
}

netbsd_build_rust_parts(){
  # build the rustllvm pieces
  cd ${TOP}/rust/src/rustllvm
  ${CXX} ${CXXFLAGS} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` PassWrapper.cpp
  ${CXX} ${CXXFLAGS} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` RustWrapper.cpp
  ${CXX} ${CXXFLAGS} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` ExecutionEngineWrapper.cpp
  ${CXX} ${CXXFLAGS} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` ArchiveWrapper.cpp
  ar rcs librustllvm.a ArchiveWrapper.o ExecutionEngineWrapper.o PassWrapper.o RustWrapper.o
  cp librustllvm.a ${TARGET}

  # build libcompiler-rt.a
  cd ${TOP}/rust/src/compiler-rt
  cmake -D_LLVM_CMAKE_DIR=${LLVM_INSTALL}/share/llvm/cmake -DLLVM_CONFIG_PATH=${LLVM_INSTALL}/bin/llvm-config
  ${MAKE} VERBOSE=1
  cp ./lib/netbsd/libclang_rt.builtins-x86_64.a ${TARGET}/libcompiler-rt.a

  # build libbacktrace.a
  cd ${TOP}/rust/src
  ln -s libbacktrace include
  cd libbacktrace
  ./configure
  ${MAKE} VERBOSE=1
  cp .libs/libbacktrace.a ${TARGET}
  cd ..
  rm -rf include

  cd ${TOP}/rust/src/rt
  ${CC} ${CFLAGS} -c -fPIC -o rust_builtin.o rust_builtin.c
  ar rcs ${TARGET}/librust_builtin.a rust_builtin.o

  cd ${TOP}/rust/src/rt
  ${CC} ${CFLAGS} -c -fPIC -o miniz.o miniz.c
  ar rcs ${TARGET}/libminiz.a miniz.o

  cd ${TOP}/rust/src/rt/hoedown
  ${MAKE} VERBOSE=1 libhoedown.a
  cp libhoedown.a ${TARGET}
}

netbsd_build(){
  export PATH=/usr/pkg/gcc49/bin:$PATH
  export CC="/usr/pkg/gcc49/bin/gcc"
  export CXX="/usr/pkg/gcc49/bin/g++"
  export CFLAGS="-g -O0"
  export CXXFLAGS="-g -O0"

  LLVM_INSTALL=${TOP}/install
  TARGET=${TOP}/libs
  LLVM_TARGET=${TARGET}/llvm

  netbsd_build_llvm
  netbsd_build_rust_parts

  # Copy NetBSD system libraries
  mkdir -p ${TARGET}/usr/lib
  cp -r /usr/lib/* ${TARGET}/usr/lib/

  cd ${TOP}/..
  python ${TOP}/rust/src/etc/mklldeps.py stage1/llvmdeps.rs "x86 arm mips ipo bitreader bitwriter linker asmparser mcjit interpreter instrumentation" true "${LLVM_INSTALL}/bin/llvm-config" "stdc++" "0"

  cd ${TOP}/..
  tar cvzf stage1.tgz stage1/libs stage1/llvmdeps.rs

  echo "Please copy stage1.tgz onto your Linux machine and extract it"
}

netbsd(){
  setup
  clone
  apply_patches
  netbsd_build
}

### BITRIG FUNCTIONS ###

bitrig_build_llvm(){
  mkdir -p ${LLVM_INSTALL}
  mkdir -p ${TARGET}
  mkdir -p ${LLVM_TARGET}

  # compile llvm
  cd ${TOP}/rust/src
  mkdir -p llvm-build
  cd llvm-build
  #../llvm/configure --prefix=${LLVM_INSTALL} --enable-debug-runtime --enable-debug-symbols
  ../llvm/configure --prefix=${LLVM_INSTALL}
  ${MAKE} -j9 VERBOSE=1
  ${MAKE} VERBOSE=1 install

  # copy the llvm lib files to the LLVM TARGET
  cp `${LLVM_INSTALL}/bin/llvm-config --libfiles` ${LLVM_TARGET}
}

bitrig_build_rust_parts(){
  # build the rustllvm pieces
  cd ${TOP}/rust/src/rustllvm
  ${CXX} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` PassWrapper.cpp
  ${CXX} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` RustWrapper.cpp
  ${CXX} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` ExecutionEngineWrapper.cpp
  ${CXX} -c `${LLVM_INSTALL}/bin/llvm-config --cxxflags` ArchiveWrapper.cpp
  ar rcs librustllvm.a ArchiveWrapper.o ExecutionEngineWrapper.o PassWrapper.o RustWrapper.o
  cp librustllvm.a ${TARGET}

  # build libcompiler-rt.a
  cd ${TOP}/rust/src/compiler-rt
  cmake -DLLVM_CONFIG_PATH=${LLVM_INSTALL}/bin/llvm-config
  ${MAKE} VERBOSE=1
  cp ./lib/bitrig/libclang_rt.builtins-x86_64.a ${TARGET}/libcompiler-rt.a

  # build libbacktrace.a
  cd ${TOP}/rust/src
  ln -s libbacktrace include
  cd libbacktrace
  ./configure
  ${MAKE} VERBOSE=1
  cp .libs/libbacktrace.a ${TARGET}
  cd ..
  rm -rf include

  cd ${TOP}/rust/src/rt
  ${LLVM_INSTALL}/bin/llc rust_try.ll
  ${CC} -c -fPIC -o rust_try.o rust_try.s
  ${CC} -c -fPIC -o record_sp.o arch/x86_64/record_sp.S
  ar rcs ${TARGET}/librustrt_native.a rust_try.o record_sp.o

  cd ${TOP}/rust/src/rt
  ${CC} -c -fPIC -o rust_builtin.o rust_builtin.c
  ar rcs ${TARGET}/librust_builtin.a rust_builtin.o

  cd ${TOP}/rust/src/rt
  ${CC} -c -fPIC -o morestack.o arch/x86_64/morestack.S
  ar rcs ${TARGET}/libmorestack.a morestack.o

  cd ${TOP}/rust/src/rt
  ${CC} -c -fPIC -o miniz.o miniz.c
  ar rcs ${TARGET}/libminiz.a miniz.o

  cd ${TOP}/rust/src/rt/hoedown
  ${MAKE} VERBOSE=1 libhoedown.a
  cp libhoedown.a ${TARGET}
}

bitrig_build(){
  if [ `machine -a` != "amd64" ]; then
    echo "Rust only supports Bitrig amd64 right now!"
    exit 1
  fi

  export AUTOCONF_VERSION=2.68
  export CC="/usr/bin/clang"
  export CXX="/usr/bin/clang++"

  LLVM_INSTALL=${TOP}/install
  TARGET=${TOP}/libs
  LLVM_TARGET=${TARGET}/llvm

  bitrig_build_llvm
  bitrig_build_rust_parts

  # Copy Bitrig system libraries
  mkdir -p ${TARGET}/usr/lib
  cp -r /usr/lib/* ${TARGET}/usr/lib/

  cd ${TOP}/..
  python ${TOP}/rust/src/etc/mklldeps.py stage1/llvmdeps.rs "x86 arm mips ipo bitreader bitwriter linker asmparser mcjit interpreter instrumentation" true "${LLVM_INSTALL}/bin/llvm-config"

  cd ${TOP}/..
  tar cvzf stage1.tgz stage1/libs stage1/llvmdeps.rs

  echo "Please copy stage1.tgz onto your Linux machine and extract it"
}

bitrig(){
  setup
  clone
  apply_patches
  bitrig_build
}

MAKE=make
case ${HOST} in
  "linux")
    linux
  ;;
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

