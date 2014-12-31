#!/bin/sh
set -x

if [ `uname -s` != "Linux" ]; then
  echo "You have to run this on Linux!"
  exit 1
fi

mkdir -p stage1-linux
cd stage1-linux

TOP=`pwd`

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

patch_src(){
  echo "Patching ${TOP}/${1} with ${2}.patch"
  cd ${TOP}/${1}
  if [ ! -e .patched ]; then
    patch -p1 < ${TOP}/../patches/${2}.patch
    date > .patched
  else
    echo "Rust already patched on:" `cat .patched`
  fi
}

cd ${TOP}
patch_src rust rust
patch_src rust/src/llvm llvm
patch_src rust/src/jemalloc jemalloc
cd ${TOP}/rust

export CC="/usr/bin/clang"
export CXX="/usr/bin/clang++"
export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fPIC"
export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include  -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual"
export LDFLAGS="-stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"

./configure --disable-docs --enable-clang --prefix=${TOP}/install
make VERBOSE=1
make install
