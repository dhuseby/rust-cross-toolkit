#!/usr/bin/env bash
set -x

OS=`uname -s`

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
    git clone --reference ${TOP}/../stage1/rust https://github.com/rust-lang/rust.git
    cd rust
    git submodule init
    git submodule update
  else
    # update everything
    cd ${TOP}/rust
    git pull origin
    git submodule update --merge
  fi
  #cp ${TOP}/../stage1/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/
}

patch_src(){
  echo "Patching ${TOP}/${1} with ${2}.patch"
  cd ${TOP}/${1}
  if [ ! -e .patched ]; then
    patch -p1 < ${TOP}/../patches/${2}.patch
    date > .patched
  else
    echo "${1} already patched on:" `cat .patched`
  fi
}

bitrig_configure(){
  export CC="/usr/bin/clang"
  export CXX="/usr/bin/clang++"
  export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fPIC"
  export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual -v"
  export LDFLAGS="-g -stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"
  PREFIX="/usr/local"

  # configure rust
  cd ${TOP}/rust
  configure --enable-local-rust --enable-clang --local-rust-root=${TOP}/../stage3 --prefix=${PREFIX}
}

bitrig_build(){
  cd ${TOP}/rust
  ${MAKE} VERBOSE=1
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
  # patch again because rust ./configure clobbers submodules
  patch_src rust rust
  patch_src rust/src/llvm llvm
  patch_src rust/src/jemalloc jemalloc
  bitrig_build
}

MAKE=gmake
bitrig

echo "To install to ${PREFIX}: cd ${TOP}/rust && ${MAKE} install"

