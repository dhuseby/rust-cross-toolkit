if [ `uname -s` != "Bitrig" ]; then
  echo "You have to run this on Bitrig!"
  exit 1
fi

if [ ! -e "stage3-bitrig/bin/rustc" ]; then
  echo "stage3-bitrig does not exist!"
  exit 1
fi

set -x

TOP=`pwd`

mkdir -p stage4-bitrig
cd stage4-bitrig


export CC="/usr/bin/clang"
export CXX="/usr/bin/clang++"
export CFLAGS="-g -O0 -pipe -fvisibility=hidden"
export CXXFLAGS="-g -O0 -fvisibility=hidden -fvisibility-inlines-hidden"
export LDFLAGS="-v -L/usr/local/lib"
PREFIX="/usr/local"

if [ ! -e rust ]; then
  #clone everything
  git clone --reference ${TOP}/stage1-bitrig/rust https://github.com/dhuseby/rust.git
  cd rust
  git submodule init
  git submodule update
else
  #update everything
  cd rust
  git pull origin
  git submodule update --merge
fi
configure --enable-local-rust --local-rust-root=${TOP}/stage3-bitrig --prefix=${PREFIX}
gmake VERBOSE=1

p=`pwd`

echo "To install to ${PREFIX}: cd $p && gmake install"

