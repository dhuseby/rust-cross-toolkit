#!/usr/bin/env bash

if [[ $# -lt 3 ]]; then
  echo "Usage: stage1.sh <target> <arch> <compiler>"
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

setup(){
  echo "Creating stage1"
  mkdir -p stage1
  cd stage1
  TOP=`pwd`
}

clone(){
  if [ ! -e rust ]; then
    cd ${TOP}
    git cclone https://github.com/rust-lang/rust.git tmp-rust
    REV=`head -n 1 tmp-rust/src/snapshots.txt | grep -oEi "[0-9a-fA-F]+$"`
    rm -rf tmp-rust
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
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -O2 -fomit-frame-pointer -fPIC"
  export CXXFLAGS="-mstackrealign -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -O2 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual"
  export LDFLAGS="-lc -lpthread -lffi -ltinfo -ldl -lm"

  # configure rust
  cd ${TOP}/rust
  ./configure --disable-docs --prefix=${TOP}/install
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
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/compiler-rt compiler-rt
  patch_src rust/src/rt/hoedown hoedown
  patch_src rust/src/jemalloc jemalloc
  patch_src rust/src/rust-installer rust-installer
  patch_src rust/src/liblibc libc
  linux_configure_${COMP}
  # patch again because rust ./configure resets submodules
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/compiler-rt compiler-rt
  patch_src rust/src/rt/hoedown hoedown
  patch_src rust/src/jemalloc jemalloc
  patch_src rust/src/rust-installer rust-installer
  patch_src rust/src/liblibc libc
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
  #../llvm/configure --prefix=${LLVM_INSTALL} --enable-debug-runtime --enable-debug-symbols
  ../llvm/configure --prefix=${LLVM_INSTALL}
  if (( $? )); then
    echo "Failed to configure LLVM"
    exit $?
  fi
  ${MAKE} -j2 VERBOSE=1
  ${MAKE} VERBOSE=1 install

  # copy the llvm lib files to the LLVM TARGET
  cp `${LLVM_INSTALL}/bin/llvm-config --libfiles` ${LLVM_TARGET}
}

netbsd_build_rust_parts(){
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
  cmake -D_LLVM_CMAKE_DIR=${LLVM_INSTALL}/share/llvm/cmake -DLLVM_CONFIG_PATH=${LLVM_INSTALL}/bin/llvm-config
  ${MAKE} VERBOSE=1
  cp ./lib/netbsd/libclang_rt.x86_64.a ${TARGET}/libcompiler-rt.a

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
  ${CC} -c -fPIC -o rust_builtin.o rust_builtin.c
  ar rcs ${TARGET}/librust_builtin.a rust_builtin.o

  cd ${TOP}/rust/src/rt
  ${CC} -c -fPIC -o miniz.o miniz.c
  ar rcs ${TARGET}/libminiz.a miniz.o

  cd ${TOP}/rust/src/rt/hoedown
  ${MAKE} VERBOSE=1 libhoedown.a
  cp libhoedown.a ${TARGET}
}

netbsd_build(){
  export PATH=/usr/pkg/gcc49/bin:$PATH
  export CC="/usr/pkg/gcc49/bin/gcc"
  export CXX="/usr/pkg/gcc49/bin/g++"

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
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/compiler-rt compiler-rt
  patch_src rust/src/rt/hoedown hoedown
  patch_src rust/src/jemalloc jemalloc
  patch_src rust/src/rust-installer rust-installer
  patch_src rust/src/liblibc libc
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
  cp ./lib/bitrig/libclang_rt.x86_64.a ${TARGET}/libcompiler-rt.a

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
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/compiler-rt compiler-rt
  patch_src rust/src/rt/hoedown hoedown
  patch_src rust/src/jemalloc jemalloc
  patch_src rust/src/rust-installer rust-installer
  patch_src rust/src/liblibc libc
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

