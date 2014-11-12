if [ `uname -s` != "OpenBSD" ]; then
  echo "You have to run this on OpenBSD!"
  exit 1
fi

if [ ! -e "stage3-openbsd/bin/rustc" ]; then
  echo "stage3-openbsd does not exist!"
  exit 1
fi
mkdir -p stage4-openbsd

TOP=`pwd`

if [ ! -e ${TOP}/stage4-openbsd/rust ]; then
  cd stage4-openbsd
  if [ -e ${TOP}/stage1-openbsd/rust ]; then
    git clone --reference ${TOP}/stage1-openbsd/rust https://github.com/rust-lang/rust.git
  else
    git clone https://github.com/rust-lang/rust.git
  fi
  cd rust
  git submodule init
  git submodule update
  cd ${TOP}
fi

cd ${TOP}/stage4-openbsd/rust
./configure --enable-local-rust --local-rust-root=${TOP}/stage3-openbsd --prefix=/usr/local
cd src/llvm
patch -p1 < ${TOP}/patch-llvm
cd ../..

gmake

p=`pwd`

echo "To install to /usr/local: cd $p && gmake install"
