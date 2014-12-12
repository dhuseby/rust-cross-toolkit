#!/bin/sh
set -x

if [ `uname -s` != "Linux" ]; then
  echo "You have to run this on Linux!"
  exit 1
fi

mkdir -p stage1-linux
cd stage1-linux

TOP=`pwd`

export CC="/usr/bin/clang"
export CXX="/usr/bin/clang++"
export CFLAGS="`llvm-config --cflags`"
export CXXFLAGS="-std=c++11 -stdlib=libc++ -stdlibabi=libc++abi `llvm-config --cxxflags`"
export LDFLAGS="`llvm-config --ldflags`"

if [ ! -e rust ]; then
  git clone https://github.com/dhuseby/rust.git
fi
cd rust
git submodule init
git submodule update
./configure --disable-docs --enable-clang --prefix=${TOP}/install
make VERBOSE=1
make install
