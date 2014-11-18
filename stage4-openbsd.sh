if [ `uname -s` != "OpenBSD" ]; then
  echo "You have to run this on OpenBSD!"
  exit 1
fi

if [ ! -e "stage3-openbsd/bin/rustc" ]; then
  echo "stage3-openbsd does not exist!"
  exit 1
fi
mkdir -p stage4-openbsd
cd stage4-openbsd

TOP=`pwd`

export AS="/usr/local/bin/egcc-as"
export CC="/usr/local/bin/egcc"
export CXX="/usr/local/bin/eg++"
export LDFLAGS="-L/usr/local/lib"
export CFLAGS="-I/usr/local/include"
export CXXFLAGS="-I/usr/local/include/c++/4.8.3/"
PREFIX="/usr/local"

if [ ! -e rust ]; then
  if [ -e ${TOP}/../stage1-openbsd/rust ]; then
    git clone --reference ${TOP}/stage1-openbsd/rust https://github.com/rust-lang/rust.git
  else
    git clone https://github.com/rust-lang/rust.git
  fi
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
cd ..
mkdir -p llvm-build
cd llvm-build
../llvm/configure --enable-local-rust --local-rust-root=${TOP}/../stage3-openbsd --prefix=${PREFIX}
gmake VERBOSE=1

p=`pwd`

echo "To install to ${PREFIX}: cd $p && gmake install"

