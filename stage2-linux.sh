#!/bin/sh
set -x

if [ `uname -s` != "Linux" ]; then
  echo "You have to run this on Linux!"
  exit 1
fi

if [ ! -e "stage1-linux" ]; then
  echo "stage1-linux does not exist!"
  exit 1
fi

if [ ! -e "stage1-linux/install" ]; then
  echo "stage1-linux/install does not exist!"
  exit 1
fi

if [ ! -e "stage1-openbsd/libs" ]; then
  echo "need stage1-openbsd/libs!"
  exit 1
fi

mkdir -p stage2-linux
mkdir -p stage2-linux/rust-libs
cd stage2-linux

TOP=`pwd`

export CC="/usr/bin/gcc-4.8"
export CXX="/usr/bin/g++-4.8"

RUST_PREFIX=${TOP}/../stage1-linux/install
RUST_SRC=${TOP}/rust
RUSTC=${RUST_PREFIX}/bin/rustc
TARGET=x86_64-unknown-openbsd

DF_LIB_DIR=${TOP}/../stage1-openbsd/libs
RS_LIB_DIR=${TOP}/rust-libs

export LD_LIBRARY_PATH=${RUST_PREFIX}/lib

if [ ! -e rust ]; then
  git clone --reference ${TOP}/../stage1-linux/rust https://github.com/rust-lang/rust.git
fi
cd rust
git submodule init
git submodule update
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
cd ../llvm
if [ ! -e .patched ]; then
  patch -p1 < ${TOP}/../patch-llvm
  date > .patched
else
  echo "LLVM already patched on:" `cat .patched`
fi
cd ../..

cp ${TOP}/../stage1-openbsd/llvmdeps.rs ${TOP}/rust/src/librustc_llvm/

# XXX
export CFG_VERSION="0.13.0-dev"
export CFG_RELEASE="openbsd-cross"
export CFG_VER_HASH="hash"
export CFG_VER_DATE="`date`"
export CFG_COMPILER_HOST_TRIPLE="x86_64-unknown-openbsd"
export CFG_PREFIX="/usr/local"

RUST_LIBS="core libc alloc unicode collections rustrt rand sync std native arena regex log fmt_macros serialize term syntax flate time getopts regex test coretest graphviz rustc_back rustc_llvm rbml rustc regex_macros green rustc_trans rustdoc"

# compile rust libraries
for lib in $RUST_LIBS; do
  if [ -e ${RS_LIB_DIR}/lib${lib}.rlib ]; then
    echo "skipping $lib"
  else
    echo "compiling $lib"
    ${RUSTC} --target ${TARGET} ${RUST_FLAGS} --crate-type lib -L${DF_LIB_DIR} -L${DF_LIB_DIR}/llvm -L${RS_LIB_DIR} ${RUST_SRC}/src/lib${lib}/lib.rs -o ${RS_LIB_DIR}/lib${lib}.rlib
  fi
done

${RUSTC} ${RUST_FLAGS} --emit obj -o ${TOP}/driver.o --target ${TARGET} -L${DF_LIB_DIR} -L${RS_LIB_DIR} --cfg rustc ${RUST_SRC}/src/driver/driver.rs

tar cvzf ${TOP}/../stage2-linux.tgz ${TOP}/*.o ${TOP}/rust-libs


echo "Please copy stage2-linux.tgz onto your OpenBSD machine and extract it"
