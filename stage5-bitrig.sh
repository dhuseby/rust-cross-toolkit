#!/bin/sh

if [ `uname -s` != "Bitrig" ]; then
  echo "You have to run this on Bitrig!"
  exit 1
fi

if [ ! -e "stage1-bitrig/libs" ]; then
  echo "stage1-openbsd does not exist!"
  exit 1
fi

if [ ! -e "stage4-bitrig/lib" ]; then
  echo "stage4-bitrig does not exist!"
  exit 1
fi

set -x

RL=stage4-bitrig/lib

SUP_LIBS="-Wl,-whole-archive -lmorestack -Wl,-no-whole-archive -lrust_builtin -lrustllvm -lcompiler-rt -lbacktrace -lcontext_switch -lhoedown -lminiz -lrustrt_native"

LLVM_LIBS="`llvm-config --libs` -lz -lcurses"

RUST_DEPS="$RL/librustc.rlib $RL/libtime.rlib $RL/librustc_llvm.rlib $RL/libarena.rlib $RL/libgetopts.rlib $RL/librustc_back.rlib $RL/libsyntax.rlib $RL/libserialize.rlib $RL/librbml.rlib $RL/libflate.rlib $RL/libterm.rlib $RL/liblog.rlib $RL/libgraphviz.rlib $RL/libfmt_macros.rlib $RL/libstd.rlib $RL/librustrt.rlib $RL/libcollections.rlib $RL/libunicode.rlib $RL/liballoc.rlib $RL/liblibc.rlib $RL/librand.rlib $RL/libcore.rlib $RL/libcoretest.rlib $RL/libregex.rlib $RL/libregex_macros.rlib $RL/librustc_driver.rlib $RL/librustc_trans.rlib $RL/librustc_typeck.rlib $RL/librustdoc.rlib $RL/libtest.rlib"

export CXX="/usr/bin/clang++"
export CXXFLAGS="-I/usr/local/include  -D_DEBUG -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -std=c++11 -stdlib=libc++ -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -fPIC -ffunction-sections -fdata-sections -Wcast-qual"
export LDFLAGS="-L/usr/local/lib -stdlib=libc++ -lc++ -lc++abi -lm -lc -lz -lcurses -lpthread"

mkdir -p stage5-bitrig/bin
mkdir -p stage5-bitrig/lib

${CXX} ${CXXFLAGS} -o stage5-bitrig/bin/rustc -Wl,--start-group stage4-bitrig/driver.o ${RUST_DEPS} -L./stage1-bitrig/libs/llvm -L./stage1-bitrig/libs ${SUP_LIBS} ${LLVM_LIBS} -Wl,--end-group

cp stage1-bitrig/libs/libcompiler-rt.a stage5-bitrig/lib
cp stage1-bitrig/libs/libmorestack.a stage5-bitrig/lib
cp stage4-bitrig/lib/*.rlib stage5-bitrig/lib

./stage5-bitrig/bin/rustc -Lstage5-bitrig/lib hw.rs && ./hw
