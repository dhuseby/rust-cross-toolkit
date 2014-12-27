if [ `uname -s` != "Bitrig" ]; then
  echo "You have to run this on Bitrig!"
  exit 1
fi

if [ ! -e "stage5-bitrig/bin/rustc" ]; then
  echo "stage5-bitrig does not exist!"
  exit 1
fi

set -x

TOP=`pwd`

mkdir -p stage6-bitrig
cd stage6-bitrig


export CC="/usr/bin/clang"
export CXX="/usr/bin/clang++"
export CFLAGS="-I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fPIC"
export CXXFLAGS="-std=c++11 -stdlib=libc++ -mstackrealign -I/usr/include/c++/v1/ -I/usr/include/libcxxabi -I/usr/lib/llvm-3.4/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -g -O0 -fomit-frame-pointer -fvisibility-inlines-hidden -fno-exceptions -fPIC -Woverloaded-virtual -Wcast-qual -v"
export LDFLAGS="-g -stdlib=libc++ -L/usr/lib/llvm-3.4/lib -L/usr/lib/x86_64-linux-gnu/ -L/lib64 -L/lib -L/usr/lib -lc++ -lc++abi -lunwind -lc -lpthread -lffi -ltinfo -ldl -lm"
PREFIX="/usr/local"


#if [ ! -e rust ]; then
#  #clone everything
#  git clone --reference ${TOP}/stage4-bitrig/rust https://github.com/dhuseby/rust.git
#  cd rust
#  git submodule init
#  git submodule update
#else
#  #update everything
  cd rust
#  git pull origin
#  git submodule update --merge
#fi
#configure --enable-local-rust --enable-clang --local-rust-root=${TOP}/stage5-bitrig --prefix=${PREFIX}
gmake VERBOSE=1

p=`pwd`

echo "To install to ${PREFIX}: cd $p && gmake install"

