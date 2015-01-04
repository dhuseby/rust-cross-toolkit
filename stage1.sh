#!/usr/bin/env bash
set -x

OS=`uname -s`

setup(){
  echo "Creating stage1"
  mkdir -p stage1
  cd stage1
  TOP=`pwd`
}

clone(){
  if [ ! -e rust ]; then
    cd ${TOP}
    git clone https://github.com/rust-lang/rust.git
    cd rust
    git submodule init
    git submodule update
  else
    cd ${TOP}/rust
    git pull upstream
    git submodule update --merge
  fi
}

patch_src(){
  echo "Patching ${TOP}/${1} with ${2}.patch"
  cd ${TOP}/${1}
  if [ ! -e .patched ]; then
    patch -p1 < ${TOP}/../patches/${2}.patch
    if (( $? )); then 
      echo "Failed to patch ${1}"
      exit 1
    fi
    date > .patched
  else
    echo "${1} already patched on:" `cat .patched`
  fi
}

linux_configure(){
  export CC="/usr/bin/clang"
  export CXX="/usr/bin/clang++"
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fPIC"
  export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include  -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual"
  export LDFLAGS="-stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"

  # compile rust
  cd ${TOP}/rust
  ./configure --disable-docs --enable-clang --prefix=${TOP}/install
}

linux_build(){
  cd ${TOP}/rust
  ${MAKE} VERBOSE=1
  ${MAKE} install
}

bitrig_build_llvm(){
  mkdir -p ${LLVM_INSTALL}
  mkdir -p ${TARGET}
  mkdir -p ${LLVM_TARGET}

  # compile llvm
  cd ${TOP}/rust/src
  mkdir -p llvm-build
  cd llvm-build
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
  ar rcs librustllvm.a PassWrapper.o RustWrapper.o	
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

  #cd ${TOP}/rust/src/rt
  #${CC} -c -o context.o arch/x86_64/_context.S
  #ar rcs ${TARGET}/libcontext_switch.a context.o

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

linux(){
  setup
  clone
  # patch before configure so we can configure for bitrig
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/jemalloc jemalloc
  linux_configure
  # patch again because rust ./configure resets submodules
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/jemalloc jemalloc
  linux_build
}

bitrig(){
  setup
  clone
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/jemalloc jemalloc
  bitrig_build
}


if [ ${OS} == "Linux" ]; then
  MAKE=make
  linux
elif [ ${OS} == "Bitrig" ]; then
  MAKE=gmake
  bitrig
else
  echo "You must run this on Linux or Bitrig!"
  exit 1
fi

