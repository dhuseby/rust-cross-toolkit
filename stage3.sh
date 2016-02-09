#!/usr/bin/env bash

usage(){
  cat<<EOF
  usage: $0 options

  This script drives the whole bootstrapping process.

  OPTIONS:
    -h      Show this message.
    -t      Target OS. Required. Valid options: 'bitrig' or 'netbsd'.
    -a      CPU archictecture. Required. Valid options: 'x86_64' or 'i686'.
    -p      Compiler. Required. Valid options: 'gcc' or 'clang'.
    -v      Verbose output from this script.
EOF
}

HOST=`uname -s | tr '[:upper:]' '[:lower:]'`
TARGET=
ARCH=
COMP=
STAGE=${0#*/}
STAGE=${STAGE%%.sh}

while getopts "hr:t:a:p:v" OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    r)
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

check_for(){
  if [ ! -e ${1} ]; then
    echo "${1} does not exist!"
    exit 1
  fi
}

check(){
  if [ ${HOST} != ${TARGET} ]; then
    echo "You have to run this on ${TARGET}!"
    exit 1
  fi

  for f in "stage1/libs" "stage2/rust-libs"; do
    check_for ${f}
  done
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

### BITRIG FUNCTIONS ###

bitrig_build(){
  cd ${TOP}
  RL=${TOP}/../stage2/rust-libs
  SUP_LIBS="-Wl,-whole-archive -lmorestack -Wl,-no-whole-archive -lrust_builtin -lrustllvm -lcompiler-rt -lbacktrace -lhoedown -lminiz -lrustrt_native"
  LLVM_LIBS="`${TOP}/../stage1/install/bin/llvm-config --libs` `${TOP}/../stage1/install/bin/llvm-config --system-libs`"
  RUST_DEPS="$RL/liballoc.rlib $RL/liballoc_system.rlib $RL/libarena.rlib $RL/libcollections.rlib $RL/libcore.rlib $RL/libcoretest.rlib $RL/libflate.rlib $RL/libfmt_macros.rlib $RL/libgetopts.rlib $RL/libgraphviz.rlib $RL/liblibc.rlib $RL/liblog.rlib $RL/librand.rlib $RL/librbml.rlib $RL/librustc.rlib $RL/librustc_back.rlib $RL/librustc_bitflags.rlib $RL/librustc_borrowck.rlib $RL/librustc_data_structures.rlib $RL/librustc_driver.rlib $RL/librustc_front.rlib $RL/librustc_lint.rlib $RL/librustc_llvm.rlib $RL/librustc_metadata.rlib $RL/librustc_mir.rlib $RL/librustc_platform_intrinsics.rlib $RL/librustc_plugin.rlib $RL/librustc_privacy.rlib $RL/librustc_resolve.rlib $RL/librustc_trans.rlib $RL/librustc_typeck.rlib $RL/librustc_unicode.rlib $RL/librustdoc.rlib $RL/libserialize.rlib $RL/libstd.rlib $RL/libsyntax.rlib $RL/libsyntax_ext.rlib $RL/libterm.rlib $RL/libtest.rlib"
  #RUST_DEPS="$RL/librustc.rlib $RL/librustc_llvm.rlib $RL/libarena.rlib $RL/libgetopts.rlib $RL/librustc_back.rlib $RL/libsyntax.rlib $RL/libserialize.rlib $RL/librbml.rlib $RL/libflate.rlib $RL/libterm.rlib $RL/liblog.rlib $RL/libgraphviz.rlib $RL/libfmt_macros.rlib $RL/libstd.rlib $RL/libcollections.rlib $RL/libunicode.rlib $RL/liballoc.rlib $RL/liblibc.rlib $RL/librand.rlib $RL/libcore.rlib $RL/libcoretest.rlib $RL/libregex.rlib $RL/librustc_driver.rlib $RL/librustc_trans.rlib $RL/librustc_typeck.rlib $RL/librustc_borrowck.rlib $RL/librustc_resolve.rlib $RL/librustdoc.rlib $RL/libtest.rlib"
  CXXFLAGS="`${TOP}/../stage1/install/bin/llvm-config --cxxflags` -stdlib=libc++ -v"
  LDFLAGS="-lc++ -lc++abi"

  cc ${CXXFLAGS} -o ${TOP}/bin/rustc -Wl,--start-group ${TOP}/../stage2/driver.o ${RUST_DEPS} -L${TOP}/../stage1/libs/llvm -L${TOP}/../stage1/libs -L${TOP}/../stage1/libs/llvm ${SUP_LIBS} ${LLVM_LIBS} ${LDFLAGS} -Wl,--end-group
  cp ${TOP}/../stage1/libs/*.a ${TOP}/lib
  cp ${TOP}/../stage2/rust-libs/*.rlib ${TOP}/lib
}

bitrig_test(){
  cd ${TOP}
  ${TOP}/bin/rustc -L${TOP}/lib ${TOP}/../tests/hw.rs
  ./hw
}

bitrig(){
  setup
  bitrig_build
  bitrig_test
}

### NETBSD FUNCTIONS ###

netbsd_build(){
  export CC="/usr/pkg/gcc49/bin/cc"
  export CXX="/usr/pkg/gcc49/bin/c++"
  export AR="/usr/pkg/gcc49/bin/gcc-ar"
  export NM="/usr/pkg/gcc49/bin/gcc-nm"
  export RANLIB="/usr/pkg/gcc49/bin/gcc-ranlib"
  cd ${TOP}
  RL=${TOP}/../stage2/rust-libs
  SUP_LIBS="-Wl,-no-whole-archive -lrust_builtin -lrustllvm -lbacktrace -lhoedown -lminiz"
  LLVM_LIBS="`${TOP}/../stage1/install/bin/llvm-config --libs` `${TOP}/../stage1/install/bin/llvm-config --system-libs`"
  RUST_DEPS="$RL/liballoc.rlib $RL/liballoc_system.rlib $RL/libarena.rlib $RL/libcollections.rlib $RL/libcore.rlib $RL/libcoretest.rlib $RL/libflate.rlib $RL/libfmt_macros.rlib $RL/libgetopts.rlib $RL/libgraphviz.rlib $RL/liblibc.rlib $RL/liblog.rlib $RL/librand.rlib $RL/librbml.rlib $RL/librustc.rlib $RL/librustc_back.rlib $RL/librustc_bitflags.rlib $RL/librustc_borrowck.rlib $RL/librustc_data_structures.rlib $RL/librustc_driver.rlib $RL/librustc_front.rlib $RL/librustc_lint.rlib $RL/librustc_llvm.rlib $RL/librustc_metadata.rlib $RL/librustc_mir.rlib $RL/librustc_platform_intrinsics.rlib $RL/librustc_plugin.rlib $RL/librustc_privacy.rlib $RL/librustc_resolve.rlib $RL/librustc_trans.rlib $RL/librustc_typeck.rlib $RL/librustc_unicode.rlib $RL/librustdoc.rlib $RL/libserialize.rlib $RL/libstd.rlib $RL/libsyntax.rlib $RL/libsyntax_ext.rlib $RL/libterm.rlib $RL/libtest.rlib"
  #RUST_DEPS="$RL/librustc.rlib $RL/librustc_llvm.rlib $RL/libarena.rlib $RL/libgetopts.rlib $RL/librustc_back.rlib $RL/libsyntax.rlib $RL/libserialize.rlib $RL/librbml.rlib $RL/libflate.rlib $RL/libterm.rlib $RL/liblog.rlib $RL/libgraphviz.rlib $RL/libfmt_macros.rlib $RL/libstd.rlib $RL/libcollections.rlib $RL/libunicode.rlib $RL/liballoc.rlib $RL/liblibc.rlib $RL/librand.rlib $RL/libcore.rlib $RL/libcoretest.rlib $RL/libregex.rlib $RL/librustc_driver.rlib $RL/librustc_trans.rlib $RL/librustc_typeck.rlib $RL/librustc_borrowck.rlib $RL/librustc_resolve.rlib $RL/librustdoc.rlib $RL/libtest.rlib"
  CFLAGS="`${TOP}/../stage1/install/bin/llvm-config --cflags` -v -gstabs+ -O0"
  CXXFLAGS="-I /usr/pkg/gcc49/include/c++/ `${TOP}/../stage1/install/bin/llvm-config --cxxflags` -v -gstabs+ -O0"
  LDFLAGS="-L /usr/pkg/gcc49/x86_64--netbsd/lib/ `${TOP}/../stage1/install/bin/llvm-config --ldflags` -v -lstdc++"

  ${CC} ${CXXFLAGS} -o ${TOP}/bin/rustc -Wl,--start-group ${TOP}/../stage2/driver.o ${RUST_DEPS} -L${TOP}/../stage1/libs/llvm -L${TOP}/../stage1/libs -L${TOP}/../stage1/libs/llvm ${SUP_LIBS} ${LLVM_LIBS} ${LDFLAGS} -Wl,--end-group

  cp ${TOP}/../stage1/libs/*.a ${TOP}/lib
  cp ${TOP}/../stage2/rust-libs/*.rlib ${TOP}/lib
}

netbsd_test(){
  cd ${TOP}
  ${TOP}/bin/rustc -g -Z verbose -L${TOP}/lib ${TOP}/../hw.rs
  ./hw
}

netbsd(){
  setup
  netbsd_build
  netbsd_test
}

check
MAKE=make
case ${HOST} in
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

