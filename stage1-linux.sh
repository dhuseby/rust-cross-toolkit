#!/bin/sh

if [ `uname -s` != "Linux" ]; then
  echo "You have to run this on Linux!"
  exit 1
fi

mkdir -p stage1-linux
cd stage1-linux

TOP=`pwd`

if [ ! -e rust ]; then
  git clone https://github.com/rust-lang/rust.git
fi
cd rust
git submodule init
git submodule update
./configure --prefix=${TOP}/install

if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-rust
  date > .patched
else
  echo "Rust already patched on:" `cat .patched`
fi
cd src/jemalloc
if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-jemalloc
  date > .patched
else
  echo "jemalloc already patched on:" `cat .patched`
fi
cd ../..
cd src/llvm
if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-llvm
  date > .patched
else
  echo "LLVM already patched on:" `cat .patched`
fi
cd ../..

echo $PWD
make
make install
