#!/usr/bin/env bash
set -x

OS=`uname -s`

check(){
  if [ ${OS} != "Bitrig" ]; then
    echo "You have to run this on Bitrig!"
    exit 1
  fi

  if [ ! -e "stage1/libs" ]; then
    echo "stage1/libs does not exist!"
    exit 1
  fi

  if [ ! -e "stage2/rust-libs" ]; then
    echo "stage2/rust-libs does not exist!"
    exit 1
  fi
}

setup(){
  echo "Creating stage3"
  mkdir -p stage3
  cd stage3
  TOP=`pwd`
  mkdir -p bin
  mkdir -p lib
  RL=stage2/rust-libs
}

bitrig_build(){
  cd ${TOP}
  RL=${TOP}/../stage2/rust-libs
  SUP_LIBS="-Wl,-whole-archive -lmorestack -Wl,-no-whole-archive -lrust_builtin -lrustllvm -lcompiler-rt -lbacktrace -lhoedown -lminiz -lrustrt_native"
  LLVM_LIBS="`${TOP}/../stage1/install/bin/llvm-config --libs` `${TOP}/../stage1/install/bin/llvm-config --system-libs`"
  RUST_DEPS="$RL/librustc.rlib $RL/librustc_llvm.rlib $RL/libarena.rlib $RL/libgetopts.rlib $RL/librustc_back.rlib $RL/libsyntax.rlib $RL/libserialize.rlib $RL/librbml.rlib $RL/libflate.rlib $RL/libterm.rlib $RL/liblog.rlib $RL/libgraphviz.rlib $RL/libfmt_macros.rlib $RL/libstd.rlib $RL/libcollections.rlib $RL/libunicode.rlib $RL/liballoc.rlib $RL/liblibc.rlib $RL/librand.rlib $RL/libcore.rlib $RL/libcoretest.rlib $RL/libregex.rlib $RL/librustc_driver.rlib $RL/librustc_trans.rlib $RL/librustc_typeck.rlib $RL/librustc_borrowck.rlib $RL/librustc_resolve.rlib $RL/librustdoc.rlib $RL/libtest.rlib"
  CXXFLAGS="`${TOP}/../stage1/install/bin/llvm-config --cxxflags` -stdlib=libc++ -v"
  LDFLAGS="-lc++ -lc++abi"

  cc ${CXXFLAGS} -o ${TOP}/bin/rustc -Wl,--start-group ${TOP}/../stage2/driver.o ${RUST_DEPS} -L${TOP}/../stage1/libs/llvm -L${TOP}/../stage1/libs -L${TOP}/../stage1/libs/llvm ${SUP_LIBS} ${LLVM_LIBS} ${LDFLAGS} -Wl,--end-group

  cp ${TOP}/../stage1/libs/libcompiler-rt.a ${TOP}/lib
  cp ${TOP}/../stage1/libs/libmorestack.a ${TOP}/lib
  cp ${TOP}/../stage2/rust-libs/*.rlib ${TOP}/lib
}

bitrig_test(){
  cd ${TOP}
  ${TOP}/bin/rustc -L${TOP}/lib ${TOP}/../hw.rs
  ./hw
}

bitrig(){
  setup
  bitrig_build
  bitrig_test
}

check
bitrig

